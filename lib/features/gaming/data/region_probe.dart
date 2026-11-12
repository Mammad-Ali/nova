/// One round trip to a data centre, timed the way the platform allows: the
/// app over its own reused connection, the browser with `fetch`.
library;

export 'region_probe_io.dart'
    if (dart.library.js_interop) 'region_probe_web.dart';
