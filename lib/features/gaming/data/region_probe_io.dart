import 'dart:io';

/// See region_probe.dart.
class RegionProbe {
  RegionProbe(this.url);
  final String url;

  /// Slower than this is no use to a game: counted as lost.
  static const _timeout = Duration(seconds: 2);

  late final HttpClient _client = HttpClient()
    ..connectionTimeout = _timeout
    ..idleTimeout = const Duration(seconds: 30);

  /// One round trip in ms over the open connection, or null when lost.
  Future<double?> once() async {
    try {
      final sw = Stopwatch()..start();
      final request = await _client.getUrl(Uri.parse(url)).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().timeout(_timeout);
      sw.stop();
      return response.statusCode < 500 ? sw.elapsedMicroseconds / 1000.0 : null;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close(force: true);
}
