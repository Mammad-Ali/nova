/// One app's share of the traffic.
class AppTraffic {
  const AppTraffic({
    required this.name,
    required this.bytesIn,
    required this.bytesOut,
    this.rateIn = 0,
    this.rateOut = 0,
    this.kind = AppTrafficKind.app,
    this.iconSource,
  });

  /// The app's name; empty for the kinds other than [AppTrafficKind.app],
  /// which the card names itself.
  final String name;

  /// Received and sent over the period being shown.
  final int bytesIn;
  final int bytesOut;

  /// Bytes per second right now. macOS's "Now" only; Android counts in
  /// buckets of hours, so it has no "now".
  final double rateIn;
  final double rateOut;

  final AppTrafficKind kind;

  /// Where the system finds the app's icon: the app bundle's path on macOS
  /// ("/Applications/Google Chrome.app"), the package name on Android.
  final String? iconSource;

  int get total => bytesIn + bytesOut;
  double get rate => rateIn + rateOut;

  /// Identifies the app across days and periods: "app:Telegram",
  /// "system:".
  String get key => appKey(kind, name);

  AppTraffic copyWith({int? bytesIn, int? bytesOut, String? iconSource}) => AppTraffic(
        name: name,
        bytesIn: bytesIn ?? this.bytesIn,
        bytesOut: bytesOut ?? this.bytesOut,
        rateIn: rateIn,
        rateOut: rateOut,
        kind: kind,
        iconSource: iconSource ?? this.iconSource,
      );
}

String appKey(AppTrafficKind kind, String name) => '${kind.name}:$name';

/// The other way round: an [AppTraffic] with no traffic for [key].
AppTraffic appFromKey(String key, {int bytesIn = 0, int bytesOut = 0, String? iconSource}) {
  final colon = key.indexOf(':');
  final kind = AppTrafficKind.values.firstWhere(
    (k) => k.name == key.substring(0, colon < 0 ? 0 : colon),
    orElse: () => AppTrafficKind.app,
  );
  return AppTraffic(
    name: colon < 0 ? key : key.substring(colon + 1),
    kind: kind,
    bytesIn: bytesIn,
    bytesOut: bytesOut,
    iconSource: iconSource,
  );
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

/// Which stretch of time the apps card shows.
enum AppPeriod {
  /// Speed right now, and totals since each app started. macOS only.
  now,
  today,
  week,
}
