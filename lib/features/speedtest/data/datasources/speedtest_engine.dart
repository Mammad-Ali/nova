/// Picks the speed test engine that fits the platform.
///
/// On desktop and mobile the test runs in a background isolate over
/// `dart:io` sockets. A browser has neither, so the web build measures with
/// `XMLHttpRequest` instead. Both expose the same `SpeedTestEngine`, so
/// everything above this line is written once.
library;

export 'speedtest_engine_io.dart'
    if (dart.library.js_interop) 'speedtest_engine_web.dart';
