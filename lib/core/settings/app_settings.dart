import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings for notifications and limits.
class AppSettings {
  const AppSettings({
    this.alertsEnabled = false,
    this.minSpeedMbps,
    this.dailyLimitGb,
  });

  /// Whether to show system notifications.
  final bool alertsEnabled;

  /// Threshold: warn when a test comes in below it. null disables the alert.
  final double? minSpeedMbps;

  /// Daily traffic limit in GB. null disables the alert.
  final double? dailyLimitGb;

  AppSettings copyWith({
    bool? alertsEnabled,
    double? minSpeedMbps,
    double? dailyLimitGb,
    bool clearMinSpeed = false,
    bool clearDailyLimit = false,
  }) {
    return AppSettings(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      minSpeedMbps: clearMinSpeed ? null : (minSpeedMbps ?? this.minSpeedMbps),
      dailyLimitGb:
          clearDailyLimit ? null : (dailyLimitGb ?? this.dailyLimitGb),
    );
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kAlerts = 'alerts_enabled';
  static const _kMinSpeed = 'alert_min_speed';
  static const _kDailyLimit = 'alert_daily_limit_gb';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = AppSettings(
        alertsEnabled: p.getBool(_kAlerts) ?? false,
        minSpeedMbps: p.getDouble(_kMinSpeed),
        dailyLimitGb: p.getDouble(_kDailyLimit),
      );
    } catch (_) {
      // Storage unavailable — keep the defaults.
    }
  }

  Future<void> _persist(AppSettings s) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAlerts, s.alertsEnabled);
      if (s.minSpeedMbps == null) {
        await p.remove(_kMinSpeed);
      } else {
        await p.setDouble(_kMinSpeed, s.minSpeedMbps!);
      }
      if (s.dailyLimitGb == null) {
        await p.remove(_kDailyLimit);
      } else {
        await p.setDouble(_kDailyLimit, s.dailyLimitGb!);
      }
    } catch (_) {}
  }

  void setAlertsEnabled(bool v) {
    state = state.copyWith(alertsEnabled: v);
    _persist(state);
  }

  void setMinSpeed(double? v) {
    state = v == null
        ? state.copyWith(clearMinSpeed: true)
        : state.copyWith(minSpeedMbps: v);
    _persist(state);
  }



  void setDailyLimit(double? v) {
    state = v == null
        ? state.copyWith(clearDailyLimit: true)
        : state.copyWith(dailyLimitGb: v);
    _persist(state);
  }
}
