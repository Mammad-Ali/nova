import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/usage_stats.dart';

final usageStatsRepositoryProvider = Provider<UsageStatsRepository>((ref) {
  return UsageStatsRepository();
});

/// Keeps the hourly/daily totals in SharedPreferences so they survive an app
/// restart within the same hour or day.
class UsageStatsRepository {
  static const _dayKeyK = 'usage_day_key';
  static const _dayBytesK = 'usage_day_bytes';
  static const _hourKeyK = 'usage_hour_key';
  static const _hourBytesK = 'usage_hour_bytes';

  Future<UsageStats> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UsageStats(
        dayKey: prefs.getString(_dayKeyK) ?? '',
        dayBytes: prefs.getInt(_dayBytesK) ?? 0,
        hourKey: prefs.getString(_hourKeyK) ?? '',
        hourBytes: prefs.getInt(_hourBytesK) ?? 0,
      );
    } catch (_) {
      return const UsageStats.empty();
    }
  }

  Future<void> save(UsageStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dayKeyK, stats.dayKey);
      await prefs.setInt(_dayBytesK, stats.dayBytes);
      await prefs.setString(_hourKeyK, stats.hourKey);
      await prefs.setInt(_hourBytesK, stats.hourBytes);
    } catch (_) {}
  }
}
