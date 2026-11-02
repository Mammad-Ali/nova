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
import '../speedtest/presentation/widgets/result_summary.dart';
import '../traffic_monitor/presentation/providers/usage_stats_provider.dart';

/// Keeps the Mac widgets (macos/NovaWidgets) up to date. They can't ask the
/// app anything, so the app hands them a snapshot: written when a test
/// finishes, when the latency to services is measured, when the language
/// changes, and every half hour for the traffic totals. Each write redraws
/// the widgets, and macOS limits how often that may happen, so nothing is
/// sent twice.
final widgetBridgeProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

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
  ref.listen(servicePingProvider, (_, next) {
    if (!next.running) schedule();
  });
  ref.listen(localeProvider, (_, _) => schedule());
  ref.listen(ipInfoProvider, (_, _) => schedule());
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
    'labels': widgetLabels(t),
  };
}

/// The widgets' words, keyed the way NovaWidgets.swift asks for them.
Map<String, String> widgetLabels(AppStrings t) => {
      'download': t.download,
      'upload': t.upload,
      'ping': t.ping,
      'jitter': t.jitter,
      'runTest': t.startTest,
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
    };
