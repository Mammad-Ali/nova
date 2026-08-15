/// Traffic accumulated over the current hour and day (Rx+Tx, bytes) plus a
/// per-day history, from which the monthly total and forecast are derived.
class UsageStats {
  const UsageStats({
    required this.dayKey,
    required this.dayBytes,
    required this.hourKey,
    required this.hourBytes,
    this.byDay = const {},
  });

  const UsageStats.empty()
      : dayKey = '',
        dayBytes = 0,
        hourKey = '',
        hourBytes = 0,
        byDay = const {};

  /// Day key, formatted yyyy-MM-dd.
  final String dayKey;
  final int dayBytes;

  /// Hour key, formatted yyyy-MM-dd-HH.
  final String hourKey;
  final int hourBytes;

  /// Traffic per day: 'yyyy-MM-dd' → bytes. Includes today.
  final Map<String, int> byDay;

  /// Current month prefix, 'yyyy-MM'.
  String get _monthPrefix =>
      dayKey.length >= 7 ? dayKey.substring(0, 7) : '';

  /// Days of the current month, oldest first.
  List<MapEntry<String, int>> get currentMonthDays {
    final prefix = _monthPrefix;
    if (prefix.isEmpty) return const [];
    final entries = byDay.entries.where((e) => e.key.startsWith(prefix)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Total traffic for the current month.
  int get monthBytes {
    var sum = 0;
    for (final e in currentMonthDays) {
      sum += e.value;
    }
    return sum;
  }

  /// Projected usage by the end of the month at the current pace.
  ///
  /// Averages over the elapsed part of the month (today counted as a
  /// fraction, so mornings don't inflate the estimate) and scales it to the
  /// month's length. Returns null while there is too little data to be useful.
  int? get monthForecastBytes {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsed = (now.day - 1) + (now.hour * 60 + now.minute) / 1440.0;
    if (elapsed < 0.2 || monthBytes <= 0) return null; // too early to forecast
    return (monthBytes / elapsed * daysInMonth).round();
  }
}
