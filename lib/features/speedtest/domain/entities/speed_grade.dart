/// Speed tier behind the final grade.
enum SpeedTier { blazing, fast, good, moderate, slow }

/// A letter grade plus the tier, derived from download speed.
class SpeedGrade {
  const SpeedGrade(this.letter, this.tier);
  final String letter;
  final SpeedTier tier;
}

/// Computes the grade from download speed (Mbps).
SpeedGrade gradeForDownload(double mbps) {
  if (mbps >= 300) return const SpeedGrade('A+', SpeedTier.blazing);
  if (mbps >= 150) return const SpeedGrade('A', SpeedTier.blazing);
  if (mbps >= 75) return const SpeedGrade('A', SpeedTier.fast);
  if (mbps >= 40) return const SpeedGrade('B', SpeedTier.fast);
  if (mbps >= 20) return const SpeedGrade('C', SpeedTier.good);
  if (mbps >= 8) return const SpeedGrade('D', SpeedTier.moderate);
  return const SpeedGrade('E', SpeedTier.slow);
}
