/// What a call check measured. Bandwidth comes from the last speed test and
/// is null when there was none recently.
class CallMetrics {
  const CallMetrics({
    required this.latencyMs,
    required this.jitterMs,
    required this.lossPercent,
    this.downMbps,
    this.upMbps,
  });

  /// Median round trip; null when nothing came back at all.
  final double? latencyMs;

  /// Mean change between consecutive round trips — what makes voices choppy.
  final double? jitterMs;

  /// Share of round trips that never came back, 0..100.
  final double lossPercent;

  final double? downMbps;
  final double? upMbps;

  /// Sums up a check's round trips (null = lost).
  factory CallMetrics.fromSamples(
    List<double?> samples, {
    double? downMbps,
    double? upMbps,
  }) {
    final ok = [for (final s in samples) ?s];
    double? latency;
    double? jitter;
    if (ok.isNotEmpty) {
      final sorted = [...ok]..sort();
      latency = sorted[sorted.length ~/ 2];
    }
    if (ok.length >= 2) {
      var sum = 0.0;
      for (var i = 1; i < ok.length; i++) {
        sum += (ok[i] - ok[i - 1]).abs();
      }
      jitter = sum / (ok.length - 1);
    }
    return CallMetrics(
      latencyMs: latency,
      jitterMs: jitter,
      lossPercent: samples.isEmpty ? 0 : (samples.length - ok.length) * 100 / samples.length,
      downMbps: downMbps,
      upMbps: upMbps,
    );
  }
}

/// The kinds of call judged separately: each needs more than the last.
enum CallKind { voice, video, group }

/// Ordered from best to worst, so the worst of several is the largest.
enum CallVerdict { ready, shaky, notReady }

/// A measurement that holds a call back.
enum CallProblem { latency, jitter, loss, download, upload, unreachable }

/// "Good up to [good], usable up to [usable]" for a figure where less is
/// better, or "at least" for one where more is better.
class _Limit {
  const _Limit(this.good, this.usable);
  final double good;
  final double usable;
}

/// Thresholds from what Zoom, Meet and Teams publish as their requirements,
/// rounded to plain numbers.
class _Needs {
  const _Needs({
    required this.latency,
    required this.jitter,
    required this.loss,
    required this.down,
    required this.up,
  });
  final _Limit latency, jitter, loss, down, up;
}

const _needs = {
  CallKind.voice: _Needs(
    latency: _Limit(150, 300),
    jitter: _Limit(30, 60),
    loss: _Limit(1, 5),
    down: _Limit(0.2, 0.1),
    up: _Limit(0.2, 0.1),
  ),
  CallKind.video: _Needs(
    latency: _Limit(150, 250),
    jitter: _Limit(30, 50),
    loss: _Limit(1, 3),
    down: _Limit(3, 1.5),
    up: _Limit(3, 1.5),
  ),
  CallKind.group: _Needs(
    latency: _Limit(150, 250),
    jitter: _Limit(30, 50),
    loss: _Limit(1, 3),
    down: _Limit(8, 4),
    up: _Limit(4, 2),
  ),
};

CallVerdict _lessIsBetter(double value, _Limit limit) => value <= limit.good
    ? CallVerdict.ready
    : value <= limit.usable
        ? CallVerdict.shaky
        : CallVerdict.notReady;

CallVerdict _moreIsBetter(double value, _Limit limit) => value >= limit.good
    ? CallVerdict.ready
    : value >= limit.usable
        ? CallVerdict.shaky
        : CallVerdict.notReady;

/// Each problem and how badly it affects a call of [kind]; figures that are
/// fine are left out. Unknown bandwidth isn't held against the connection.
Map<CallProblem, CallVerdict> callProblems(CallKind kind, CallMetrics m) {
  final needs = _needs[kind]!;
  final latency = m.latencyMs;
  if (latency == null) return {CallProblem.unreachable: CallVerdict.notReady};

  final verdicts = {
    CallProblem.latency: _lessIsBetter(latency, needs.latency),
    if (m.jitterMs != null) CallProblem.jitter: _lessIsBetter(m.jitterMs!, needs.jitter),
    CallProblem.loss: _lessIsBetter(m.lossPercent, needs.loss),
    if (m.downMbps != null) CallProblem.download: _moreIsBetter(m.downMbps!, needs.down),
    if (m.upMbps != null) CallProblem.upload: _moreIsBetter(m.upMbps!, needs.up),
  };
  verdicts.removeWhere((_, verdict) => verdict == CallVerdict.ready);
  return verdicts;
}

/// How a call of [kind] would go: as good as its worst figure allows.
CallVerdict judgeCall(CallKind kind, CallMetrics m) {
  var worst = CallVerdict.ready;
  for (final verdict in callProblems(kind, m).values) {
    if (verdict.index > worst.index) worst = verdict;
  }
  return worst;
}
