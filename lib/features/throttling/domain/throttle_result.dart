/// Вердикт сравнения «обычный CDN против видео-CDN».
enum ThrottleVerdict {
  /// Видео идёт не медленнее обычного трафика.
  none,

  /// Видео заметно медленнее — похоже на замедление стриминга.
  suspected,

  /// Видео сильно медленнее — провайдер почти наверняка режет видео.
  likely,

  /// Видео БЫСТРЕЕ: у провайдера стоит локальный кэш видеосервиса.
  localCache,
}

/// Результат проверки на троттлинг.
class ThrottleResult {
  const ThrottleResult({
    required this.neutralMbps,
    required this.videoMbps,
    required this.verdict,
    this.videoHost,
  });

  /// Скорость до нейтрального CDN (Cloudflare/Cachefly).
  final double neutralMbps;

  /// Скорость до видео-CDN (Netflix Open Connect).
  final double videoMbps;

  final ThrottleVerdict verdict;

  /// Хост видео-CDN — по нему видно, стоит ли кэш внутри сети провайдера.
  final String? videoHost;

  /// Доля скорости видео от обычной: 1.0 — одинаково.
  double get ratio => neutralMbps <= 0 ? 0 : videoMbps / neutralMbps;
}

/// Классифицирует результат по соотношению скоростей.
ThrottleVerdict verdictFor(double neutralMbps, double videoMbps) {
  if (neutralMbps <= 0.01) return ThrottleVerdict.none;
  final r = videoMbps / neutralMbps;
  if (r >= 1.25) return ThrottleVerdict.localCache;
  if (r >= 0.85) return ThrottleVerdict.none;
  if (r >= 0.55) return ThrottleVerdict.suspected;
  return ThrottleVerdict.likely;
}
