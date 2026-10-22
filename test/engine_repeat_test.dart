// Runs a real speed test against Cloudflare. Tagged so CI can skip it:
// a CDN hiccup must not fail a build. Locally, `flutter test` runs it.
@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/speedtest/data/datasources/speedtest_engine.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_models.dart';

void main() {
  test('the engine can run twice in a row without crashing', () async {
    for (var i = 0; i < 2; i++) {
      final engine = SpeedTestEngine();
      final phases = <TestPhase>{};
      final sub = engine.run().listen((p) => phases.add(p.phase));

      await Future<void>.delayed(const Duration(seconds: 4));
      await sub.cancel(); // onCancel -> cancel() -> deferred _dispose kills the isolate
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(phases, contains(TestPhase.ping),
          reason: 'run #${i + 1} should emit events');
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
