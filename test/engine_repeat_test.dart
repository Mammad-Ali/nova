import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/speedtest/data/datasources/speedtest_engine.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_models.dart';

void main() {
  test('движок можно запускать дважды подряд без краха', () async {
    for (var i = 0; i < 2; i++) {
      final engine = SpeedTestEngine();
      final phases = <TestPhase>{};
      final sub = engine.run().listen((p) => phases.add(p.phase));

      await Future<void>.delayed(const Duration(seconds: 4));
      await sub.cancel(); // → onCancel → cancel() → отложенный _dispose (kill isolate)
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(phases, contains(TestPhase.ping),
          reason: 'запуск №${i + 1} должен присылать события');
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
