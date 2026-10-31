import 'entities/speedtest_record.dart';

/// What merging this device's history with the cloud's produced.
class HistoryMerge {
  const HistoryMerge({required this.merged, required this.toUpload});

  /// Every test known to either side, oldest first, each exactly once.
  final List<SpeedTestRecord> merged;

  /// Tests only this device had — the cloud still needs them.
  final List<SpeedTestRecord> toUpload;
}

/// A test is identified by the moment it finished, to the millisecond: the
/// same run seen from two devices, or uploaded twice, counts once. Two
/// different runs finishing in the same millisecond is not a real case.
int historyKey(SpeedTestRecord r) => r.timestamp.millisecondsSinceEpoch;

HistoryMerge mergeHistory(
  List<SpeedTestRecord> local,
  List<SpeedTestRecord> cloud,
) {
  final byKey = <int, SpeedTestRecord>{
    for (final r in cloud) historyKey(r): r,
  };
  final toUpload = <SpeedTestRecord>[];
  for (final r in local) {
    if (byKey.containsKey(historyKey(r))) continue;
    byKey[historyKey(r)] = r;
    toUpload.add(r);
  }
  final merged = byKey.values.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return HistoryMerge(merged: merged, toUpload: toUpload);
}
