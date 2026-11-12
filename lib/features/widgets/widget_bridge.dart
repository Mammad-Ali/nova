import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/utils/byte_format.dart';
import '../services_ping/presentation/service_ping_provider.dart';
import '../speedtest/data/datasources/ip_info.dart';
import '../speedtest/domain/entities/speed_grade.dart';
import '../speedtest/presentation/providers/speedtest_history_provider.dart';
import '../speedtest/presentation/providers/speedtest_provider.dart';
import '../speedtest/presentation/widgets/result_summary.dart';
import '../lan_scan/domain/known_device.dart';
import '../lan_scan/domain/lan_device.dart';
import '../lan_scan/presentation/lan_scan_sheet.dart';
import '../lan_scan/presentation/network_watch_provider.dart';
import '../traffic_monitor/domain/entities/app_traffic.dart';
import '../traffic_monitor/presentation/providers/app_usage_tracker.dart';
import '../traffic_monitor/presentation/providers/usage_stats_provider.dart';

/// Keeps the widgets up to date — the Mac's (macos/NovaWidgets) and the
/// Android home screen's (NovaWidgets.kt). They can't ask the
/// app anything, so the app hands them a snapshot: written when a test
/// starts and finishes, when the latency to services is measured, when the
/// language changes, and every half hour for the traffic totals. Each write redraws
/// the widgets, and macOS limits how often that may happen, so nothing is
/// sent twice.
final widgetBridgeProvider = Provider<void>((ref) {
  // The Mac widgets (NovaWidgets.swift) and Android's (NovaWidgets.kt) read
  // the same snapshot.
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.android)) {
    return;
  }

  const channel = MethodChannel('net_pulse/widgets');
  Timer? pending;
  String? sent;

  Future<void> send() async {
    final json = jsonEncode(widgetSnapshot(ref));
    if (json == sent) return;
    try {
      await channel.invokeMethod<bool>('update', json);
      sent = json;
    } catch (_) {
      // The widgets are extras; a failed write is retried with the next one.
    }
  }

  // Several sources often change together (a test, then the latencies
  // measured after it): one write covers them all.
  void schedule() {
    pending?.cancel();
    pending = Timer(const Duration(seconds: 2), send);
  }

  ref.listen(speedTestHistoryProvider, (_, _) => schedule());
  // "Testing…" on the widgets while a test runs — often one they started.
  ref.listen(speedTestControllerProvider.select((s) => s.isRunning), (_, _) => schedule());
  ref.listen(servicePingProvider, (_, next) {
    if (!next.running) schedule();
  });
  ref.listen(localeProvider, (_, _) => schedule());
  ref.listen(ipInfoProvider, (_, _) => schedule());
  // A scan's summary changes at most every half hour. Today's apps change
  // every few seconds, far more often than macOS lets widgets redraw, so
  // they ride along with every other write and the half-hourly one.
  ref.listen(networkWatchProvider, (_, _) => schedule());
  final periodic = Timer.periodic(const Duration(minutes: 30), (_) => schedule());
  ref.onDispose(() {
    pending?.cancel();
    periodic.cancel();
  });
  schedule();
});

/// What the widgets show, in the shape NovaWidgets.swift decodes. Times go
/// as milliseconds, traffic as the text the app itself shows, and every
/// label in the app's language.
@visibleForTesting
Map<String, Object?> widgetSnapshot(Ref ref) {
  final t = ref.read(stringsProvider);
  final history = ref.read(speedTestHistoryProvider);
  final usage = ref.read(usageStatsProvider);
  final pings = ref.read(servicePingProvider).results;
  final isp = ref.read(ipInfoProvider).asData?.value.isp;
  final last = history.isEmpty ? null : history.last;
  String bytes(int value) => formatBytes(value).toString();

  return {
    'test': last == null
        ? null
        : () {
            final grade = gradeForDownload(last.downloadMbps);
            return {
              't': last.timestamp.millisecondsSinceEpoch,
              'down': last.downloadMbps,
              'up': last.uploadMbps,
              'ping': last.pingMs,
              'jitter': last.jitterMs,
              'grade': grade.letter,
              'tier': speedTierLabel(t, grade.tier),
              'tierKey': grade.tier.name,
            };
          }(),
    'recent': [
      for (final record in history.skip(math.max(0, history.length - 12)))
        record.downloadMbps,
    ],
    'best': history.isEmpty
        ? null
        : history.map((r) => r.downloadMbps).reduce(math.max),
    // Empty until the traffic counters have loaded their first day.
    'usage': usage.dayKey.isEmpty
        ? null
        : {
            'hour': bytes(usage.hourBytes),
            'today': bytes(usage.dayBytes),
            'month': bytes(usage.monthBytes),
            'forecast': usage.monthForecastBytes == null
                ? null
                : bytes(usage.monthForecastBytes!),
          },
    'services': [
      for (final ping in pings) {'name': ping.target.name, 'ms': ping.rttMs},
    ],
    'provider': isp,
    'running': ref.read(speedTestControllerProvider).isRunning,
    'apps': _apps(ref),
    'network': _network(ref, t),
    'labels': widgetLabels(t),
  };
}

