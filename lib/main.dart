import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/home_shell.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/locale_provider.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/alerts/alerts_watcher.dart';
import 'features/traffic_monitor/presentation/providers/stability_provider.dart';
import 'features/traffic_monitor/presentation/providers/traffic_provider.dart';
import 'features/traffic_monitor/presentation/providers/usage_stats_provider.dart';
import 'shell/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Иконка в меню-баре/трее и системные уведомления — только на десктопе;
  // на других платформах вызовы тихо ничего не делают.
  await TrayService.instance.init();
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: PulsarApp()));
}

class PulsarApp extends ConsumerStatefulWidget {
  const PulsarApp({super.key});

  @override
  ConsumerState<PulsarApp> createState() => _PulsarAppState();
}

class _PulsarAppState extends ConsumerState<PulsarApp> {
  @override
  void initState() {
    super.initState();
    // Прогреваем фоновые провайдеры: сбор трафика, статистика, стабильность
    // и наблюдатель уведомлений — чтобы они работали независимо от вкладки.
    ref.read(trafficHistoryProvider);
    ref.read(usageStatsProvider);
    ref.read(stabilityProvider);
    ref.read(alertsWatcherProvider);

    // Иконка в трее показывает текущую скорость и трафик за час — оба
    // провайдера меняются независимо, поэтому обновляем при любом из них.
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
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Pulsar',
      debugShowCheckedModeBanner: false,
      theme: buildNetPulseTheme(),
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
