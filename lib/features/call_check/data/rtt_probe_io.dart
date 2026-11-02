import 'dart:io';

/// See rtt_probe.dart.
class RttProbe {
  RttProbe();

  /// A zero-byte answer from Cloudflare's edge, which is close to everyone.
  static final _url = Uri.parse('https://speed.cloudflare.com/__down?bytes=0');

  /// A reply slower than this would already have frozen a call, so it
  /// counts as lost.
  static const _timeout = Duration(seconds: 2);

  final HttpClient _client = HttpClient()
    ..connectionTimeout = _timeout
    ..idleTimeout = const Duration(seconds: 30);

  /// One round trip in ms, or null when it was lost.
  Future<double?> once() async {
    try {
      final sw = Stopwatch()..start();
      final request = await _client.getUrl(_url).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().timeout(_timeout);
      sw.stop();
      return response.statusCode == 200 ? sw.elapsedMicroseconds / 1000.0 : null;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close(force: true);
}