/// Today's busiest apps for the apps widgets. Each app's icon goes along
/// as the app bundle it comes from and a file name: the widgets may only
/// read Nova's own folder, so the app saves the icon there under that name
/// (WidgetStore in MainFlutterWindow.swift).
Map<String, Object?>? _apps(Ref ref) {
  final usage = ref.read(macAppUsageProvider);
  if (!usage.loaded) return null;
  final apps = usage.over(1);
  final total = apps.fold<int>(0, (sum, a) => sum + a.total);
  final top = apps.isEmpty ? 1 : apps.first.total;
  return {
    'total': formatBytes(total).toString(),
    'count': apps.length,
    'list': [
      for (final app in apps.take(5))
        {
          'name': app.kind == AppTrafficKind.app ? app.name : ref.read(stringsProvider).appsSystemMac,
          'kind': app.kind.name,
          'bytes': formatBytes(app.total).toString(),
          'share': top == 0 ? 0 : app.total / top,
          if (app.iconSource != null) ...{
            'bundle': app.iconSource,
            'icon': widgetIconFile(app.key),
          },
        },
    ],
  };
}

/// The file an app's icon is saved under: its key, made safe for a file
/// name, plus a hash of the key — macOS file names ignore case, and
/// "claude" (Claude Code) and "Claude" (the app) are different apps.
String widgetIconFile(String key) {
  var hash = 0x811c9dc5; // FNV-1a
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  final safe = key.replaceAll(RegExp('[^A-Za-z0-9]+'), '_').toLowerCase();
  return '${safe}_${hash.toRadixString(16).padLeft(8, '0')}.png';
}

/// The last scan of the network, for the Network widget.
Map<String, Object?>? _network(Ref ref, AppStrings t) {
  final summary = ref.read(networkWatchProvider);
  if (summary == null) return null;
  final newest = summary.newest;
  return {
    'online': summary.online,
    't': summary.at.millisecondsSinceEpoch,
    if (newest != null) 'newest': knownDeviceTitle(newest, t),
  };
}

/// What to call a device that isn't in front of us: the user's name for it,
/// else what it called itself, else its maker and kind.
String knownDeviceTitle(KnownDevice device, AppStrings t) {
  if (device.name != null) return device.name!;
  if (device.seenName != null) return device.seenName!;
  final kind = deviceKindLabel(device.kind ?? device.seenKind ?? DeviceKind.unknown, t);
  return device.vendor == null ? kind : '${device.vendor} · $kind';
}

/// The widgets' words, keyed the way NovaWidgets.swift asks for them.
Map<String, String> widgetLabels(AppStrings t) => {
      'download': t.download,
      'upload': t.upload,
      'ping': t.ping,
      'jitter': t.jitter,
      'runTest': t.startTest,
      'testing': t.widgetTesting,
      'callCheck': t.widgetCallShort,
      'findCause': t.diagTitle,
      'services': t.servicesTitle,
      'pastHour': t.usagePastHour,
      'today': t.usageToday,
      'month': t.usageMonth,
      'forecast': t.usageForecast,
      'noTest': t.widgetNoTest,
      'traffic': t.widgetTraffic,
      'trafficEmpty': t.widgetTrafficEmpty,
      'speedName': t.widgetSpeedName,
      'speedDesc': t.widgetSpeedDesc,
      'toolsName': t.widgetToolsName,
      'toolsDesc': t.widgetToolsDesc,
      'dashName': t.widgetDashName,
      'dashDesc': t.widgetDashDesc,
      'trafficName': t.widgetTraffic,
      'trafficDesc': t.widgetTrafficDesc,
      'appsToday': t.widgetAppsToday,
      'appsMore': t.widgetAppsMore,
      'appsEmpty': t.widgetAppsEmpty,
      'appsTotal': t.widgetAppsTotal,
      'appsName': t.widgetAppsToday,
      'appsDesc': t.widgetAppsDesc,
      'network': t.widgetNetwork,
      'online': t.widgetOnline,
      'newDevice': t.widgetNewDevice,
      'networkEmpty': t.widgetNetworkEmpty,
      'networkName': t.widgetNetwork,
      'networkDesc': t.widgetNetworkDesc,
    };
