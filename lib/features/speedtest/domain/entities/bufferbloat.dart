/// How badly the link swells under load.
enum BloatLevel { excellent, good, fair, poor }

/// Outcome of the bufferbloat assessment.
class BufferbloatResult {
  const BufferbloatResult({
    required this.idlePingMs,
    required this.loadedPingMs,
    required this.level,
  });

  final double idlePingMs;
  final double loadedPingMs;
  final BloatLevel level;

  /// Added latency under load (ms). This is what ruins games and calls.
  double get increaseMs =>
      (loadedPingMs - idlePingMs) < 0 ? 0 : loadedPingMs - idlePingMs;

  String get letter => switch (level) {
        BloatLevel.excellent => 'A',
        BloatLevel.good => 'B',
        BloatLevel.fair => 'C',
        BloatLevel.poor => 'D',
      };
}

/// Classifies bufferbloat by how much latency the load adds.
///
/// Thresholds follow the conventions of tests like Waveform: under 30 ms of
/// added delay is excellent, beyond 200 ms the link is choking.
BufferbloatResult evaluateBufferbloat({
  required double idlePingMs,
  required double loadedPingMs,
}) {
  final delta = loadedPingMs - idlePingMs;
  final level = switch (delta) {
    < 30 => BloatLevel.excellent,
    < 60 => BloatLevel.good,
    < 200 => BloatLevel.fair,
    _ => BloatLevel.poor,
  };
  return BufferbloatResult(
    idlePingMs: idlePingMs,
    loadedPingMs: loadedPingMs,
    level: level,
  );
}
