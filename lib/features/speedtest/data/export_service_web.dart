import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/entities/speedtest_record.dart';
import 'history_csv.dart';

/// Saving results in a browser: the file is handed over as a download, which
/// the browser files into the user's Downloads folder.
class ExportService {
  const ExportService();

  /// Returns the downloaded file's name.
  Future<String?> savePng(Uint8List bytes, {String? suggestedName}) async {
    final name = suggestedName ?? 'nova-speedtest.png';
    _download(bytes, name, 'image/png');
    return name;
  }

  Future<String?> saveHistoryCsv(List<SpeedTestRecord> records) async {
    const name = 'nova-history.csv';
    _download(
      Uint8List.fromList(utf8.encode(historyCsv(records))),
      name,
      'text/csv',
    );
    return name;
  }

  void _download(Uint8List bytes, String name, String mime) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    web.document.body?.append(link);
    link.click();
    link.remove();
    web.URL.revokeObjectURL(url);
  }
}
