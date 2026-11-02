import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/service_target.dart';
import 'service_ping_provider.dart';
import 'service_ping_sheet.dart';

/// Latency to popular services, right on the speed test screen: one tile
/// per service, measured when the screen opens and again after every test.
class ServicesCard extends ConsumerWidget {
  const ServicesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(servicePingProvider);

    // Until the first run finishes, the tiles show the services in their
    // usual order with a dash, so the card doesn't jump when results land.
    final pings = s.results.isNotEmpty
        ? s.results
        : [for (final target in kServiceTargets) ServicePing(target: target)];
    final measured = s.results.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
      decoration: glassCard(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: AppColors.accentAlt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.servicesTitle,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: s.running
                    ? Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentAlt,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: ref.read(servicePingProvider.notifier).run,
                        icon: Icon(Icons.refresh_rounded, size: 20, color: AppColors.textMid),
                        tooltip: t.servicesRefresh,
                      ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 12),
            child: Text(
              // Browser timings carry the page's own overhead.
              kIsWeb ? t.servicesWebNote : t.servicesHint,
              style: TextStyle(color: AppColors.textLo, fontSize: 11.5, height: 1.35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LayoutBuilder(
              builder: (context, box) {
                // Three tiles a row where they fit, two on a narrow phone.
                final columns = box.maxWidth >= 330 ? 3 : 2;
                const gap = 8.0;
                final width = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final ping in pings)
                      SizedBox(
                        width: width,
                        child: _ServiceTile(
                          ping: ping,
                          measured: measured,
                          failedLabel: t.servicesUnreachable,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.ping,
    required this.measured,
    required this.failedLabel,
  });

  final ServicePing ping;
  final bool measured;
  final String failedLabel;

  @override
  Widget build(BuildContext context) {
    final color = measured ? pingQualityColor(ping.quality) : AppColors.textLo;
    final rtt = ping.rttMs;
    final value = !measured
        ? '—'
        : rtt == null
            ? failedLabel
            : rtt.toStringAsFixed(rtt >= 100 ? 0 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.onGlass.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: measured ? 0.28 : 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ping.target.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMid,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: rtt == null && measured ? 14 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (measured && rtt != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    'ms',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
