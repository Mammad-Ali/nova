import '../domain/entities/speedtest_record.dart';

/// The test history as CSV — the same text whether it is written to disk by
/// the app or handed to the browser as a download.
String historyCsv(List<SpeedTestRecord> records) {
  final buf = StringBuffer()
    ..writeln('timestamp,download_mbps,upload_mbps,ping_ms,jitter_ms');
  for (final r in records) {
    buf.writeln([
      r.timestamp.toIso8601String(),
      r.downloadMbps.toStringAsFixed(2),
      r.uploadMbps.toStringAsFixed(2),
      r.pingMs.toStringAsFixed(2),
      r.jitterMs.toStringAsFixed(2),
    ].join(','));
  }
  return buf.toString();
}
