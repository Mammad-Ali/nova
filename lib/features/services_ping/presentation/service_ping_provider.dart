import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<ServicePing> _measure(ServiceTarget target) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 10);
    final uri = Uri.parse(target.url);
    final rtts = <double>[];

    try {
      // Warm-up absorbs DNS + TLS; the rest reuses the live connection.
      await _once(client, uri);
      for (var i = 0; i < 3; i++) {
        final rtt = await _once(client, uri);
        if (rtt != null) rtts.add(rtt);
      }
    } finally {
      client.close(force: true);
    }

    if (rtts.isEmpty) return ServicePing(target: target);
    rtts.sort();
    return ServicePing(target: target, rttMs: rtts[rtts.length ~/ 2]);
  }

  Future<double?> _once(HttpClient c, Uri uri) async {
    try {
      final sw = Stopwatch()..start();
      final req = await c.headUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 5));
      await resp.drain<void>();
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    }
  }
}
