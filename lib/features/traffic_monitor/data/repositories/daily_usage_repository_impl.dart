import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dailyUsageRepositoryProvider = Provider<DailyUsageRepository>((ref) {
  return DailyUsageRepository();
});

/// Хранит суммарный трафик по дням: `{'2026-07-27': 1234567, …}`.
///
/// Нужен для месячной статистики и прогноза — в отличие от счётчиков
/// час/день, эти корзины переживают смену суток.
class DailyUsageRepository {
  static const _key = 'daily_usage_v1';

  /// Держим два месяца — этого хватает и на «прошлый месяц», и на графики,
  /// а файл настроек не разрастается.
  static const maxDays = 62;

  Future<Map<String, int>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, int> byDay) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Оставляем только последние maxDays — ключи вида yyyy-MM-dd
      // сортируются лексикографически как хронологически.
      final keys = byDay.keys.toList()..sort();
      final trimmed = keys.length > maxDays
          ? {for (final k in keys.sublist(keys.length - maxDays)) k: byDay[k]!}
          : byDay;
      await prefs.setString(_key, jsonEncode(trimmed));
    } catch (_) {}
  }
}
