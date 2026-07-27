/// Накопленный трафик за текущий час и день (Rx+Tx, байты) плюс история
/// по дням — из неё считаются месячный итог и прогноз расхода.
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

  /// Ключ дня, формат yyyy-MM-dd.
  final String dayKey;
  final int dayBytes;

  /// Ключ часа, формат yyyy-MM-dd-HH.
  final String hourKey;
  final int hourBytes;

  /// Трафик по дням: 'yyyy-MM-dd' → байты. Включает сегодняшний день.
  final Map<String, int> byDay;

  /// Префикс текущего месяца, 'yyyy-MM'.
  String get _monthPrefix =>
      dayKey.length >= 7 ? dayKey.substring(0, 7) : '';

  /// Дни текущего месяца, по возрастанию даты.
  List<MapEntry<String, int>> get currentMonthDays {
    final prefix = _monthPrefix;
    if (prefix.isEmpty) return const [];
    final entries = byDay.entries.where((e) => e.key.startsWith(prefix)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Суммарный трафик за текущий месяц.
  int get monthBytes {
    var sum = 0;
    for (final e in currentMonthDays) {
      sum += e.value;
    }
    return sum;
  }

  /// Прогноз расхода к концу месяца по текущему темпу.
  ///
  /// Считаем среднее за прошедшую часть месяца (с дробным «сегодня», чтобы
  /// утром прогноз не завышался) и умножаем на длину месяца.
  /// null — если данных ещё слишком мало, чтобы прогноз был осмысленным.
  int? get monthForecastBytes {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsed = (now.day - 1) + (now.hour * 60 + now.minute) / 1440.0;
    if (elapsed < 0.2 || monthBytes <= 0) return null; // рано прогнозировать
    return (monthBytes / elapsed * daysInMonth).round();
  }
}
