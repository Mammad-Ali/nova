import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/byte_format.dart';
import '../../domain/entities/usage_stats.dart';

/// Monthly usage: the running total, a projection for the end of the month
/// and a per-day bar chart.
class MonthlyUsageCard extends StatelessWidget {
  const MonthlyUsageCard({
    super.key,
    required this.strings,
    required this.stats,
  });

  final AppStrings strings;
  final UsageStats stats;

  @override
  Widget build(BuildContext context) {
    final days = stats.currentMonthDays;
    final month = formatBytes(stats.monthBytes);
    final forecastBytes = stats.monthForecastBytes;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.accentUp),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.usageMonth,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${month.value} ${month.unit}',
                style: TextStyle(
                  color: AppColors.onGlass,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (forecastBytes != null) ...[
            const SizedBox(height: 12),
            _ForecastRow(strings: strings, bytes: forecastBytes),
          ],
          if (days.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              strings.usageByDay,
              style: TextStyle(color: AppColors.textLo, fontSize: 11),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 54, child: _DayBars(days: days)),
          ],
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.strings, required this.bytes});
  final AppStrings strings;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final f = formatBytes(bytes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.onGlass.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onGlass.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded,
              size: 16, color: AppColors.accentAlt),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.usageForecast,
                  style: TextStyle(color: AppColors.textLo, fontSize: 11),
                ),
                const SizedBox(height: 1),
                Text(
                  strings.usageForecastHint,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textLo, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '~${f.value} ${f.unit}',
            style: TextStyle(
              color: AppColors.accentAlt,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-day usage bars for the current month. Today is highlighted.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.days});
  final List<MapEntry<String, int>> days;

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final d in days) {
      if (d.value > peak) peak = d.value;
    }
    final todayKey = days.isEmpty ? '' : days.last.key;

    return LayoutBuilder(
      builder: (context, c) {
        // The whole month is shown; on narrow windows the bars just get thinner.
        final slot = c.maxWidth / days.length;
        final barW = (slot * 0.62).clamp(2.0, 14.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in days)
              Tooltip(
                message: '${d.key} · ${formatBytes(d.value)}',
                child: Container(
                  width: barW,
                  height: (d.value / peak).clamp(0.03, 1.0) * 54,
                  decoration: BoxDecoration(
                    color: d.key == todayKey
                        ? AppColors.accentUp
                        : AppColors.accentUp.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
