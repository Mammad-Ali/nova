import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/speedtest_history_repository_impl.dart'
    show SpeedTestHistoryRepositoryImpl, speedTestHistoryRepositoryProvider;
import '../../domain/entities/speedtest_record.dart';
import '../../domain/repositories/speedtest_history_repository.dart';
import 'history_sync_provider.dart';

final speedTestHistoryProvider =
    NotifierProvider<SpeedTestHistoryNotifier, List<SpeedTestRecord>>(
        SpeedTestHistoryNotifier.new);

/// Stored results, oldest to newest. Persisted through
/// [SpeedTestHistoryRepository]; every change is written out immediately.
class SpeedTestHistoryNotifier extends Notifier<List<SpeedTestRecord>> {
  late final SpeedTestHistoryRepository _repo =
      ref.read(speedTestHistoryRepositoryProvider);
  final _loaded = Completer<void>();

  /// Completes once the stored history has been read.
  Future<void> get loaded => _loaded.future;

  @override
  List<SpeedTestRecord> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final stored = await _repo.loadAll();
    // A run that moved no data was never a measurement. The web engine used
    // to finish such runs and store them as 0 Mbps, which then showed up as a
    // "personal best: 0.0" and skewed the comparison with the previous test.
    final valid = stored
        .where((r) => r.downloadMbps > 0 && r.uploadMbps > 0)
        .toList();
    state = valid;
    if (!_loaded.isCompleted) _loaded.complete();
    if (valid.length != stored.length) await _repo.saveAll(valid);
  }

  Future<void> add(SpeedTestRecord record) async {
    final next = [...state, record];
    state = next;
    await _repo.saveAll(next);
    unawaited(ref.read(historySyncProvider.notifier).upload(record));
  }

  /// Clears the history here and, when signed in, in the account too.
  Future<void> clear() async {
    state = const [];
    await _repo.saveAll(const []);
    await ref.read(historySyncProvider.notifier).clearCloud();
  }

  /// Replaces the history with [records] — the result of a merge with the
  /// cloud. Only the newest entries are kept on the device; the account
  /// holds the rest.
  Future<void> replaceAll(List<SpeedTestRecord> records) async {
    const keep = SpeedTestHistoryRepositoryImpl.maxEntries;
    final next = records.length > keep ? records.sublist(records.length - keep) : records;
    state = next;
    await _repo.saveAll(next);
  }
}
