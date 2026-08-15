import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ping_sample.dart';
import '../providers/stability_provider.dart';

/// Stability card: a live two-minute latency chart, packet loss, and a
/// warning whenever the connection actually drops.
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
      padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: glassCard(glow: outage ? AppColors.red : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                outage ? Icons.wifi_off_rounded : Icons.network_check_rounded,
                size: 18,
                color: outage ? AppColors.red : AppColors.accentAlt,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.stabilityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
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
          SizedBox(height: 10),
          Row(
            children: [
              _Stat(
                label: strings.ping,
                value: _ms(s.currentMs),
                color: AppColors.onGlass,
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
          SizedBox(height: 14),
          SizedBox(
            height: 62,
            child: _PingChart(samples: s.samples),
          ),
          if (outage) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.red),
                SizedBox(width: 6),
                Text(
                  '${strings.stabilityOutage} · ${s.currentOutage}',
                  style: TextStyle(color: AppColors.red, fontSize: 12),
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
    this.color,
    this.big = false,
  });

  final String label;
  final String value;

  /// null means the palette's regular muted text colour.
  final Color? color;
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
            style: TextStyle(color: AppColors.textLo, fontSize: 10),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textMid,
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

/// Latency bars; lost samples are drawn as full-height red marks.
class _PingChart extends StatelessWidget {
  const _PingChart({required this.samples});
  final List<PingSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return Center(
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

    // Scale top follows the peak but never drops below 60 ms, so small
    // fluctuations don't make the chart jump.
    var peak = 60.0;
    for (final s in samples) {
      final r = s.rttMs;
      if (r != null && r > peak) peak = r;
    }

    final paint = Paint();
    // Right-aligned: new samples arrive on the right.
    final offset = capacity - samples.length;

    for (var i = 0; i < samples.length; i++) {
      final x = (offset + i) * slot + slot / 2;
      final s = samples[i];

      if (s.lost) {
        // A loss is a full-height red mark.
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
      // Colour by latency: teal → amber → red.
      paint.color = rtt < 60
          ? AppColors.accentAlt
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
