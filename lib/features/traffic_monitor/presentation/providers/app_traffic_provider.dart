import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/app_traffic_source.dart';
import '../../domain/entities/app_traffic.dart';
import 'app_usage_tracker.dart';

/// Where the "apps using the network" numbers come from.
enum AppTrafficMode {
  /// macOS: Nova watches the apps itself (macAppUsageProvider).
  mac,

  /// Android: the system's network statistics.
  android,

  /// Windows, Linux, the browser: the system doesn't say.
  unavailable,
}

class AppTrafficState {
  const AppTrafficState({
    required this.mode,
    required this.period,
    this.apps = const [],
    this.loaded = false,
    this.needsAccess = false,
  });

  final AppTrafficMode mode;
  final AppPeriod period;

  /// Most traffic first.
  final List<AppTraffic> apps;

  /// False until the first reading arrives.
  final bool loaded;

  /// Android without Usage access: the card offers to open the setting.
  final bool needsAccess;

  /// The periods offered: "now" is the Mac's alone.
  List<AppPeriod> get periods => mode == AppTrafficMode.mac
      ? AppPeriod.values
      : const [AppPeriod.today, AppPeriod.week];

  AppTrafficState copyWith({
    AppPeriod? period,
    List<AppTraffic>? apps,
    bool? loaded,
    bool? needsAccess,
  }) =>
      AppTrafficState(
        mode: mode,
        period: period ?? this.period,
        apps: apps ?? this.apps,
        loaded: loaded ?? this.loaded,
        needsAccess: needsAccess ?? this.needsAccess,
      );
}

AppTrafficMode get _mode {
  if (kIsWeb) return AppTrafficMode.unavailable;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => AppTrafficMode.mac,
    TargetPlatform.android => AppTrafficMode.android,
    _ => AppTrafficMode.unavailable,
  };
}

/// The apps card's data, while the Monitor tab is on screen.
final appTrafficProvider =
    NotifierProvider.autoDispose<AppTrafficNotifier, AppTrafficState>(AppTrafficNotifier.new);

class AppTrafficNotifier extends Notifier<AppTrafficState> {
  AndroidAppTrafficSource? _android;
  var _busy = false;

  /// The period picked last, kept while Nova runs.
  static AppPeriod? _remembered;

  @override
  AppTrafficState build() {
    final mode = _mode;
    final period = _remembered ?? AppPeriod.today;
    switch (mode) {
      case AppTrafficMode.mac:
        final usage = ref.watch(macAppUsageProvider);
        return AppTrafficState(
          mode: mode,
          period: period,
          apps: _macApps(usage, period),
          loaded: usage.loaded,
        );
      case AppTrafficMode.android:
        _android = AndroidAppTrafficSource();
        final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
        // Back from the Usage access setting: the answer may have changed.
        final lifecycle = AppLifecycleListener(onResume: refresh);
        ref.onDispose(() {
          timer.cancel();
          lifecycle.dispose();
        });
        Future.microtask(refresh);
        return AppTrafficState(mode: mode, period: period);
      case AppTrafficMode.unavailable:
        return AppTrafficState(mode: mode, period: period, loaded: true);
    }
  }

  void setPeriod(AppPeriod period) {
    _remembered = period;
    if (state.mode == AppTrafficMode.mac) {
      state = state.copyWith(period: period, apps: _macApps(ref.read(macAppUsageProvider), period));
    } else {
      state = state.copyWith(period: period, loaded: false);
      unawaited(refresh());
    }
  }

  static List<AppTraffic> _macApps(MacAppUsage usage, AppPeriod period) => switch (period) {
        // By total: speeds change every reading, and a list sorted by them
        // would never hold still long enough to read.
        AppPeriod.now => [...usage.live]..sort((a, b) => b.total.compareTo(a.total)),
        AppPeriod.today => usage.over(1),
        AppPeriod.week => usage.over(7),
      };

  Future<void> refresh() async {
    final android = _android;
    if (android == null || _busy) return;
    _busy = true;
    try {
      final access = await android.hasAccess();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final from = state.period == AppPeriod.week ? midnight.subtract(const Duration(days: 6)) : midnight;
      final apps = access ? await android.range(from, now) : null;
      if (!ref.mounted) return;
      state = state.copyWith(
        apps: [...?apps]..sort((a, b) => b.total.compareTo(a.total)),
        loaded: true,
        needsAccess: !access,
      );
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loaded: true);
    } finally {
      _busy = false;
    }
  }

  /// One app's total for each of the last seven days, oldest first.
  Future<List<int>> week(String key) async {
    if (state.mode == AppTrafficMode.mac) return ref.read(macAppUsageProvider).daily(key, 7);
    final android = _android;
    if (android == null) return List.filled(7, 0);
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return Future.wait([
      for (var i = 6; i >= 0; i--)
        android
            .range(midnight.subtract(Duration(days: i)),
                i == 0 ? now : midnight.subtract(Duration(days: i - 1)))
            .then((apps) => apps?.where((a) => a.key == key).firstOrNull?.total ?? 0),
    ]);
  }

  Future<void> openAccessSettings() async => _android?.openAccessSettings();
}
