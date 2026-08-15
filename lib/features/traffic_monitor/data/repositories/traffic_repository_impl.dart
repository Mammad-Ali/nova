import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/network_snapshot.dart';
import '../../domain/repositories/traffic_repository.dart';

// The DI seam the presentation layer reads from.
final trafficRepositoryProvider = Provider<TrafficRepository>((ref) {
  final repo = TrafficRepositoryImpl();
  repo.startMonitoring();
  ref.onDispose(() => repo.stopMonitoring());
  return repo;
});

class TrafficRepositoryImpl implements TrafficRepository {
  static const MethodChannel _channel = MethodChannel('net_pulse/traffic');
  
  StreamController<NetworkSnapshot>? _controller;
  Timer? _timer;
  
  int? _prevRx;
  int? _prevTx;
  DateTime? _prevTime;

  @override
  Stream<NetworkSnapshot> watch() {
    _controller ??= StreamController<NetworkSnapshot>.broadcast();
    return _controller!.stream;
  }

  void startMonitoring() {
    if (_timer != null) return;
    
    _prevRx = null;
    _prevTx = null;
    _prevTime = null;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final List<dynamic>? counters = await _channel.invokeMethod<List<dynamic>>('getCounters');
        if (counters == null || counters.length < 2) return;

        final int currentRx = counters[0] as int;
        final int currentTx = counters[1] as int;
        final DateTime now = DateTime.now();

        if (_prevRx != null && _prevTx != null && _prevTime != null) {
          final double timeDeltaSeconds = now.difference(_prevTime!).inMilliseconds / 1000.0;
          
          if (timeDeltaSeconds > 0) {
            final int deltaRx = _calculateDelta(currentRx, _prevRx!);
            final int deltaTx = _calculateDelta(currentTx, _prevTx!);

            if (timeDeltaSeconds < 3.0) {
              final snapshot = NetworkSnapshot(
                rxPerSec: (deltaRx / timeDeltaSeconds).round(),
                txPerSec: (deltaTx / timeDeltaSeconds).round(),
                totalRx: currentRx,
                totalTx: currentTx,
                timestamp: now,
              );
              _controller?.add(snapshot);
            }
          }
        }

        _prevRx = currentRx;
        _prevTx = currentTx;
        _prevTime = now;
      } catch (e) {
        _controller?.addError(e);
      }
    });
  }

  int _calculateDelta(int now, int prev) {
    int delta = now - prev;
    if (delta < 0) delta += 0x100000000; // macOS 32-bit counter wrapped
    return delta;
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}