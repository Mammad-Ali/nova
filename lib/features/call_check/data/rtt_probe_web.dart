import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// See rtt_probe.dart.
class RttProbe {
  RttProbe();

  static const _url = 'https://speed.cloudflare.com/__down?bytes=0';
  static const _timeout = Duration(seconds: 2);

  /// One round trip in ms, or null when it was lost.
  Future<double?> once() async {
    try {
      final sw = Stopwatch()..start();
      final response = await web.window
          .fetch(_url.toJS, web.RequestInit(cache: 'no-store'))
          .toDart
          .timeout(_timeout);
      await response.arrayBuffer().toDart.timeout(_timeout);
      sw.stop();
      return response.ok ? sw.elapsedMicroseconds / 1000.0 : null;
    } catch (_) {
      return null;
    }
  }

  void close() {}
}
