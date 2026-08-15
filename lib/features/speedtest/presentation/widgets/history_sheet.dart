import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/speedtest_record.dart';
import '../providers/speedtest_history_provider.dart';

/// Opens the sheet listing past speed test results.
Future<void> showSpeedTestHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _HistorySheet(),
  );
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final records = ref.watch(speedTestHistoryProvider);
    // Newest entries are easier to read at the top, so reverse the list.
    final newestFirst = records.reversed.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12), width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onGlass.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.historyTitle,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (records.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(speedTestHistoryProvider.notifier).clear(),
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.red),
                        label: Text(t.historyClear,
                            style: TextStyle(color: AppColors.red)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? _EmptyState(text: t.historyEmpty)
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (records.length >= 2) ...[
                            _TrendChart(records: records),
                            const SizedBox(height: 20),
                          ],
                          for (final r in newestFirst) ...[
                            _HistoryRow(record: r),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, color: AppColors.textLo, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(color: AppColors.textLo, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── trend sparkline ──────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.records});
  final List<SpeedTestRecord> records;

  @override
  Widget build(BuildContext context) {
    final downSpots = <FlSpot>[];
    final upSpots = <FlSpot>[];
    var maxY = 1.0;
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      downSpots.add(FlSpot(i.toDouble(), r.downloadMbps));
      upSpots.add(FlSpot(i.toDouble(), r.uploadMbps));
      if (r.downloadMbps > maxY) maxY = r.downloadMbps;
      if (r.uploadMbps > maxY) maxY = r.uploadMbps;
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: glassCard(),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (records.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          clipData: const FlClipData.all(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            _line(downSpots, AppColors.accentDown),
            _line(upSpots, AppColors.accentUp),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length <= 12,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 2.5,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

// ─────────────────────────── result row ───────────────────────────────────

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});
  final SpeedTestRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: glassCard(radius: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              _fmtDate(record.timestamp),
              style: TextStyle(
                color: AppColors.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _statChip(
              Icons.south_rounded,
              AppColors.accentDown,
              record.downloadMbps,
            ),
          ),
          Expanded(
            flex: 3,
            child: _statChip(
              Icons.north_rounded,
              AppColors.accentUp,
              record.uploadMbps,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${record.pingMs.toStringAsFixed(0)} ms',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppColors.textLo,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, Color color, double mbps) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          mbps >= 100 ? mbps.toStringAsFixed(0) : mbps.toStringAsFixed(1),
          style: TextStyle(
            color: AppColors.onGlass,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _fmtDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}
