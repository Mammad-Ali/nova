import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../domain/entities/speedtest_record.dart';

/// Saves results to disk as an image or CSV.
///
/// The user picks the path through the system dialog, which also satisfies
/// the macOS sandbox: access is granted for exactly the chosen file.
class ExportService {
  const ExportService();

  /// Returns the saved file's path, or null if the user cancelled.
  Future<String?> savePng(Uint8List bytes, {String? suggestedName}) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName ?? 'nova-speedtest.png',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG', extensions: ['png']),
      ],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes);
    return location.path;
  }

  /// Exports the test history as CSV.
  Future<String?> saveHistoryCsv(List<SpeedTestRecord> records) async {
    final location = await getSaveLocation(
      suggestedName: 'nova-history.csv',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return null;

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
    await File(location.path).writeAsString(buf.toString());
    return location.path;
  }
}
