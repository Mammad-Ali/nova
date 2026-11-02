import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/diagnose/domain/diagnosis.dart';

void main() {
  final goodRouter = judgeRouter('192.168.1.1', [3, 4, 3, 5]);
  final goodDns = judgeDns(40, failed: 0, total: 4);
  final goodNet = judgeInternet([25, 27, 26, 30]);

  test('grades the Wi-Fi signal', () {
    expect(judgeWifi(-55).health, LinkHealth.good);
    expect(judgeWifi(-70).health, LinkHealth.fair);
    expect(judgeWifi(-82).health, LinkHealth.bad);
    expect(judgeWifi(null).health, LinkHealth.skipped);
  });

  test('grades the router by round trip and loss', () {
    expect(goodRouter.health, LinkHealth.good);
    expect(judgeRouter('192.168.1.1', [15, 18, 14]).health, LinkHealth.fair);
    expect(judgeRouter('192.168.1.1', [3, null, 3, 3, 3, 3, 3, 3, 3, 3]).health, LinkHealth.fair);
    expect(judgeRouter('192.168.1.1', [null, null]).unreachable, isTrue);
    expect(judgeRouter(null, const []).health, LinkHealth.skipped);
  });

  test('everything healthy means no cause', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(-50),
      DiagnosisStep.router: goodRouter,
      DiagnosisStep.dns: goodDns,
      DiagnosisStep.internet: goodNet,
    });
    expect(result.cause, Cause.none);
  });

  test('the first bad link from the home outwards is the cause', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(-80),
      DiagnosisStep.router: goodRouter,
      DiagnosisStep.dns: goodDns,
      DiagnosisStep.internet: judgeInternet([200, 220, null, 210]),
    });
    expect(result.cause, Cause.wifi);
    expect(result.serious, isTrue);
  });

  test('a bad link beats a merely fair one closer to home', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(-70),
      DiagnosisStep.router: goodRouter,
      DiagnosisStep.dns: judgeDns(900, failed: 0, total: 4),
      DiagnosisStep.internet: goodNet,
    });
    expect(result.cause, Cause.dns);
    expect(result.serious, isTrue);
  });

  test('a slow way out with a healthy home is the provider', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(null),
      DiagnosisStep.router: goodRouter,
      DiagnosisStep.dns: goodDns,
      DiagnosisStep.internet: judgeInternet([100, 110, 95, 105]),
    });
    expect(result.cause, Cause.provider);
    expect(result.serious, isFalse);
  });

  test('nothing beyond a working router is an outage', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(-50),
      DiagnosisStep.router: goodRouter,
      DiagnosisStep.dns: judgeDns(null, failed: 4, total: 4),
      DiagnosisStep.internet: judgeInternet([null, null, null]),
    });
    expect(result.cause, Cause.offline);
  });

  test('no router either points at the router', () {
    final result = findCause({
      DiagnosisStep.wifi: judgeWifi(-50),
      DiagnosisStep.router: judgeRouter('192.168.1.1', [null, null]),
      DiagnosisStep.dns: judgeDns(null, failed: 4, total: 4),
      DiagnosisStep.internet: judgeInternet([null, null]),
    });
    expect(result.cause, Cause.router);
  });
}
