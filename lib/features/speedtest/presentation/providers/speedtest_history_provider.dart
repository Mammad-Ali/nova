import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/speedtest_history_repository_impl.dart'
    show speedTestHistoryRepositoryProvider;
import '../../domain/entities/speedtest_record.dart';
import '../../domain/repositories/speedtest_history_repository.dart';

final speedTestHistoryProvider =
    NotifierProvider<SpeedTestHistoryNotifier, List<SpeedTestRecord>>(
        SpeedTestHistoryNotifier.new);

/// Список сохранённых результатов, старые → новые. Хранится на диске через
/// [SpeedTestHistoryRepository]; каждое изменение сразу сохраняется.
class SpeedTestHistoryNotifier extends Notifier<List<SpeedTestRecord>> {
  late final SpeedTestHistoryRepository _repo =
      ref.read(speedTestHistoryRepositoryProvider);

  @override
  List<SpeedTestRecord> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await _repo.loadAll();
  }

  Future<void> add(SpeedTestRecord record) async {
    final next = [...state, record];
    state = next;
    await _repo.saveAll(next);
  }

  Future<void> clear() async {
    state = const [];
    await _repo.saveAll(const []);
  }
}
