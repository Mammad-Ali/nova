import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/service_target.dart';
import 'service_ping_provider.dart';

/// Открывает шторку «Пинг до сервисов».
void showServicePingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ServicePingSheet(),
  );
}

class _ServicePingSheet extends ConsumerWidget {
  const _ServicePingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(servicePingProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onGlass.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.servicesTitle,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (s.running)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentAlt,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: ref.read(servicePingProvider.notifier).run,
                        icon: Icon(Icons.refresh_rounded,
                            color: AppColors.textMid),
                        tooltip: t.servicesRefresh,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.servicesHint,
                    style:
                        TextStyle(color: AppColors.textLo, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (s.results.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.accentAlt),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: s.results.length,
                  itemBuilder: (_, i) => _ServiceRow(
                    ping: s.results[i],
                    failedLabel: t.servicesUnreachable,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.ping, required this.failedLabel});
  final ServicePing ping;
  final String failedLabel;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(ping.quality);
    // Полоса: чем короче, тем быстрее (250 мс принимаем за «полную» шкалу).
    final frac = ping.rttMs == null
        ? 1.0
        : (ping.rttMs! / 250).clamp(0.06, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              ping.target.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onGlass,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 8, color: AppColors.onGlass.withValues(alpha: 0.05)),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(height: 8, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              ping.failed
                  ? failedLabel
                  : '${ping.rttMs!.toStringAsFixed(ping.rttMs! >= 100 ? 0 : 1)} ms',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _qualityColor(PingQuality q) => switch (q) {
      PingQuality.great => AppColors.green,
      PingQuality.good => AppColors.accentAlt,
      PingQuality.fair => AppColors.amber,
      PingQuality.poor => AppColors.red,
      PingQuality.failed => AppColors.textLo,
    };
