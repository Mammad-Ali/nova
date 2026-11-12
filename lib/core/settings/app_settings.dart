import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the menu-bar item shows next to its icon (macOS; the Windows tray
/// has no room for text).
enum MenuBarContent { speedAndHour, speed, downUp, today, iconOnly }

/// How often the automatic test runs.
const autoTestIntervals = [1, 3, 6];

/// User settings: alerts and limits, the menu bar, automatic tests.
class AppSettings {
  const AppSettings({
    this.alertsEnabled = false,
    this.minSpeedMbps,
    this.dailyLimitGb,
    this.menuBarEnabled = true,
    this.menuBarContent = MenuBarContent.speedAndHour,
    this.menuBarBits = false,
    this.autoTestEnabled = false,
    this.autoTestHours = 1,
    this.planMbps,
  });

  /// Whether to show system notifications.
  final bool alertsEnabled;

  /// Threshold: warn when a test comes in below it. null disables the alert.
  final double? minSpeedMbps;

  /// Daily traffic limit in GB. null disables the alert.
  final double? dailyLimitGb;

  /// Whether Nova has a menu-bar (macOS) or tray (Windows) icon. Without one,
  /// closing the window quits Nova: nothing would be left to reopen it from.
  final bool menuBarEnabled;

  /// What the menu-bar item shows beside its icon.
  final MenuBarContent menuBarContent;

  /// Speeds in the menu bar in megabits per second rather than bytes.
  final bool menuBarBits;

  /// Whether a speed test runs on its own every [autoTestHours] hours.
  final bool autoTestEnabled;
  final int autoTestHours;

  /// The download speed the internet plan promises, for the report to the
  /// provider. null until the user says.
  final double? planMbps;

  AppSettings copyWith({
    bool? alertsEnabled,
    double? minSpeedMbps,
    double? dailyLimitGb,
    bool clearMinSpeed = false,
    bool clearDailyLimit = false,
    bool? menuBarEnabled,
    MenuBarContent? menuBarContent,
    bool? menuBarBits,
    bool? autoTestEnabled,
    int? autoTestHours,
    double? planMbps,
    bool clearPlan = false,
  }) {
    return AppSettings(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      minSpeedMbps: clearMinSpeed ? null : (minSpeedMbps ?? this.minSpeedMbps),
      dailyLimitGb:
          clearDailyLimit ? null : (dailyLimitGb ?? this.dailyLimitGb),
      menuBarEnabled: menuBarEnabled ?? this.menuBarEnabled,
      menuBarContent: menuBarContent ?? this.menuBarContent,
      menuBarBits: menuBarBits ?? this.menuBarBits,
      autoTestEnabled: autoTestEnabled ?? this.autoTestEnabled,
      autoTestHours: autoTestHours ?? this.autoTestHours,
      planMbps: clearPlan ? null : (planMbps ?? this.planMbps),
    );
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kAlerts = 'alerts_enabled';
  static const _kMinSpeed = 'alert_min_speed';
  static const _kDailyLimit = 'alert_daily_limit_gb';
  static const _kMenuBar = 'menu_bar_enabled';
  static const _kMenuBarContent = 'menu_bar_content';
  static const _kMenuBarBits = 'menu_bar_bits';
  static const _kAutoTest = 'auto_test_enabled';
  static const _kAutoTestHours = 'auto_test_hours';
  static const _kPlan = 'plan_mbps';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final content = p.getString(_kMenuBarContent);
      final hours = p.getInt(_kAutoTestHours);
      state = AppSettings(
        alertsEnabled: p.getBool(_kAlerts) ?? false,
        minSpeedMbps: p.getDouble(_kMinSpeed),
        dailyLimitGb: p.getDouble(_kDailyLimit),
        menuBarEnabled: p.getBool(_kMenuBar) ?? true,
        menuBarContent: MenuBarContent.values.asNameMap()[content] ??
            MenuBarContent.speedAndHour,
        menuBarBits: p.getBool(_kMenuBarBits) ?? false,
        autoTestEnabled: p.getBool(_kAutoTest) ?? false,
        autoTestHours: autoTestIntervals.contains(hours) ? hours! : 1,
        planMbps: p.getDouble(_kPlan),
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
      await p.setBool(_kMenuBar, s.menuBarEnabled);
      await p.setString(_kMenuBarContent, s.menuBarContent.name);
      await p.setBool(_kMenuBarBits, s.menuBarBits);
      await p.setBool(_kAutoTest, s.autoTestEnabled);
      await p.setInt(_kAutoTestHours, s.autoTestHours);
      if (s.planMbps == null) {
        await p.remove(_kPlan);
      } else {
        await p.setDouble(_kPlan, s.planMbps!);
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

  void setMenuBarEnabled(bool v) => _set(state.copyWith(menuBarEnabled: v));

  void setMenuBarContent(MenuBarContent v) => _set(state.copyWith(menuBarContent: v));

  void setMenuBarBits(bool v) => _set(state.copyWith(menuBarBits: v));

  void setAutoTestEnabled(bool v) => _set(state.copyWith(autoTestEnabled: v));

  void setAutoTestHours(int v) => _set(state.copyWith(autoTestHours: v));

  void setPlan(double? mbps) =>
      _set(mbps == null || mbps <= 0 ? state.copyWith(clearPlan: true) : state.copyWith(planMbps: mbps));

  void _set(AppSettings s) {
    state = s;
    _persist(s);
  }
}
