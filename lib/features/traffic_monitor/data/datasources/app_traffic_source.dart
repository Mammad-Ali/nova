import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/app_traffic.dart';

/// Traffic per app on macOS, from nettop: every process with network
/// activity and what it has received and sent since it started. Apps that
/// run as several processes — Chrome's helpers, Electron apps — are added
/// up under the app they belong to, found from each process's path.
///
/// Needs Nova outside the App Sandbox: inside it nettop sees Nova alone.
class MacAppTrafficSource {
  /// Process ID → the app it belongs to; null for macOS's own services.
  final _apps = <int, String?>{};

  /// Process ID → the app bundle it runs from, for the app's icon.
  final _bundles = <int, String?>{};
  Map<int, (int, int)> _last = {};
  DateTime? _lastAt;

  Future<MacAppSample> sample() async {
    final result = await Process.run(
      '/usr/bin/nettop',
      ['-P', '-L', '1', '-x', '-J', 'bytes_in,bytes_out'],
    );
    final processes = parseNettop('${result.stdout}');
    final now = DateTime.now();

    final unknown = [
      for (final pid in processes.keys)
        if (!_apps.containsKey(pid)) pid,
    ];
    if (unknown.isNotEmpty) {
      final ps = await Process.run('/bin/ps', ['-o', 'pid=,comm=', '-p', unknown.join(',')]);
      for (final line in '${ps.stdout}'.split('\n')) {
        final m = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
        if (m == null) continue;
        final pid = int.parse(m[1]!);
        final path = m[2]!.trim();
        _apps[pid] = appFromPath(path);
        _bundles[pid] = bundleFromPath(path);
      }
      // Gone before ps looked: nettop's (shortened) name will do.
      for (final pid in unknown) {
        _apps.putIfAbsent(pid, () => processes[pid]!.name);
      }
    }

    final seconds = _lastAt == null ? 0.0 : now.difference(_lastAt!).inMilliseconds / 1000;
    final byApp = <String?, _Sum>{};
    for (final MapEntry(key: pid, value: p) in processes.entries) {
      final sum = byApp.putIfAbsent(_apps[pid], _Sum.new)
        ..bytesIn += p.bytesIn
        ..bytesOut += p.bytesOut;
      sum.bundle ??= _bundles[pid];
      final before = _last[pid];
      // A process seen for the first time brings its whole past with it,
      // which may well be from yesterday: only what moves from here on is
      // counted. A smaller count means the ID now belongs to a new process.
      if (before != null) {
        if (p.bytesIn >= before.$1) sum.newIn += p.bytesIn - before.$1;
        if (p.bytesOut >= before.$2) sum.newOut += p.bytesOut - before.$2;
      }
    }
    _last = {for (final e in processes.entries) e.key: (e.value.bytesIn, e.value.bytesOut)};
    _lastAt = now;
    _apps.removeWhere((pid, _) => !processes.containsKey(pid));
    _bundles.removeWhere((pid, _) => !processes.containsKey(pid));

    final apps = <AppTraffic>[];
    final moved = <String, (int, int)>{};
    for (final MapEntry(key: app, value: sum) in byApp.entries) {
      final traffic = AppTraffic(
        name: app ?? '',
        kind: app == null ? AppTrafficKind.system : AppTrafficKind.app,
        bytesIn: sum.bytesIn,
        bytesOut: sum.bytesOut,
        rateIn: seconds > 0 ? sum.newIn / seconds : 0,
        rateOut: seconds > 0 ? sum.newOut / seconds : 0,
        iconSource: sum.bundle,
      );
      if (traffic.total > 0) apps.add(traffic);
      if (sum.newIn + sum.newOut > 0) moved[traffic.key] = (sum.newIn, sum.newOut);
    }
    return MacAppSample(apps: apps, moved: moved);
  }

  /// nettop's `-P -x -J bytes_in,bytes_out` output — "Google Chrome
  /// H.35148,82661,73378," per process — by process ID.
  static Map<int, ({String name, int bytesIn, int bytesOut})> parseNettop(String text) {
    final line = RegExp(r'^(.*)\.(\d+),(\d+),(\d+),?\s*$', multiLine: true);
    return {
      for (final m in line.allMatches(text))
        int.parse(m[2]!): (
          name: m[1]!,
          bytesIn: int.parse(m[3]!),
          bytesOut: int.parse(m[4]!),
        ),
    };
  }

  /// The app a process belongs to, from its executable's path: the
  /// outermost ".app" in it — "/Applications/Google Chrome.app/…/Google
  /// Chrome Helper" is "Google Chrome" — or else the file's name. Null for
  /// macOS's own services.
  static String? appFromPath(String path) {
    const system = ['/System/', '/usr/', '/bin/', '/sbin/', '/Library/Apple/'];
    if (system.any(path.startsWith)) return null;
    final parts = path.split('/');
    for (final part in parts) {
      if (part.endsWith('.app') && part.length > 4) return part.substring(0, part.length - 4);
    }
    return parts.last.isEmpty ? path : parts.last;
  }

  /// The outermost app bundle in [path] — "/Applications/Google
  /// Chrome.app" — whose icon stands for the app; null for macOS's own
  /// services and for programs outside any bundle.
  static String? bundleFromPath(String path) {
    if (appFromPath(path) == null) return null;
    final at = path.indexOf('.app/');
    if (at > 0) return path.substring(0, at + 4);
    return path.endsWith('.app') ? path : null;
  }
}

/// One reading: every app's totals since it started and its speed, and
/// what each moved since the reading before ("app:Telegram" → in, out).
class MacAppSample {
  const MacAppSample({required this.apps, required this.moved});
  final List<AppTraffic> apps;
  final Map<String, (int, int)> moved;
}

class _Sum {
  int bytesIn = 0;
  int bytesOut = 0;
  int newIn = 0;
  int newOut = 0;
  String? bundle;
}

/// Traffic per app on Android, today, from the system's network
/// statistics (AppTraffic.kt). Android shows them only to apps the user
/// has allowed under Usage access.
class AndroidAppTrafficSource {
  static const _channel = MethodChannel('net_pulse/apps');

  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openAccess');
    } catch (_) {}
  }

  /// Each app's traffic from [from] to [to]; null when the statistics
  /// can't be read (no access).
  Future<List<AppTraffic>?> range(DateTime from, DateTime to) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('range', {
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
    });
    if (raw == null) return null;
    final merged = <String, AppTraffic>{};
    for (final entry in raw) {
      final kind = switch (entry['kind']) {
        'system' => AppTrafficKind.system,
        'removed' => AppTrafficKind.removed,
        'hotspot' => AppTrafficKind.hotspot,
        _ => AppTrafficKind.app,
      };
      final name = '${entry['name'] ?? ''}';
      final key = appKey(kind, name);
      final before = merged[key];
      merged[key] = AppTraffic(
        name: name,
        kind: kind,
        bytesIn: (before?.bytesIn ?? 0) + ((entry['rx'] as num?)?.toInt() ?? 0),
        bytesOut: (before?.bytesOut ?? 0) + ((entry['tx'] as num?)?.toInt() ?? 0),
        iconSource: before?.iconSource ?? _nonEmpty(entry['package'] as String?),
      );
    }
    return merged.values.toList();
  }
}

String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
