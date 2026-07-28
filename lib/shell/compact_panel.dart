import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/l10n/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/byte_format.dart';
import '../features/speedtest/domain/entities/speedtest_models.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/traffic_monitor/presentation/providers/traffic_provider.dart';
import '../features/traffic_monitor/presentation/providers/usage_stats_provider.dart';
import '../features/traffic_monitor/presentation/widgets/live_traffic_chart.dart';
import 'compact_mode.dart';

/// Мини-панель под иконкой меню-бара: живая скорость, график, расход за
/// час/день и кнопка запуска теста — всё без открытия основного окна.
class CompactPanel extends ConsumerWidget {
  const CompactPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final history = ref.watch(trafficHistoryProvider);
    final usage = ref.watch(usageStatsProvider);
    final test = ref.watch(speedTestControllerProvider);

    return Padding(
      // Сверху оставляем место: рамки окна нет, но перетаскивать за шапку надо.
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Шапка: за неё можно двигать окно, справа — выход в полный вид.
          DragToMoveArea(
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.primaryGradient.createShader(r),
                  child: Text(
                    'Pulsar',
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: ref.read(compactModeProvider.notifier).exit,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: t.compactExpand,
                  icon: Icon(Icons.open_in_full_rounded,
                      color: AppColors.textMid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniTile(
                  icon: Icons.south_rounded,
                  color: AppColors.accentDown,
                  bytesPerSec: history.currentRxPerSec,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniTile(
                  icon: Icons.north_rounded,
                  color: AppColors.accentUp,
                  bytesPerSec: history.currentTxPerSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              decoration: glassCard(radius: 14),
              child: history.snapshots.isEmpty
                  ? Center(
                      child: Text(
                        t.waitingFirst,
                        style: TextStyle(
                            color: AppColors.textLo, fontSize: 11),
                      ),
                    )
                  : LiveTrafficChart(snapshots: history.snapshots),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Usage(label: t.usagePastHour, bytes: usage.hourBytes),
              ),
              Expanded(
                child: _Usage(label: t.usageToday, bytes: usage.dayBytes),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TestButton(
            phase: test.phase,
            running: test.isRunning,
            mbps: test.isRunning ? test.displayMbps : test.downloadMbps,
            label: test.isRunning ? t.stopTest : t.startTest,
            onTap: test.isRunning
                ? ref.read(speedTestControllerProvider.notifier).stop
                : ref.read(speedTestControllerProvider.notifier).start,
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.color,
    required this.bytesPerSec,
  });

  final IconData icon;
  final Color color;
  final int bytesPerSec;

  @override
  Widget build(BuildContext context) {
    final r = formatRate(bytesPerSec);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: glassCard(radius: 14).copyWith(
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    r.value,
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    r.unit,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({required this.label, required this.bytes});
  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final f = formatBytes(bytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textLo, fontSize: 10)),
        const SizedBox(height: 1),
        Text(
          '${f.value} ${f.unit}',
          style: TextStyle(
              color: AppColors.onGlass, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.phase,
    required this.running,
    required this.mbps,
    required this.label,
    required this.onTap,
  });

  final TestPhase phase;
  final bool running;
  final double? mbps;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showValue = mbps != null && mbps! > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: running ? null : AppColors.primaryGradient,
          color: running ? AppColors.red.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(14),
          border: running
              ? Border.all(color: AppColors.red.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              running ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: running ? AppColors.red : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              showValue
                  ? '${mbps!.toStringAsFixed(mbps! >= 100 ? 0 : 1)} Mbps'
                  : label,
              style: TextStyle(
                color: running ? AppColors.red : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
