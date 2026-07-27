import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/traffic_monitor/domain/entities/usage_stats.dart';

String _two(int n) => n.toString().padLeft(2, '0');

void main() {
  final now = DateTime.now();
  String dayOfMonth(int d) => '${now.year}-${_two(now.month)}-${_two(d)}';

  UsageStats withDays(Map<String, int> byDay) => UsageStats(
        dayKey: dayOfMonth(now.day),
        dayBytes: byDay[dayOfMonth(now.day)] ?? 0,
        hourKey: '',
        hourBytes: 0,
        byDay: byDay,
      );

  test('месячный итог складывает только дни текущего месяца', () {
    final stats = withDays({
      dayOfMonth(1): 100,
      dayOfMonth(2): 250,
      // Прошлый месяц — не должен попасть в сумму.
      '2000-01-15': 999999,
    });

    expect(stats.monthBytes, 350);
    expect(stats.currentMonthDays.length, 2);
  });

  test('дни месяца отсортированы по возрастанию даты', () {
    final stats = withDays({
      dayOfMonth(3): 30,
      dayOfMonth(1): 10,
      dayOfMonth(2): 20,
    });

    expect(stats.currentMonthDays.map((e) => e.value).toList(), [10, 20, 30]);
  });

  test('прогноз масштабирует текущий темп на длину месяца', () {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsed = (now.day - 1) + (now.hour * 60 + now.minute) / 1440.0;

    // Тест осмыслен только когда месяц уже начался (elapsed >= 0.2).
    if (elapsed < 0.2) return;

    const perDay = 1000;
    final stats = withDays({
      for (var d = 1; d <= now.day; d++) dayOfMonth(d): perDay,
    });

    final forecast = stats.monthForecastBytes;
    expect(forecast, isNotNull);

    final expected = (stats.monthBytes / elapsed * daysInMonth).round();
    // Допуск на минуту, прошедшую между вычислениями.
    expect((forecast! - expected).abs() < expected * 0.02, isTrue,
        reason: 'прогноз $forecast, ожидали ~$expected');
  });

  test('без данных прогноз не строится', () {
    expect(withDays({}).monthForecastBytes, isNull);
  });
}
