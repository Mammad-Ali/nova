import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bufferbloat.dart';

/// The "latency under load" card: compares idle latency with latency while
/// downloading. The gap is bufferbloat — the reason games and calls stutter
/// whenever something else is using the link.
class BufferbloatCard extends StatelessWidget {
  const BufferbloatCard({
    super.key,
    required this.strings,
    required this.idlePingMs,
    required this.loadedPingMs,
  });

  final AppStrings strings;
  final double idlePingMs;
  final double loadedPingMs;

  @override
  Widget build(BuildContext context) {
    final r = evaluateBufferbloat(
      idlePingMs: idlePingMs,
      loadedPingMs: loadedPingMs,
    );
    final color = _levelColor(r.level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCard(glow: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.bloatTitle,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Pill(color: color, label: '${r.letter} · ${_levelLabel(r.level)}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Value(
                  label: strings.bloatIdle,
                  value: idlePingMs,
                  color: AppColors.textMid,
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.textLo),
              Expanded(
                child: _Value(
                  label: strings.bloatLoaded,
                  value: loadedPingMs,
                  color: color,
                ),
              ),
              Expanded(
                child: _Value(
                  label: strings.bloatIncrease,
                  value: r.increaseMs,
                  color: color,
                  prefix: '+',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // A visual bar showing how much delay the load adds.
          _BloatBar(
            idleMs: idlePingMs,
            loadedMs: loadedPingMs,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            strings.bloatHint,
            style: TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _levelLabel(BloatLevel l) => switch (l) {
        BloatLevel.excellent => strings.bloatExcellent,
        BloatLevel.good => strings.bloatGood,
        BloatLevel.fair => strings.bloatFair,
        BloatLevel.poor => strings.bloatPoor,
      };
}

Color _levelColor(BloatLevel l) => switch (l) {
      BloatLevel.excellent => AppColors.green,
      BloatLevel.good => AppColors.accentDown,
      BloatLevel.fair => AppColors.amber,
      BloatLevel.poor => AppColors.red,
    };

class _Value extends StatelessWidget {
  const _Value({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  final String label;
  final double value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textLo, fontSize: 11),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$prefix${value.toStringAsFixed(value >= 100 ? 0 : 1)}',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text('ms',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bar: the grey part is the baseline latency, the coloured part the increase
/// under load.
class _BloatBar extends StatelessWidget {
  const _BloatBar({
    required this.idleMs,
    required this.loadedMs,
    required this.color,
  });

  final double idleMs;
  final double loadedMs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = loadedMs <= 0 ? 1.0 : loadedMs;
    final idleFrac = (idleMs / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: (idleFrac * 1000).round().clamp(1, 1000),
              child: Container(color: AppColors.onGlass.withValues(alpha: 0.18)),
            ),
            Expanded(
              flex: ((1 - idleFrac) * 1000).round().clamp(1, 1000),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
