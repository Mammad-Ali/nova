import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/byte_format.dart';
import '../../data/datasources/app_traffic_source.dart';
import '../../data/repositories/app_usage_repository.dart';
import '../../domain/entities/app_traffic.dart';

/// What the Mac tracker knows.
class MacAppUsage {
  const MacAppUsage({
    this.live = const [],
    this.byDay = const {},
    this.icons = const {},
    this.loaded = false,
  });

  /// Every app with network activity now: totals since it started, speed.
  final List<AppTraffic> live;

  /// What each app moved per day while Nova was running.
  final Map<String, Map<String, (int, int)>> byDay;

  /// App key → its bundle, for the icon, including apps that have quit.
  final Map<String, String> icons;

  final bool loaded;

  /// The apps' totals over [days] days up to and including today, busiest
  /// first.
  List<AppTraffic> over(int days, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final sums = <String, (int, int)>{};
    for (var i = 0; i < days; i++) {
      final day = byDay[dayKey(today.subtract(Duration(days: i)))];
      if (day == null) continue;
      day.forEach((key, v) {
        final before = sums[key] ?? (0, 0);
        sums[key] = (before.$1 + v.$1, before.$2 + v.$2);
      });
    }
    return [
      for (final MapEntry(key: key, value: v) in sums.entries)
        if (v.$1 + v.$2 > 0) appFromKey(key, bytesIn: v.$1, bytesOut: v.$2, iconSource: icons[key]),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }

  /// One app's total for each of the last [days] days, oldest first.
  List<int> daily(String key, int days, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        switch (byDay[dayKey(today.subtract(Duration(days: i)))]?[key]) {
          final v? => v.$1 + v.$2,
          null => 0,
        },
    ];
  }
}

/// Watches which apps use the network on the Mac, all the time Nova runs —
/// the menu bar keeps it running — so "today" and "this week" are known
/// for every app, and warns when one passes the daily limit set for it.
///
/// Started from main.dart; does nothing on other platforms.
final macAppUsageProvider = NotifierProvider<MacAppUsageNotifier, MacAppUsage>(MacAppUsageNotifier.new);

class MacAppUsageNotifier extends Notifier<MacAppUsage> {
  static const _interval = Duration(seconds: 3);
  static const _saveEvery = Duration(minutes: 1);

  final _source = MacAppTrafficSource();
  final _repo = AppUsageRepository();
  var _busy = false;
  var _dirty = false;
  DateTime _savedAt = DateTime.now();

  /// Limits already announced: "2026-11-12|app:Telegram".
  final _warned = <String>{};

  @override
  MacAppUsage build() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return const MacAppUsage(loaded: true);
    final timer = Timer.periodic(_interval, (_) => _tick());
    ref.onDispose(() {
      timer.cancel();
      if (_dirty) unawaited(_save());
    });
    Future.microtask(_load);
    return const MacAppUsage();
  }

  Future<void> _load() async {
    final byDay = await _repo.load();
    final icons = await _repo.loadIcons();
    _warned.addAll(await _loadWarned());
    if (!ref.mounted) return;
    state = MacAppUsage(live: state.live, byDay: byDay, icons: icons, loaded: true);
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_busy || !state.loaded) return;
    _busy = true;
    try {
      final sample = await _source.sample();
      if (!ref.mounted) return;
      final today = dayKey(DateTime.now());
      final byDay = {...state.byDay};
      final day = {...?byDay[today]};
      sample.moved.forEach((key, v) {
        final before = day[key] ?? (0, 0);
        day[key] = (before.$1 + v.$1, before.$2 + v.$2);
      });
      byDay[today] = day;

      var icons = state.icons;
      for (final app in sample.apps) {
        if (app.iconSource != null && icons[app.key] != app.iconSource) {
          icons = {...icons, app.key: app.iconSource!};
          unawaited(_repo.saveIcons(icons));
        }
      }

      state = MacAppUsage(live: sample.apps, byDay: byDay, icons: icons, loaded: true);
      if (sample.moved.isNotEmpty) {
        _dirty = true;
        _checkLimits(today, day);
      }
      if (_dirty && DateTime.now().difference(_savedAt) >= _saveEvery) await _save();
    } catch (_) {
      // nettop missing or refused: the card shows what it has.
    } finally {
      _busy = false;
    }
  }

  Future<void> _save() async {
    _dirty = false;
    _savedAt = DateTime.now();
    await _repo.save(state.byDay);
  }

  void _checkLimits(String today, Map<String, (int, int)> day) {
    final limits = ref.read(appLimitsProvider);
    if (limits.isEmpty) return;
    final t = ref.read(stringsProvider);
    for (final MapEntry(key: key, value: limit) in limits.entries) {
      final used = day[key];
      if (used == null || used.$1 + used.$2 < limit) continue;
      if (!_warned.add('$today|$key')) continue;
      final app = appFromKey(key);
      final name = app.kind == AppTrafficKind.app ? app.name : t.appsSystemMac;
      unawaited(NotificationService.instance.show(
        AppStrings.fill(t.appsLimitTitle, [name]),
        AppStrings.fill(t.appsLimitBody, [
          formatBytes(used.$1 + used.$2).toString(),
          formatBytes(limit).toString(),
        ]),
      ));
      unawaited(_saveWarned(today));
    }
  }

  static const _warnedKey = 'app_limit_warned_v1';

  Future<Set<String>> _loadWarned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_warnedKey) ?? const [];
      final today = dayKey(DateTime.now());
      return {for (final s in list) if (s.startsWith('$today|')) s};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveWarned(String today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_warnedKey, [for (final s in _warned) if (s.startsWith('$today|')) s]);
    } catch (_) {}
  }
}

/// Daily limits per app, in bytes: app key → limit. Set from an app's
/// detail sheet; on the Mac passing one sends a notification, on Android
/// the app is marked in the list.
final appLimitsProvider = NotifierProvider<AppLimitsNotifier, Map<String, int>>(AppLimitsNotifier.new);

class AppLimitsNotifier extends Notifier<Map<String, int>> {
  static const _key = 'app_limits_v1';

  @override
  Map<String, int> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || !ref.mounted) return;
      state = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {}
  }

  Future<void> set(String key, int? bytes) async {
    final next = {...state};
    if (bytes == null) {
      next.remove(key);
    } else {
      next[key] = bytes;
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(next));
    } catch (_) {}
  }
}
