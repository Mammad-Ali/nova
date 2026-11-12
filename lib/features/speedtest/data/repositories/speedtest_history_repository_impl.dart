import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/speedtest_record.dart';
import '../../domain/repositories/speedtest_history_repository.dart';

final speedTestHistoryRepositoryProvider =
    Provider<SpeedTestHistoryRepository>((ref) {
  return SpeedTestHistoryRepositoryImpl();
});

class SpeedTestHistoryRepositoryImpl implements SpeedTestHistoryRepository {
  static const _key = 'speedtest_history_v1';

  /// About a month of hourly automatic tests, enough for a report to the
  /// provider (report_sheet.dart); some 80 KB of settings.
  static const maxEntries = 1000;

  @override
  Future<List<SpeedTestRecord>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SpeedTestRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Storage unavailable or data corrupted — return an empty history
      // rather than crashing.
      return const [];
    }
  }

  @override
  Future<void> saveAll(List<SpeedTestRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = records.length > maxEntries
          ? records.sublist(records.length - maxEntries)
          : records;
      final raw = jsonEncode(trimmed.map((r) => r.toJson()).toList());
      await prefs.setString(_key, raw);
    } catch (_) {}
  }
}
