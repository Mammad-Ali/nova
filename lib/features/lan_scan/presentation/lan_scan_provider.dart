import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lan_scan_engine.dart';
import '../domain/lan_device.dart';

/// State of the "who is on my network" scan.
class LanScanState {
  const LanScanState({
    this.devices = const [],
    this.running = false,
    this.scanned = 0,
    this.total = 0,
    this.subnet,
    this.failure,
  });

  final List<LanDevice> devices;
  final bool running;
  final int scanned;
  final int total;
  final String? subnet;
  final LanScanFailure? failure;

  double get progress => total == 0 ? 0 : scanned / total;
}

final lanScanProvider =
    NotifierProvider<LanScanNotifier, LanScanState>(LanScanNotifier.new);

class LanScanNotifier extends Notifier<LanScanState> {
  LanScanEngine? _engine;
  StreamSubscription<LanScanUpdate>? _subscription;

  @override
  LanScanState build() {
    ref.onDispose(_stop);
    // Scan straight away: opening the sheet is the request.
    Future.microtask(run);
    return const LanScanState(running: true);
  }

  void run() {
    if (_engine != null) return;
    state = const LanScanState(running: true);

    final engine = _engine = LanScanEngine();
    _subscription = engine.run().listen((update) {
      state = LanScanState(
        devices: update.devices,
        running: !update.done,
        scanned: update.scanned,
        total: update.total,
        subnet: update.subnet,
        failure: update.failure,
      );
      if (update.done) _stop();
    });
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _engine?.cancel();
    _engine = null;
  }
}
