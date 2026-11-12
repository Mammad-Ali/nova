import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/byte_format.dart';
import '../../domain/entities/app_traffic.dart';
import '../providers/app_traffic_provider.dart';
import '../providers/app_usage_tracker.dart';
import 'app_badge.dart';

/// One app up close: today, the past week day by day, and its daily limit.
void showAppDetailSheet(BuildContext context, {required AppTraffic app, required AppStrings strings}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AppDetailSheet(app: app, strings: strings),
  );
}

/// "1 GB" rather than "1.00 GB": the limits are round numbers.
String _round(int bytes) => bytes % (1024 * _mb) == 0 ? '${bytes ~/ (1024 * _mb)} GB' : '${bytes ~/ _mb} MB';

/// The limits offered, in bytes.
const _mb = 1024 * 1024;
const _limitChoices = [250 * _mb, 500 * _mb, 1024 * _mb, 2048 * _mb, 5120 * _mb, 10240 * _mb];

class _AppDetailSheet extends ConsumerStatefulWidget {
  const _AppDetailSheet({required this.app, required this.strings});
  final AppTraffic app;
  final AppStrings strings;

  @override
  ConsumerState<_AppDetailSheet> createState() => _AppDetailSheetState();
}

class _AppDetailSheetState extends ConsumerState<_AppDetailSheet> {
  late final Future<List<int>> _week;
  late final bool _mac;

  @override
  void initState() {
    super.initState();
    _mac = ref.read(appTrafficProvider).mode == AppTrafficMode.mac;
    _week = ref.read(appTrafficProvider.notifier).week(widget.app.key);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    final app = widget.app;
    final name = appDisplayName(app, t, mac: _mac);
    final limit = ref.watch(appLimitsProvider)[app.key];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.onGlass.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AppBadge(app: app, name: name, color: appColor(app), size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.onGlass, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<int>>(
                  future: _week,
                  builder: (context, snap) {
                    final days = snap.data;
                    if (days == null) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _Week(days: days, limit: limit, strings: t);
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  t.appsLimit,
                  style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _mac ? t.appsLimitHintMac : t.appsLimitHintAndroid,
                  style: TextStyle(color: AppColors.textLo, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in <int?>[null, ..._limitChoices])
                      ChoiceChip(
                        label: Text(choice == null ? t.appsLimitOff : _round(choice)),
                        selected: choice == limit,
                        onSelected: (_) => ref.read(appLimitsProvider.notifier).set(app.key, choice),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: choice == limit ? Colors.black : AppColors.onGlass,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: Colors.white,
                        backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                        side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.14)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today and the week as numbers, then a bar per day.
class _Week extends StatelessWidget {
  const _Week({required this.days, required this.limit, required this.strings});
  final List<int> days;
  final int? limit;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final today = days.isEmpty ? 0 : days.last;
    final week = days.fold<int>(0, (a, b) => a + b);
    final top = math.max(days.fold<int>(1, math.max), limit ?? 0).toDouble();
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Figure(label: strings.appsPeriodToday, value: formatBytes(today).toString())),
            Expanded(child: _Figure(label: strings.appsPeriodWeek, value: formatBytes(week).toString())),
          ],
        ),
        const SizedBox(height: 18),
        Text(strings.appsLast7Days, style: TextStyle(color: AppColors.textLo, fontSize: 12)),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: top * 1.15,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final day = now.subtract(Duration(days: days.length - 1 - value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: AppColors.textLo, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (limit != null)
                    HorizontalLine(
                      y: limit!.toDouble(),
                      color: AppColors.red.withValues(alpha: 0.7),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                ],
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    formatBytes(rod.toY).toString(),
                    TextStyle(color: AppColors.onGlass, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: days[i].toDouble(),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        color: limit != null && days[i] >= limit!
                            ? AppColors.red
                            : i == days.length - 1
                                ? AppColors.sun
                                : AppColors.accentDown,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textLo, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}
