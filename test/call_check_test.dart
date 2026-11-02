import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/call_check/domain/call_check.dart';

void main() {
  test('sums up samples: median, jitter, loss', () {
    final m = CallMetrics.fromSamples([20, 30, null, 40, 30]);
    expect(m.latencyMs, 30);
    expect(m.jitterMs, closeTo((10 + 10 + 10) / 3, 1e-9));
    expect(m.lossPercent, 20);
  });

  test('nothing back at all means not ready, whatever the call', () {
    final m = CallMetrics.fromSamples([null, null, null]);
    for (final kind in CallKind.values) {
      expect(judgeCall(kind, m), CallVerdict.notReady);
      expect(callProblems(kind, m).keys, [CallProblem.unreachable]);
    }
  });

  test('a clean line is ready for everything', () {
    const m = CallMetrics(latencyMs: 25, jitterMs: 3, lossPercent: 0, downMbps: 90, upMbps: 30);
    for (final kind in CallKind.values) {
      expect(judgeCall(kind, m), CallVerdict.ready);
    }
  });

  test('a slow upload spoils video but not voice', () {
    const m = CallMetrics(latencyMs: 30, jitterMs: 5, lossPercent: 0, downMbps: 50, upMbps: 1);
    expect(judgeCall(CallKind.voice, m), CallVerdict.ready);
    expect(judgeCall(CallKind.video, m), CallVerdict.notReady);
    expect(callProblems(CallKind.video, m).keys, [CallProblem.upload]);
  });

  test('group calls ask for more bandwidth than one-to-one video', () {
    const m = CallMetrics(latencyMs: 30, jitterMs: 5, lossPercent: 0, downMbps: 5, upMbps: 3);
    expect(judgeCall(CallKind.video, m), CallVerdict.ready);
    expect(judgeCall(CallKind.group, m), CallVerdict.shaky);
  });

  test('jitter and loss count even when the average is fine', () {
    const m = CallMetrics(latencyMs: 40, jitterMs: 45, lossPercent: 2);
    expect(judgeCall(CallKind.voice, m), CallVerdict.shaky);
    expect(judgeCall(CallKind.video, m), CallVerdict.shaky);
    expect(callProblems(CallKind.video, m).keys.toSet(), {CallProblem.jitter, CallProblem.loss});
  });

  test('unknown bandwidth is not held against the connection', () {
    const m = CallMetrics(latencyMs: 30, jitterMs: 5, lossPercent: 0);
    expect(judgeCall(CallKind.group, m), CallVerdict.ready);
  });
}
