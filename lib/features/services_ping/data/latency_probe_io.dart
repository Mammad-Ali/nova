import 'dart:io';

/// Median of three HEAD requests over one reused connection, in ms. Null if
/// the service never answered.
Future<double?> measureLatency(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 10);
  final uri = Uri.parse(url);
  final rtts = <double>[];

  try {
    // Warm-up absorbs DNS + TLS; the rest reuses the live connection.
    await _once(client, uri);
    for (var i = 0; i < 3; i++) {
      final rtt = await _once(client, uri);
      if (rtt != null) rtts.add(rtt);
    }
  } finally {
    client.close(force: true);
  }

  if (rtts.isEmpty) return null;
  rtts.sort();
  return rtts[rtts.length ~/ 2];
}

Future<double?> _once(HttpClient c, Uri uri) async {
  try {
    final sw = Stopwatch()..start();
    final req = await c.headUrl(uri);
    final resp = await req.close().timeout(const Duration(seconds: 5));
    await resp.drain<void>();
    sw.stop();
    return sw.elapsedMicroseconds / 1000.0;
  } catch (_) {
    return null;
  }
}
