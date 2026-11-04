import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/app_traffic_source.dart';
import '../../domain/entities/app_traffic.dart';

/// What the "apps using the network" card can show here.
enum AppTrafficMode {
  /// macOS: speed right now, and totals since each app started.
  live,

  /// Android: totals since midnight.
  today,

  /// Windows, Linux, the browser: the system doesn't say.
  unavailable,
}

class AppTrafficState {
  const AppTrafficState({
    required this.mode,
    this.apps = const [],
    this.loaded = false,
    this.needsAccess = false,
  });

  final AppTrafficMode mode;

  /// Most traffic first.
  final List<AppTraffic> apps;

  /// False until the first reading arrives.
  final bool loaded;

  /// Android without Usage access: the card offers to open the setting.
  final bool needsAccess;
}

AppTrafficMode get _mode {
  if (kIsWeb) return AppTrafficMode.unavailable;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => AppTrafficMode.live,
    TargetPlatform.android => AppTrafficMode.today,
    _ => AppTrafficMode.unavailable,
  };
}

/// Read while the Monitor tab is on screen, and only then.
final appTrafficProvider =
    NotifierProvider.autoDispose<AppTrafficNotifier, AppTrafficState>(AppTrafficNotifier.new);

class AppTrafficNotifier extends Notifier<AppTrafficState> {
  MacAppTrafficSource? _mac;
  AndroidAppTrafficSource? _android;
  var _busy = false;

  @override
  AppTrafficState build() {
    final mode = _mode;
    switch (mode) {
      case AppTrafficMode.live:
        _mac = MacAppTrafficSource();
        // Two readings make a speed; every two seconds keeps it current.
        final timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
        ref.onDispose(timer.cancel);
      case AppTrafficMode.today:
        _android = AndroidAppTrafficSource();
        final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
        // Back from the Usage access setting: the answer may have changed.
        final lifecycle = AppLifecycleListener(onResume: refresh);
        ref.onDispose(() {
          timer.cancel();
          lifecycle.dispose();
        });
      case AppTrafficMode.unavailable:
        return AppTrafficState(mode: mode, loaded: true);
    }
    Future.microtask(refresh);
    return AppTrafficState(mode: mode);
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      if (_mac != null) {
        final apps = await _mac!.sample();
        if (!ref.mounted) return;
        state = AppTrafficState(mode: state.mode, apps: _sorted(apps), loaded: true);
      } else if (_android != null) {
        final access = await _android!.hasAccess();
        final apps = access ? await _android!.today() : null;
        if (!ref.mounted) return;
        state = AppTrafficState(
          mode: state.mode,
          apps: _sorted(apps ?? const []),
          loaded: true,
          needsAccess: !access,
        );
      }
    } catch (_) {
      if (ref.mounted && !state.loaded) {
        state = AppTrafficState(mode: state.mode, loaded: true);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> openAccessSettings() async => _android?.openAccessSettings();

  /// By total: speeds change every reading, and a list sorted by them
  /// would never hold still long enough to read.
  static List<AppTraffic> _sorted(List<AppTraffic> apps) =>
      [...apps]..sort((a, b) => b.total.compareTo(a.total));
}
