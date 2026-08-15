import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/daily_usage_repository_impl.dart';
import '../../data/repositories/usage_stats_repository_impl.dart';
import '../../domain/entities/usage_stats.dart';
import 'traffic_provider.dart';

final usageStatsProvider =
    NotifierProvider<UsageStatsNotifier, UsageStats>(UsageStatsNotifier.new);

/// Totals traffic (Rx+Tx) for the current hour and day by summing the
/// per-second deltas from [trafficStreamProvider]. The baseline already
/// accumulated today is loaded from disk and flushed back periodically.
///
/// Caveat: counting only happens while the app is running; there is no
/// system-wide background accounting.
class UsageStatsNotifier extends Notifier<UsageStats> {
  late final UsageStatsRepository _repo =
      ref.read(usageStatsRepositoryProvider);
  late final DailyUsageRepository _dailyRepo =
      ref.read(dailyUsageRepositoryProvider);

  /// Daily buckets behind the monthly stats: 'yyyy-MM-dd' → bytes.
  Map<String, int> _byDay = {};

  String _dayKey = '';
  String _hourKey = '';
  int _dayBase = 0; // loaded from disk
  int _hourBase = 0;
  int _dayDelta = 0; // accumulated this session
  int _hourDelta = 0;

  Timer? _flushTimer;

  @override
  UsageStats build() {
    final now = DateTime.now();
    _dayKey = _dayKeyOf(now);
    _hourKey = _hourKeyOf(now);

    ref.listen(trafficStreamProvider, (_, next) {
      next.whenOrNull(data: (snap) => _add(snap.rxPerSec + snap.txPerSec));
    });

    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => _persist());
    ref.onDispose(() {
      _flushTimer?.cancel();
      _persist();
    });

    _loadBase();
    return UsageStats(
      dayKey: _dayKey,
      dayBytes: 0,
      hourKey: _hourKey,
      hourBytes: 0,
    );
  }

  Future<void> _loadBase() async {
    final saved = await _repo.load();
    // Reuse stored values only for the same day/hour; otherwise start at zero.
    if (saved.dayKey == _dayKey) _dayBase = saved.dayBytes;
    if (saved.hourKey == _hourKey) _hourBase = saved.hourBytes;

    _byDay = await _dailyRepo.load();
    // If the app was closed abruptly last time, the daily total may not have
    // reached the bucket — restore today's baseline from it.
    final storedToday = _byDay[_dayKey];
    if (storedToday != null && storedToday > _dayBase) _dayBase = storedToday;

    _emit();
  }

  void _add(int bytes) {
    final now = DateTime.now();
    final dk = _dayKeyOf(now);
    final hk = _hourKeyOf(now);

    if (dk != _dayKey) {
      _dayKey = dk;
      _dayBase = 0;
      _dayDelta = 0;
    }
    if (hk != _hourKey) {
      _hourKey = hk;
      _hourBase = 0;
      _hourDelta = 0;
    }

    _dayDelta += bytes;
    _hourDelta += bytes;
    _emit();
  }

  void _emit() {
    final dayTotal = _dayBase + _dayDelta;
    // Keep today's bucket current so the monthly stats include today without
    // waiting for the date to roll over.
    _byDay[_dayKey] = dayTotal;

    state = UsageStats(
      dayKey: _dayKey,
      dayBytes: dayTotal,
      hourKey: _hourKey,
      hourBytes: _hourBase + _hourDelta,
      byDay: Map.unmodifiable(_byDay),
    );
  }

  void _persist() {
    _repo.save(state);
    _dailyRepo.save(_byDay);
  }

  String _dayKeyOf(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';

  String _hourKeyOf(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}-${_two(t.hour)}';

  String _two(int n) => n.toString().padLeft(2, '0');
}
