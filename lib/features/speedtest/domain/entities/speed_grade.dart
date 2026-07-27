/// Категория скорости для итоговой оценки.
enum SpeedTier { blazing, fast, good, moderate, slow }

/// Буквенная оценка + категория по скорости загрузки.
class SpeedGrade {
  const SpeedGrade(this.letter, this.tier);
  final String letter;
  final SpeedTier tier;
}

/// Считает оценку по download (Мбит/с).
SpeedGrade gradeForDownload(double mbps) {
  if (mbps >= 300) return const SpeedGrade('A+', SpeedTier.blazing);
  if (mbps >= 150) return const SpeedGrade('A', SpeedTier.blazing);
  if (mbps >= 75) return const SpeedGrade('A', SpeedTier.fast);
  if (mbps >= 40) return const SpeedGrade('B', SpeedTier.fast);
  if (mbps >= 20) return const SpeedGrade('C', SpeedTier.good);
  if (mbps >= 8) return const SpeedGrade('D', SpeedTier.moderate);
  return const SpeedGrade('E', SpeedTier.slow);
}
