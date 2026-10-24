import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/latency_probe.dart';
import '../domain/service_target.dart';

/// State of the per-service latency measurement.
class ServicePingState {
  const ServicePingState({this.results = const [], this.running = false});

  final List<ServicePing> results;
  final bool running;
}

final servicePingProvider =
    NotifierProvider<ServicePingNotifier, ServicePingState>(
        ServicePingNotifier.new);

/// Measures latency to each service: three requests, median wins.
/// Services are probed in parallel, so a full run takes about a second.
class ServicePingNotifier extends Notifier<ServicePingState> {
  @override
  ServicePingState build() {
    // Measure immediately on open instead of waiting for a button press.
    Future.microtask(run);
    return const ServicePingState(running: true);
  }

  Future<void> run() async {
    if (state.results.isNotEmpty && state.running) return;
    state = ServicePingState(results: state.results, running: true);

    final results = await Future.wait(kServiceTargets.map(_measure));

    // Fastest first, unreachable ones last.
    results.sort((a, b) {
      if (a.failed != b.failed) return a.failed ? 1 : -1;
      return (a.rttMs ?? 0).compareTo(b.rttMs ?? 0);
    });

    state = ServicePingState(results: results, running: false);
  }

  Future<ServicePing> _measure(ServiceTarget target) async =>
      ServicePing(target: target, rttMs: await measureLatency(target.url));
}
