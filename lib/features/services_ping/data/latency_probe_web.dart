import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Median of three requests from the browser, in ms. Null if the service
/// never answered.
///
/// `no-cors` lets the page reach any service — the response is opaque, but
/// only its arrival time matters here. The figure includes the browser's own
/// overhead, which is why the sheet labels browser results approximate.
Future<double?> measureLatency(String url) async {
  // Warm-up, not counted: it pays for DNS and the TLS handshake.
  await _once(url);
  final rtts = <double>[];
  for (var i = 0; i < 3; i++) {
    final rtt = await _once(url);
    if (rtt != null) rtts.add(rtt);
  }
  if (rtts.isEmpty) return null;
  rtts.sort();
  return rtts[rtts.length ~/ 2];
}

Future<double?> _once(String url) async {
  try {
    final sw = Stopwatch()..start();
    await web.window
        .fetch(
          url.toJS,
          web.RequestInit(method: 'HEAD', mode: 'no-cors', cache: 'no-store'),
        )
        .toDart
        .timeout(const Duration(seconds: 5));
    sw.stop();
    return sw.elapsedMicroseconds / 1000.0;
  } catch (_) {
    return null;
  }
}
