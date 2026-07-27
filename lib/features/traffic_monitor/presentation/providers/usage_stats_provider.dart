import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/usage_stats_repository_impl.dart';
import '../../domain/entities/usage_stats.dart';
import 'traffic_provider.dart';

final usageStatsProvider =
    NotifierProvider<UsageStatsNotifier, UsageStats>(UsageStatsNotifier.new);

/// Считает суммарный трафик (Rx+Tx) за текущий час и день, складывая
/// посекундные дельты из [trafficStreamProvider]. База (то, что уже накоплено
/// сегодня/в этом часу) подгружается с диска и периодически туда сбрасывается.
///
/// Ограничение: считается только пока приложение открыто — системного учёта в
/// фоне тут нет.
class UsageStatsNotifier extends Notifier<UsageStats> {
  late final UsageStatsRepository _repo =
      ref.read(usageStatsRepositoryProvider);

  String _dayKey = '';
  String _hourKey = '';
  int _dayBase = 0; // загружено с диска
  int _hourBase = 0;
  int _dayDelta = 0; // накоплено в этой сессии
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
    // Берём сохранённое только если это тот же день/час — иначе начинаем с нуля.
    if (saved.dayKey == _dayKey) _dayBase = saved.dayBytes;
    if (saved.hourKey == _hourKey) _hourBase = saved.hourBytes;
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
    state = UsageStats(
      dayKey: _dayKey,
      dayBytes: _dayBase + _dayDelta,
      hourKey: _hourKey,
      hourBytes: _hourBase + _hourDelta,
    );
  }

  void _persist() => _repo.save(state);

  String _dayKeyOf(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';

  String _hourKeyOf(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}-${_two(t.hour)}';

  String _two(int n) => n.toString().padLeft(2, '0');
}
