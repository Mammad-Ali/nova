import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/home_shell.dart';
import 'core/app_activity.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/locale_provider.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/alerts/alerts_watcher.dart';
import 'features/traffic_monitor/presentation/providers/stability_provider.dart';
import 'features/traffic_monitor/presentation/providers/traffic_provider.dart';
import 'features/traffic_monitor/presentation/providers/usage_stats_provider.dart';
import 'shell/compact_mode.dart';
import 'shell/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Menu-bar/tray icon and system notifications are desktop-only; on other
  // platforms these calls quietly do nothing.
  await TrayService.instance.init();
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: NovaApp()));
}

class NovaApp extends ConsumerStatefulWidget {
  const NovaApp({super.key});

  @override
  ConsumerState<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends ConsumerState<NovaApp> {
  @override
  void initState() {
    super.initState();
    // Warm up the background providers — traffic capture, usage stats,
    // stability and the alert watcher — so they run regardless of the tab.
    ref.read(trafficHistoryProvider);
    ref.read(usageStatsProvider);
    ref.read(stabilityProvider);
    ref.read(alertsWatcherProvider);

    // The tray icon shows current speed and hourly traffic; the two providers
    // update independently, so refresh on either one.
    void pushTrayStatus() {
      final traffic = ref.read(trafficHistoryProvider);
      final usage = ref.read(usageStatsProvider);
      TrayService.instance.updateStatus(
        rxPerSec: traffic.currentRxPerSec,
        txPerSec: traffic.currentTxPerSec,
        hourBytes: usage.hourBytes,
      );
    }

    ref.listenManual(trafficHistoryProvider, (prev, next) => pushTrayStatus());
    ref.listenManual(usageStatsProvider, (prev, next) => pushTrayStatus());

    // A left click on the tray icon toggles the compact panel.
    TrayService.instance.onIconTap =
        () => ref.read(compactModeProvider.notifier).toggle();

    // Track window state: animations pause while the window is hidden.
    ref.watch(uiActiveProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Nova',
      debugShowCheckedModeBanner: false,
      theme: buildNovaTheme(),
      locale: locale.locale,
      supportedLocales: AppLocale.values.map((e) => e.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
