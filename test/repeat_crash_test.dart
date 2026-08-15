import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:net_pulse/features/speedtest/data/datasources/ip_info.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_models.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_record.dart';
import 'package:net_pulse/features/speedtest/presentation/providers/speedtest_history_provider.dart';
import 'package:net_pulse/features/speedtest/presentation/providers/speedtest_provider.dart';
import 'package:net_pulse/features/speedtest/presentation/screens/speedtest_screen.dart';

/// Fake controller: replays state transitions without touching the network.
class FakeCtrl extends SpeedTestController {
  @override
  SpeedTestState build() => const SpeedTestState();

  @override
  void start() =>
      state = const SpeedTestState(phase: TestPhase.ping, gaugeMax: 100);

  @override
  void stop() => state = state.copyWith(phase: TestPhase.idle);

  void finish(double d) {
    state = SpeedTestState(
      phase: TestPhase.done,
      gaugeMax: 100,
      downloadMbps: d,
      uploadMbps: d * 0.4,
      pingMs: 18,
      jitterMs: 2.5,
    );
    ref.read(speedTestHistoryProvider.notifier).add(SpeedTestRecord(
          timestamp: DateTime.now(),
          downloadMbps: d,
          uploadMbps: d * 0.4,
          pingMs: 18,
          jitterMs: 2.5,
        ));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('running the test repeatedly does not crash', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speedTestControllerProvider.overrideWith(FakeCtrl.new),
        ipInfoProvider.overrideWith(
          (ref) => const IpInfo(isp: 'Test ISP', city: 'Baku', country: 'AZ'),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SpeedTestScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final el = tester.element(find.byType(SpeedTestScreen));
    final ctrl = ProviderScope.containerOf(el)
        .read(speedTestControllerProvider.notifier) as FakeCtrl;

    // Run 1
    ctrl.start();
    await tester.pump(const Duration(milliseconds: 100));
    ctrl.finish(50);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull, reason: 'after the first run');

    // Run 2 (repeat, a record, which fires confetti)
    ctrl.start();
    await tester.pump(const Duration(milliseconds: 100));
    ctrl.finish(90);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull, reason: 'after the repeat run');

    // Run 3
    ctrl.start();
    await tester.pump(const Duration(milliseconds: 200));
    ctrl.finish(30);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull, reason: 'after the third run');
  });
}
