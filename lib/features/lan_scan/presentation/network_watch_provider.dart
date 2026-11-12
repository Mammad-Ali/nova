import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lan_scan_engine.dart';
import '../domain/known_device.dart';
import '../domain/lan_device.dart';
import 'known_devices_provider.dart';
import 'lan_scan_provider.dart';

/// The network at a glance, for the Network widget.
class NetworkSummary {
  const NetworkSummary({required this.online, required this.at, this.newest});

  /// Devices that answered the last scan, this machine included.
  final int online;

  /// When that scan finished.
  final DateTime at;

  /// The most recently found device among those that are new (first seen
  /// in the last day), if any.
  final KnownDevice? newest;
}

/// Keeps [NetworkSummary] current: on the Mac a quiet scan every half hour
/// while Nova runs, and every scan the user runs in the meantime.
final networkWatchProvider =
    NotifierProvider<NetworkWatchNotifier, NetworkSummary?>(NetworkWatchNotifier.new);

class NetworkWatchNotifier extends Notifier<NetworkSummary?> {
  static const _every = Duration(minutes: 30);
  LanScanEngine? _engine;

  @override
  NetworkSummary? build() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      // The first one waits a little: Nova has enough to do at launch.
      final first = Timer(const Duration(minutes: 1), _scan);
      final timer = Timer.periodic(_every, (_) => _scan());
      ref.onDispose(() {
        first.cancel();
        timer.cancel();
        _engine?.cancel();
      });
    }
    return null;
  }

  Future<void> _scan() async {
    if (_engine != null) return;
    final engine = _engine = LanScanEngine();
    try {
      final vendors = await loadVendors();
      LanScanUpdate? last;
      await for (final update in engine.run()) {
        last = update;
      }
      if (last == null || last.failure != null) return;
      await publish([
        for (final device in last.devices) device.copyWith(vendor: vendors[device.macPrefix]),
      ]);
    } catch (_) {
      // Next time, then.
    } finally {
      _engine = null;
    }
  }

  /// Records a finished scan — this one's or the user's — and sums it up.
  Future<void> publish(List<LanDevice> devices) async {
    final known = ref.read(knownDevicesProvider.notifier);
    await known.recordScan(devices);
    if (!ref.mounted) return;
    final now = DateTime.now();
    final everyone = ref.read(knownDevicesProvider);
    final fresh = [
      for (final device in devices)
        if (everyone[deviceId(device)] case final k? when !device.isSelf && k.isNew(now)) k,
    ]..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
    state = NetworkSummary(online: devices.length, at: now, newest: fresh.firstOrNull);
  }
}
