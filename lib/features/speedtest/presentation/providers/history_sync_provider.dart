import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_session.dart';
import '../../../leaderboard/domain/leaderboard_models.dart';
import '../../../leaderboard/presentation/leaderboard_providers.dart';
import '../../data/cloud_history_repository.dart';
import '../../domain/entities/speedtest_record.dart';
import '../../domain/history_merge.dart';
import 'speedtest_history_provider.dart';

enum SyncStatus { off, syncing, synced, failed }

/// Keeps the test history in the signed-in account.
///
/// On sign-in — and on every start while signed in — the device's history
/// and the account's are merged both ways: tests only here go up, tests from
/// other devices come down. Each new test is uploaded as it finishes; one
/// that fails to upload (offline) is picked up by the next merge, so nothing
/// needs a separate retry queue.
final historySyncProvider =
    NotifierProvider<HistorySyncNotifier, SyncStatus>(HistorySyncNotifier.new);

class HistorySyncNotifier extends Notifier<SyncStatus> {
  CloudHistoryRepository get _cloud => CloudHistoryRepository(ref.read(firestoreProvider));

  @override
  SyncStatus build() {
    ref.listen<NovaAccount?>(accountProvider, (previous, next) {
      if (next == null || next.demo) {
        state = SyncStatus.off;
      } else if (next.id != previous?.id) {
        sync();
      }
    });
    return SyncStatus.off;
  }

  /// The real, signed-in account, or null.
  NovaAccount? get _account {
    final a = ref.read(accountProvider);
    return a == null || a.demo ? null : a;
  }

  Future<void> sync() async {
    final account = _account;
    if (account == null || state == SyncStatus.syncing) return;
    state = SyncStatus.syncing;
    try {
      final history = ref.read(speedTestHistoryProvider.notifier);
      // The device's history loads asynchronously; merging before it arrives
      // would treat it as empty and overwrite it with the cloud's.
      await history.loaded;
      final result = mergeHistory(
        ref.read(speedTestHistoryProvider),
        await _cloud.load(account.id),
      );
      await _cloud.add(account.id, result.toUpload);
      await history.replaceAll(result.merged);
      state = SyncStatus.synced;
    } catch (_) {
      state = SyncStatus.failed;
    }
  }

  /// Called for every finished test.
  Future<void> upload(SpeedTestRecord record) async {
    final account = _account;
    if (account == null) return;
    try {
      await _cloud.add(account.id, [record]);
      if (state != SyncStatus.syncing) state = SyncStatus.synced;
    } catch (_) {
      state = SyncStatus.failed; // the next merge uploads it
    }
  }

  /// Called when the history is cleared on this device.
  Future<void> clearCloud() async {
    final account = _account;
    if (account == null) return;
    try {
      await _cloud.deleteAll(account.id);
      state = SyncStatus.synced;
    } catch (_) {
      state = SyncStatus.failed;
    }
  }
}
