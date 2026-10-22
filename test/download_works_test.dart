// Runs a real speed test against Cloudflare. Tagged so CI can skip it:
// a CDN hiccup must not fail a build. Locally, `flutter test` runs it.
@Tags(['network'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/speedtest/data/datasources/speedtest_engine.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_models.dart';

void main() {
  test('full run reports download, upload, bufferbloat and server', () async {
    final engine = SpeedTestEngine();
    SpeedTestProgress? result;
    final completer = Completer<void>();

    engine.run().listen((p) {
      if (p.phase == TestPhase.done || p.phase == TestPhase.error) {
        result = p;
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future.timeout(const Duration(seconds: 55));

    expect(result, isNotNull);
    expect(result!.phase, TestPhase.done, reason: 'error: ${result!.error}');

    expect(result!.downloadMbps! > 0, isTrue,
        reason: 'download should be > 0, got ${result!.downloadMbps}');
    expect(result!.uploadMbps! > 0, isTrue,
        reason: 'upload should be > 0, got ${result!.uploadMbps}');

    // Latency under load and the name of the selected server.
    expect(result!.serverName, isNotNull, reason: 'a server should have been selected');
    expect(result!.loadedPingMs, isNotNull,
        reason: 'latency under load should be measured');
    expect(result!.loadedPingMs! > 0, isTrue);

    // ignore: avoid_print
    print('server=${result!.serverName} '
        'down=${result!.downloadMbps!.toStringAsFixed(1)} '
        'up=${result!.uploadMbps!.toStringAsFixed(1)} '
        'ping=${result!.pingMs!.toStringAsFixed(1)} '
        'loaded=${result!.loadedPingMs!.toStringAsFixed(1)}');
  }, timeout: const Timeout(Duration(seconds: 70)));
}
