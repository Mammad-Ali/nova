import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/settings/app_settings.dart';
import '../speedtest/domain/entities/speedtest_models.dart';
import '../speedtest/presentation/providers/speedtest_provider.dart';
import '../traffic_monitor/presentation/providers/usage_stats_provider.dart';

/// Watches test results and daily traffic, sending system notifications when
/// the user's thresholds are crossed.
///
/// Kept alive from [main]; otherwise nothing would be listening.
final alertsWatcherProvider = Provider<AlertsWatcher>((ref) {
  final w = AlertsWatcher(ref);
  w.start();
  return w;
});

class AlertsWatcher {
  AlertsWatcher(this.ref);
  final Ref ref;

  /// Prevents sending the same notification twice.
  String? _limitNotifiedForDay;
  TestPhase? _prevPhase;

  void start() {
    ref.listen<SpeedTestState>(speedTestControllerProvider, (prev, next) {
      final justDone =
          next.phase == TestPhase.done && _prevPhase != TestPhase.done;
      _prevPhase = next.phase;
      if (justDone) _checkSpeed(next);
    });

    ref.listen(usageStatsProvider, (prev, next) => _checkDailyLimit(next));
  }

  void _checkSpeed(SpeedTestState s) {
    final settings = ref.read(appSettingsProvider);
    final threshold = settings.minSpeedMbps;
    final down = s.downloadMbps;
    if (!settings.alertsEnabled || threshold == null || down == null) return;
    if (down >= threshold) return;

    final t = ref.read(stringsProvider);
    NotificationService.instance.show(
      t.alertSlowTitle,
      AppStrings.fill(t.alertSlowBody,
          [down.toStringAsFixed(1), threshold.toStringAsFixed(0)]),
    );
  }

  void _checkDailyLimit(dynamic usage) {
    final settings = ref.read(appSettingsProvider);
    final limitGb = settings.dailyLimitGb;
    if (!settings.alertsEnabled || limitGb == null) return;

    final dayKey = usage.dayKey as String;
    final dayBytes = usage.dayBytes as int;
    if (dayKey.isEmpty || _limitNotifiedForDay == dayKey) return;

    final limitBytes = limitGb * 1024 * 1024 * 1024;
    if (dayBytes < limitBytes) return;

    _limitNotifiedForDay = dayKey; // once per day
    final t = ref.read(stringsProvider);
    final usedGb = dayBytes / (1024 * 1024 * 1024);
    NotificationService.instance.show(
      t.alertLimitTitle,
      AppStrings.fill(t.alertLimitBody,
          [usedGb.toStringAsFixed(1), limitGb.toStringAsFixed(1)]),
    );
  }
}
