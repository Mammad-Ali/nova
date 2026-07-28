import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/byte_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/network_snapshot.dart';
import '../providers/traffic_provider.dart' show TrafficHistoryNotifier;

class LiveTrafficChart extends StatelessWidget {
  const LiveTrafficChart({
    super.key,
    required this.snapshots,
    this.downloadColor = const Color(0xFF22D3EE),
    this.uploadColor = const Color(0xFFA855F7),
  });

  final List<NetworkSnapshot> snapshots;
  final Color downloadColor;
  final Color uploadColor;

  static const int _capacity = TrafficHistoryNotifier.capacity;

  @override
  Widget build(BuildContext context) {
    final n = snapshots.length;
    final rxSpots = <FlSpot>[];
    final txSpots = <FlSpot>[];
    for (var i = 0; i < n; i++) {
      final x = (_capacity - n + i).toDouble();
      rxSpots.add(FlSpot(x, snapshots[i].rxPerSec.toDouble()));
      txSpots.add(FlSpot(x, snapshots[i].txPerSec.toDouble()));
    }

    final maxY = _niceMaxY();
    final gridStep = maxY / 4;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_capacity - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridStep,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.onGlass.withValues(alpha: 0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: gridStep,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value >= maxY) return const SizedBox.shrink();
                final f = formatBytes(value);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '${f.value} ${f.unit}',
                    style: TextStyle(
                      color: AppColors.onGlass.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          _line(rxSpots, downloadColor),
          _line(txSpots, uploadColor),
        ],
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.linear,
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  double _niceMaxY() {
    var peak = 0;
    for (final s in snapshots) {
      if (s.rxPerSec > peak) peak = s.rxPerSec;
      if (s.txPerSec > peak) peak = s.txPerSec;
    }
    const floor = 64 * 1024;
    final target = math.max(peak * 1.25, floor.toDouble());
    return _roundUpNice(target);
  }

  double _roundUpNice(double v) {
    if (v <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final norm = v / magnitude;
    final nice = norm <= 1 ? 1.0 : (norm <= 2 ? 2.0 : (norm <= 5 ? 5.0 : 10.0));
    return nice * magnitude;
  }
}