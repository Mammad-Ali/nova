/// Накопленный трафик за текущий час и текущий день (Rx+Tx, байты).
class UsageStats {
  const UsageStats({
    required this.dayKey,
    required this.dayBytes,
    required this.hourKey,
    required this.hourBytes,
  });

  const UsageStats.empty()
      : dayKey = '',
        dayBytes = 0,
        hourKey = '',
        hourBytes = 0;

  /// Ключ дня, формат yyyy-MM-dd.
  final String dayKey;
  final int dayBytes;

  /// Ключ часа, формат yyyy-MM-dd-HH.
  final String hourKey;
  final int hourBytes;
}
