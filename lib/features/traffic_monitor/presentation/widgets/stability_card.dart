import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ping_sample.dart';
import '../providers/stability_provider.dart';

/// Карточка стабильности: живой график задержки за 2 минуты, потери пакетов
/// и предупреждение, когда связь реально пропадает.
class StabilityCard extends ConsumerWidget {
  const StabilityCard({super.key, required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stabilityProvider);
    final notifier = ref.read(stabilityProvider.notifier);

    final outage = s.currentOutage > 0;
    final loss = s.lossPercent;
    final lossColor = loss <= 0
        ? AppColors.green
        : (loss < 5 ? AppColors.amber : AppColors.red);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: glassCard(glow: outage ? AppColors.red : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                outage ? Icons.wifi_off_rounded : Icons.network_check_rounded,
                size: 18,
                color: outage ? AppColors.red : AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.stabilityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: notifier.toggle,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  s.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.textMid,
                ),
                tooltip: s.running ? strings.pause : strings.resume,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(
                label: strings.ping,
                value: _ms(s.currentMs),
                color: Colors.white,
                big: true,
              ),
              _Stat(label: strings.stabilityAvg, value: _ms(s.avgMs)),
              _Stat(label: strings.stabilityMax, value: _ms(s.maxMs)),
              _Stat(
                label: strings.stabilityLoss,
                value: '${loss.toStringAsFixed(loss == 0 ? 0 : 1)}%',
                color: lossColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 62,
            child: _PingChart(samples: s.samples),
          ),
          if (outage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.red),
                const SizedBox(width: 6),
                Text(
                  '${strings.stabilityOutage} · ${s.currentOutage}',
                  style: const TextStyle(color: AppColors.red, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _ms(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ms';
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color = AppColors.textMid,
    this.big = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textLo, fontSize: 10),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: big ? 19 : 14,
                fontWeight: big ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Столбики задержки; потерянные замеры — красные метки снизу.
class _PingChart extends StatelessWidget {
  const _PingChart({required this.samples});
  final List<PingSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Center(
        child: Text('…', style: TextStyle(color: AppColors.textLo)),
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _PingPainter(samples),
    );
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter(this.samples);
  final List<PingSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    const capacity = StabilityNotifier.capacity;
    final slot = size.width / capacity;
    final barW = (slot * 0.62).clamp(1.0, 6.0);

    // Верх шкалы — по пику, но не ниже 60 мс, чтобы мелочь не прыгала.
    var peak = 60.0;
    for (final s in samples) {
      final r = s.rttMs;
      if (r != null && r > peak) peak = r;
    }

    final paint = Paint();
    // Правое выравнивание: новые замеры приходят справа.
    final offset = capacity - samples.length;

    for (var i = 0; i < samples.length; i++) {
      final x = (offset + i) * slot + slot / 2;
      final s = samples[i];

      if (s.lost) {
        // Потеря — красная метка на всю высоту.
        paint.color = AppColors.red.withValues(alpha: 0.75);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - barW / 2, 0, barW, size.height),
            const Radius.circular(2),
          ),
          paint,
        );
        continue;
      }

      final rtt = s.rttMs!;
      final h = (rtt / peak).clamp(0.04, 1.0) * size.height;
      // Цвет по величине задержки: бирюза → жёлтый → красный.
      paint.color = rtt < 60
          ? AppColors.teal
          : (rtt < 150 ? AppColors.amber : AppColors.red);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barW / 2, size.height - h, barW, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PingPainter old) =>
      !identical(old.samples, samples);
}
