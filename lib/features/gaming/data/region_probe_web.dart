import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// See region_probe.dart. `no-cors` reaches any server; the answer is
/// opaque, and only its arrival time matters.
class RegionProbe {
  RegionProbe(this.url);
  final String url;

  static const _timeout = Duration(seconds: 2);

  Future<double?> once() async {
    try {
      final sw = Stopwatch()..start();
      await web.window
          .fetch(url.toJS, web.RequestInit(mode: 'no-cors', cache: 'no-store'))
          .toDart
          .timeout(_timeout);
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    }
  }

  void close() {}
}
