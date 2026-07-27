import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/theme/app_theme.dart';
import 'wifi_info.dart';

/// Компактный чип с данными Wi-Fi: уровень сигнала и скорость линка.
/// Отвечает на вопрос «медленно из-за провайдера или я далеко от роутера».
///
/// Ничего не рисует, если соединение проводное, Wi-Fi выключен или платформа
/// не поддерживается.
class WifiChip extends ConsumerWidget {
  const WifiChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final info = ref.watch(wifiInfoProvider).asData?.value;
    if (info == null) return const SizedBox.shrink();

    final q = info.quality;
    final color = q == null
        ? AppColors.textMid
        : (q > 0.66
            ? AppColors.green
            : (q > 0.33 ? AppColors.amber : AppColors.red));

    final parts = <String>[
      if (info.ssid != null) info.ssid!,
      if (info.rssi != null) '${info.rssi} dBm',
      if (info.txRateMbps != null) '${info.txRateMbps} Mbps',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_signalIcon(q), size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              '${t.wifiTitle}: ',
              style: const TextStyle(color: AppColors.textLo, fontSize: 12),
            ),
            Flexible(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _signalIcon(double? q) {
    if (q == null) return Icons.wifi_rounded;
    if (q > 0.66) return Icons.network_wifi_rounded;
    if (q > 0.33) return Icons.network_wifi_2_bar_rounded;
    return Icons.network_wifi_1_bar_rounded;
  }
}
