/// Round-trip time to one service, measured the way the platform allows.
///
/// The app times HEAD requests over its own connection; a web page cannot
/// open one, so the browser variant times `fetch` in no-cors mode instead.
/// Both warm the connection up first and report the median of three.
library;

export 'latency_probe_io.dart'
    if (dart.library.js_interop) 'latency_probe_web.dart';
