/// One app's share of the traffic.
class AppTraffic {
  const AppTraffic({
    required this.name,
    required this.bytesIn,
    required this.bytesOut,
    this.rateIn = 0,
    this.rateOut = 0,
    this.kind = AppTrafficKind.app,
  });

  /// The app's name; empty for the kinds other than [AppTrafficKind.app],
  /// which the card names itself.
  final String name;

  /// Received and sent: on macOS since the app started, on Android today.
  final int bytesIn;
  final int bytesOut;

  /// Bytes per second right now. macOS only; Android counts in buckets of
  /// hours, so it has no "now".
  final double rateIn;
  final double rateOut;

  final AppTrafficKind kind;

  int get total => bytesIn + bytesOut;
  double get rate => rateIn + rateOut;
}

enum AppTrafficKind {
  app,

  /// The operating system's own services, together.
  system,

  /// Apps uninstalled since (Android).
  removed,

  /// Devices using this phone as a hotspot (Android).
  hotspot,
}
