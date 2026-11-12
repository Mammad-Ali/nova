import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What each app moved per day: `{'2026-11-12': {'app:Telegram': [in, out]}}`.
///
/// The Mac keeps this itself — nettop only knows each running app's total
/// since it started. Android's system keeps its own, so it never uses this.
class AppUsageRepository {
  static const _key = 'app_usage_v1';
  static const _iconsKey = 'app_icons_v1';

  /// Five weeks: a week to show, with room to spare.
  static const maxDays = 35;

  /// Busy days can see hundreds of tiny helpers; the long tail is dropped.
  static const maxAppsPerDay = 80;

  Future<Map<String, Map<String, (int, int)>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(_key));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, Map<String, (int, int)>> byDay) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, encode(byDay));
    } catch (_) {}
  }

  /// App → where its icon is, remembered so a day's list still has icons
  /// after the app has quit.
  Future<Map<String, String>> loadIcons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_iconsKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveIcons(Map<String, String> icons) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_iconsKey, jsonEncode(icons));
    } catch (_) {}
  }

  static Map<String, Map<String, (int, int)>> decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final MapEntry(key: day, value: apps) in decoded.entries)
        day: {
          for (final MapEntry(key: app, value: pair) in (apps as Map<String, dynamic>).entries)
            app: (((pair as List)[0] as num).toInt(), (pair[1] as num).toInt()),
        },
    };
  }

  /// The JSON, keeping only the latest [maxDays] and each day's
  /// [maxAppsPerDay] busiest apps.
  static String encode(Map<String, Map<String, (int, int)>> byDay) {
    final days = byDay.keys.toList()..sort();
    final kept = days.length > maxDays ? days.sublist(days.length - maxDays) : days;
    return jsonEncode({
      for (final day in kept)
        day: {
          for (final e in (byDay[day]!.entries.toList()
                ..sort((a, b) => (b.value.$1 + b.value.$2).compareTo(a.value.$1 + a.value.$2)))
              .take(maxAppsPerDay))
            e.key: [e.value.$1, e.value.$2],
        },
    });
  }
}

/// "2026-11-12" for [time]'s local date.
String dayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
