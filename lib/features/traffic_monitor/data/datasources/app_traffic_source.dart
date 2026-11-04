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
  Map<int, (int, int)> _last = {};
  DateTime? _lastAt;

  Future<List<AppTraffic>> sample() async {
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
        if (m != null) _apps[int.parse(m[1]!)] = appFromPath(m[2]!.trim());
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
      final before = _last[pid];
      if (before != null && seconds > 0) {
        // A smaller count means the ID now belongs to a new process.
        if (p.bytesIn >= before.$1) sum.rateIn += (p.bytesIn - before.$1) / seconds;
        if (p.bytesOut >= before.$2) sum.rateOut += (p.bytesOut - before.$2) / seconds;
      }
    }
    _last = {for (final e in processes.entries) e.key: (e.value.bytesIn, e.value.bytesOut)};
    _lastAt = now;
    _apps.removeWhere((pid, _) => !processes.containsKey(pid));

    return [
      for (final MapEntry(key: app, value: sum) in byApp.entries)
        if (sum.bytesIn + sum.bytesOut > 0)
          AppTraffic(
            name: app ?? '',
            kind: app == null ? AppTrafficKind.system : AppTrafficKind.app,
            bytesIn: sum.bytesIn,
            bytesOut: sum.bytesOut,
            rateIn: sum.rateIn,
            rateOut: sum.rateOut,
          ),
    ];
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
}

class _Sum {
  int bytesIn = 0;
  int bytesOut = 0;
  double rateIn = 0;
  double rateOut = 0;
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

  /// Null when the statistics can't be read (no access).
  Future<List<AppTraffic>?> today() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('today');
    if (raw == null) return null;
    final merged = <(AppTrafficKind, String), AppTraffic>{};
    for (final entry in raw) {
      final kind = switch (entry['kind']) {
        'system' => AppTrafficKind.system,
        'removed' => AppTrafficKind.removed,
        'hotspot' => AppTrafficKind.hotspot,
        _ => AppTrafficKind.app,
      };
      final name = '${entry['name'] ?? ''}';
      final before = merged[(kind, name)];
      merged[(kind, name)] = AppTraffic(
        name: name,
        kind: kind,
        bytesIn: (before?.bytesIn ?? 0) + ((entry['rx'] as num?)?.toInt() ?? 0),
        bytesOut: (before?.bytesOut ?? 0) + ((entry['tx'] as num?)?.toInt() ?? 0),
      );
    }
    return merged.values.toList();
  }
}
