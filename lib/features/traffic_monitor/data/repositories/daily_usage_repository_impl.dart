import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dailyUsageRepositoryProvider = Provider<DailyUsageRepository>((ref) {
  return DailyUsageRepository();
});

/// Stores total traffic per day: `{'2026-07-27': 1234567, …}`.
///
/// Backs the monthly stats and the forecast: unlike the hour/day counters,
/// these buckets survive the date rolling over.
class DailyUsageRepository {
  static const _key = 'daily_usage_v1';

  /// Two months is enough for "last month" and for the charts, while keeping
  /// the settings file small.
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
      // Keep only the most recent maxDays: yyyy-MM-dd keys sort
      // lexicographically the same way they sort chronologically.
      final keys = byDay.keys.toList()..sort();
      final trimmed = keys.length > maxDays
          ? {for (final k in keys.sublist(keys.length - maxDays)) k: byDay[k]!}
          : byDay;
      await prefs.setString(_key, jsonEncode(trimmed));
    } catch (_) {}
  }
}
