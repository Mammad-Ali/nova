/// Насколько сильно «распухает» канал под нагрузкой.
enum BloatLevel { excellent, good, fair, poor }

/// Результат оценки bufferbloat.
class BufferbloatResult {
  const BufferbloatResult({
    required this.idlePingMs,
    required this.loadedPingMs,
    required this.level,
  });

  final double idlePingMs;
  final double loadedPingMs;
  final BloatLevel level;

  /// Прирост задержки под нагрузкой (мс). Именно он портит игры и звонки.
  double get increaseMs =>
      (loadedPingMs - idlePingMs) < 0 ? 0 : loadedPingMs - idlePingMs;

  String get letter => switch (level) {
        BloatLevel.excellent => 'A',
        BloatLevel.good => 'B',
        BloatLevel.fair => 'C',
        BloatLevel.poor => 'D',
      };
}

/// Классифицирует bufferbloat по приросту задержки под нагрузкой.
///
/// Пороги близки к общепринятым в тестах вроде Waveform: до 30 мс прироста —
/// отлично, свыше 200 мс — канал захлёбывается.
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
