/// What a browser tells a page about its connection (the Network
/// Information API): Chrome, Edge and Android browsers do; Safari and
/// Firefox don't, and the apps have better figures of their own.
library;

export 'browser_connection_io.dart' if (dart.library.js_interop) 'browser_connection_web.dart';

/// The browser's own estimates; any of them may be missing.
class BrowserConnection {
  const BrowserConnection({this.type, this.effectiveType, this.downlinkMbps, this.rttMs, this.saveData = false});

  /// "wifi", "cellular", "ethernet" — Android browsers only.
  final String? type;

  /// How the connection behaves, as the browser rounds it: "4g", "3g"…
  final String? effectiveType;

  /// Estimated download speed, rounded by the browser (to 25 kbps, capped
  /// at 10 Mbps in Chrome).
  final double? downlinkMbps;

  /// Estimated round trip, rounded to 25 ms.
  final int? rttMs;

  /// The visitor asked for less data.
  final bool saveData;
}
