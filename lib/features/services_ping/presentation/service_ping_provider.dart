import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service_target.dart';

/// Состояние замера задержек до сервисов.
class ServicePingState {
  const ServicePingState({this.results = const [], this.running = false});

  final List<ServicePing> results;
  final bool running;
}

final servicePingProvider =
    NotifierProvider<ServicePingNotifier, ServicePingState>(
        ServicePingNotifier.new);

/// Меряет задержку до каждого сервиса: три запроса, берём медиану.
/// Сервисы опрашиваются параллельно, поэтому весь прогон ~1 секунду.
class ServicePingNotifier extends Notifier<ServicePingState> {
  @override
  ServicePingState build() {
    // Первый замер сразу при открытии — не заставляем жать кнопку.
    Future.microtask(run);
    return const ServicePingState(running: true);
  }

  Future<void> run() async {
    if (state.results.isNotEmpty && state.running) return;
    state = ServicePingState(results: state.results, running: true);

    final results = await Future.wait(kServiceTargets.map(_measure));

    // Быстрые — наверху, недоступные — в конце.
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
      // Прогрев: поглощает DNS + TLS, дальше меряем по живому соединению.
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
