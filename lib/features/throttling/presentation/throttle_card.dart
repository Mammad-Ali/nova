import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/throttle_result.dart';
import 'throttle_provider.dart';

/// Карточка «режет ли провайдер видео»: сравнивает скорость до обычного CDN
/// и до серверов Netflix.
class ThrottleCard extends ConsumerWidget {
  const ThrottleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(throttleProvider);
    final result = s.result;
    final color = result == null
        ? AppColors.textMid
        : _verdictColor(result.verdict);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCard(glow: result == null ? null : color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.policy_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.throttleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (s.running)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accentAlt),
                )
              else
                TextButton(
                  onPressed: ref.read(throttleProvider.notifier).run,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    result == null ? t.throttleRun : t.servicesRefresh,
                    style: TextStyle(
                        color: AppColors.accentAlt,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.throttleHint,
            style: TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Text(
              s.error!,
              style: TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Bar(
                    label: t.throttleNeutral,
                    mbps: result.neutralMbps,
                    peak: _peak(result),
                    color: AppColors.accentDown,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Bar(
                    label: t.throttleVideo,
                    mbps: result.videoMbps,
                    peak: _peak(result),
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(_verdictIcon(result.verdict), size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _verdictText(t, result.verdict),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${(result.ratio * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (result.videoHost != null) ...[
              const SizedBox(height: 8),
              Text(
                '${t.serverLabel}: ${result.videoHost}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textLo, fontSize: 10),
              ),
            ],
          ],
        ],
      ),
    );
  }

  double _peak(ThrottleResult r) =>
      r.neutralMbps > r.videoMbps ? r.neutralMbps : r.videoMbps;
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.mbps,
    required this.peak,
    required this.color,
  });

  final String label;
  final double mbps;
  final double peak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final frac = peak <= 0 ? 0.0 : (mbps / peak).clamp(0.04, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textLo, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '${mbps.toStringAsFixed(mbps >= 100 ? 0 : 1)} Mbps',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                  height: 8, color: AppColors.onGlass.withValues(alpha: 0.05)),
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(height: 8, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _verdictColor(ThrottleVerdict v) => switch (v) {
      ThrottleVerdict.localCache => AppColors.green,
      ThrottleVerdict.none => AppColors.green,
      ThrottleVerdict.suspected => AppColors.amber,
      ThrottleVerdict.likely => AppColors.red,
    };

IconData _verdictIcon(ThrottleVerdict v) => switch (v) {
      ThrottleVerdict.localCache => Icons.bolt_rounded,
      ThrottleVerdict.none => Icons.check_circle_rounded,
      ThrottleVerdict.suspected => Icons.warning_amber_rounded,
      ThrottleVerdict.likely => Icons.report_rounded,
    };

String _verdictText(AppStrings t, ThrottleVerdict v) => switch (v) {
      ThrottleVerdict.localCache => t.throttleLocalCache,
      ThrottleVerdict.none => t.throttleNone,
      ThrottleVerdict.suspected => t.throttleSuspected,
      ThrottleVerdict.likely => t.throttleLikely,
    };
