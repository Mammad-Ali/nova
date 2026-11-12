import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lan_scan_engine.dart';
import '../domain/lan_device.dart';
import 'network_watch_provider.dart';

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
  StreamSubscription<void>? _subscription;

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
    final vendors = _vendors ??= loadVendors();
    _subscription = engine
        .run()
        .asyncMap((update) async => (update, await vendors))
        .listen((pair) {
      final (update, vendors) = pair;
      state = LanScanState(
        devices: [
          for (final device in update.devices)
            device.copyWith(vendor: vendors[device.macPrefix]),
        ],
        running: !update.done,
        scanned: update.scanned,
        total: update.total,
        subnet: update.subnet,
        failure: update.failure,
      );
      if (update.done) {
        _stop();
        if (update.failure == null) {
          ref.read(networkWatchProvider.notifier).publish(state.devices);
        }
      }
    });
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _engine?.cancel();
    _engine = null;
  }
}

/// Makers by MAC prefix, read once per app run.
Future<Map<String, String>>? _vendors;

/// assets/oui/vendors.txt ("B4B024 TP-Link" per line, made by
/// tool/make_vendor_list.py) as prefix → maker. Empty if it can't be read:
/// the list then just shows no makers.
Future<Map<String, String>> loadVendors() async {
  try {
    return parseVendors(await rootBundle.loadString('assets/oui/vendors.txt'));
  } catch (_) {
    return const {};
  }
}

Map<String, String> parseVendors(String text) => {
      for (final line in const LineSplitter().convert(text))
        if (line.length > 7 && !line.startsWith('#'))
          line.substring(0, 6): line.substring(7),
    };
