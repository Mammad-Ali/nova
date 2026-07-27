/// Фазы активного теста скорости.
enum TestPhase { idle, ping, download, upload, done, error }

extension TestPhaseX on TestPhase {
  // Локализованные названия фаз берутся из AppStrings в UI-слое.
  bool get isRunning =>
      this == TestPhase.ping ||
      this == TestPhase.download ||
      this == TestPhase.upload;
}

/// Одно событие прогресса, которое фоновый изолят присылает в UI.
///
/// Обычный data-класс из примитивов — безопасно копируется между изолятами.
class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phase,
    this.displayMbps = 0,
    this.phaseProgress = 0,
    this.pingMs,
    this.jitterMs,
    this.downloadMbps,
    this.uploadMbps,
    this.loadedPingMs,
    this.serverName,
    this.error,
  });

  /// Текущая фаза.
  final TestPhase phase;

  /// Сглаженная (EWMA) текущая скорость в Мбит/с — для стрелки спидометра.
  final double displayMbps;

  /// Прогресс внутри текущей фазы, 0..1.
  final double phaseProgress;

  /// Итоговые метрики (заполняются по мере готовности).
  final double? pingMs;
  final double? jitterMs;
  final double? downloadMbps;
  final double? uploadMbps;

  /// Медианный пинг, измеренный ПОД НАГРУЗКОЙ (во время скачивания).
  /// Разница с обычным [pingMs] и есть bufferbloat.
  final double? loadedPingMs;

  /// Имя сервера, на котором реально прошёл замер.
  final String? serverName;

  /// Текст ошибки, если фаза == error.
  final String? error;
}
