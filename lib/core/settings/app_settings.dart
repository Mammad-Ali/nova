import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Пользовательские настройки уведомлений и лимитов.
class AppSettings {
  const AppSettings({
    this.alertsEnabled = false,
    this.minSpeedMbps,
    this.dailyLimitGb,
    this.themeMode = ThemeMode.system,
  });

  /// Показывать ли системные уведомления.
  final bool alertsEnabled;

  /// Порог: если тест показал меньше — предупредить. null = выключено.
  final double? minSpeedMbps;

  /// Дневной лимит трафика в ГБ. null = выключено.
  final double? dailyLimitGb;

  /// Тема оформления: по системе, всегда тёмная или всегда светлая.
  final ThemeMode themeMode;

  AppSettings copyWith({
    bool? alertsEnabled,
    double? minSpeedMbps,
    double? dailyLimitGb,
    ThemeMode? themeMode,
    bool clearMinSpeed = false,
    bool clearDailyLimit = false,
  }) {
    return AppSettings(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      minSpeedMbps: clearMinSpeed ? null : (minSpeedMbps ?? this.minSpeedMbps),
      dailyLimitGb:
          clearDailyLimit ? null : (dailyLimitGb ?? this.dailyLimitGb),
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kAlerts = 'alerts_enabled';
  static const _kMinSpeed = 'alert_min_speed';
  static const _kDailyLimit = 'alert_daily_limit_gb';
  static const _kThemeMode = 'theme_mode';

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
        themeMode: _modeFromName(p.getString(_kThemeMode)),
      );
    } catch (_) {
      // Хранилище недоступно — остаёмся на значениях по умолчанию.
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
      await p.setString(_kThemeMode, s.themeMode.name);
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

  void setThemeMode(ThemeMode v) {
    state = state.copyWith(themeMode: v);
    _persist(state);
  }

  static ThemeMode _modeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void setDailyLimit(double? v) {
    state = v == null
        ? state.copyWith(clearDailyLimit: true)
        : state.copyWith(dailyLimitGb: v);
    _persist(state);
  }
}
