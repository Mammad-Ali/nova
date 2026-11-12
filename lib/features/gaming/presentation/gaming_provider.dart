import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/region_probe.dart';
import '../domain/gaming.dart';

class GamingCheckState {
  const GamingCheckState({this.results = const {}, this.running = false});

  /// By region id; a region appears once its samples are in.
  final Map<String, RegionResult> results;
  final bool running;

  /// The region with the lowest ping, once there are any.
  String? get best {
    String? id;
    double? low;
    results.forEach((key, r) {
      final ping = r.pingMs;
      if (ping != null && r.verdict != GamingVerdict.lost && (low == null || ping < low!)) {
        low = ping;
        id = key;
      }
    });
    return id;
  }
}

final gamingCheckProvider =
    NotifierProvider.autoDispose<GamingCheckNotifier, GamingCheckState>(GamingCheckNotifier.new);

class GamingCheckNotifier extends Notifier<GamingCheckState> {
  static const _samples = 10;
  static const _gap = Duration(milliseconds: 120);

  @override
  GamingCheckState build() => const GamingCheckState();

  /// Times every region at once: a few seconds in all.
  Future<void> run() async {
    if (state.running) return;
    state = const GamingCheckState(running: true);
    await Future.wait([for (final region in gameRegions) _measure(region)]);
    if (ref.mounted) state = GamingCheckState(results: state.results);
  }

  Future<void> _measure(GameRegion region) async {
    final probe = RegionProbe(region.url);
    try {
      // The first one pays for the name lookup and the handshake.
      await probe.once();
      final samples = <double?>[];
      for (var i = 0; i < _samples; i++) {
        samples.add(await probe.once());
        await Future<void>.delayed(_gap);
      }
      if (!ref.mounted) return;
      state = GamingCheckState(
        results: {...state.results, region.id: RegionResult.from(samples)},
        running: true,
      );
    } finally {
      probe.close();
    }
  }
}
