import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';
import '../domain/entities/speedtest_record.dart';
import '../domain/history_merge.dart';

/// Someone's test history in Firestore: `users/{uid}/tests/{id}`, one
/// document per test, named after the moment it finished — so writing the
/// same test twice only overwrites it.
class CloudHistoryRepository {
  const CloudHistoryRepository(this._db);

  final FirestoreClient _db;

  /// Upper bound on what one device pulls down; the newest come first.
  static const pullLimit = 1000;

  String _collection(String uid) => 'users/$uid/tests';

  Future<List<SpeedTestRecord>> load(String uid) async {
    final docs = await _db.list(_collection(uid), orderBy: 't desc', limit: pullLimit);
    return [
      for (final d in docs)
        if (d.data['t'] is DateTime)
          SpeedTestRecord(
            // Firestore hands timestamps back in UTC; history is shown in
            // local time.
            timestamp: (d.data['t'] as DateTime).toLocal(),
            downloadMbps: asDouble(d.data['d']),
            uploadMbps: asDouble(d.data['u']),
            pingMs: asDouble(d.data['p']),
            jitterMs: asDouble(d.data['j']),
          ),
    ];
  }

  /// Uploads [records] in batched writes.
  Future<void> add(String uid, List<SpeedTestRecord> records) async {
    if (records.isEmpty) return;
    await _db.commit([
      for (final r in records)
        {
          'update': {
            'name': FirestoreClient.documentName('${_collection(uid)}/${historyKey(r)}'),
            'fields': encodeFields({
              't': r.timestamp,
              'd': r.downloadMbps,
              'u': r.uploadMbps,
              'p': r.pingMs,
              'j': r.jitterMs,
              'platform': _platform,
            }),
          },
        },
    ]);
  }

  /// Deletes the whole history, page by page.
  Future<void> deleteAll(String uid) async {
    while (true) {
      final docs = await _db.list(_collection(uid), limit: 500);
      if (docs.isEmpty) return;
      await _db.commit([
        for (final d in docs)
          {'delete': FirestoreClient.documentName('${_collection(uid)}/${d.id}')},
      ]);
      if (docs.length < 500) return;
    }
  }

  /// Where a test was taken, kept for the record: web, macOS, windows, android.
  static String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;
}
