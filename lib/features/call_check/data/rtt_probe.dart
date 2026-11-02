/// One round trip at a time to a tiny endpoint, over a connection that stays
/// open between trips — the steady back-and-forth a call produces.
///
/// The app uses its own HTTP connection; a web page goes through `fetch`,
/// whose timings include the browser's overhead.
library;

export 'rtt_probe_io.dart' if (dart.library.js_interop) 'rtt_probe_web.dart';
