import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../domain/entities/speedtest_record.dart';

/// Сохранение результатов на диск: картинка и CSV.
///
/// Путь выбирает сам пользователь через системный диалог — так работает и в
/// песочнице macOS (доступ выдаётся именно на выбранный файл).
class ExportService {
  const ExportService();

  /// Возвращает путь сохранённого файла или null, если пользователь отменил.
  Future<String?> savePng(Uint8List bytes, {String? suggestedName}) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName ?? 'pulsar-speedtest.png',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG', extensions: ['png']),
      ],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes);
    return location.path;
  }

  /// Экспорт истории тестов в CSV.
  Future<String?> saveHistoryCsv(List<SpeedTestRecord> records) async {
    final location = await getSaveLocation(
      suggestedName: 'pulsar-history.csv',
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
