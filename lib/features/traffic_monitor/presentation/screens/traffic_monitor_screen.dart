import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_button.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/byte_format.dart';
import '../../../lan_scan/presentation/lan_scan_sheet.dart';
import '../providers/traffic_provider.dart';
import '../providers/usage_stats_provider.dart';
import '../widgets/live_traffic_chart.dart';
import '../widgets/monthly_usage_card.dart';
import '../widgets/stability_card.dart';

/// The passive monitoring tab: live system-wide Rx/Tx traffic.
class TrafficMonitorScreen extends ConsumerWidget {
  const TrafficMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final feed = ref.watch(trafficStreamProvider);
    final history = ref.watch(trafficHistoryProvider);
    final usage = ref.watch(usageStatsProvider);
    final isLive = feed.hasValue && !feed.hasError;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            strings: t,
            isLive: isLive,
            onReset: () => ref.read(trafficHistoryProvider.notifier).reset(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SpeedTile(
                  label: t.download,
                  peakLabel: t.peak,
                  sessionLabel: t.session,
                  icon: Icons.south_rounded,
                  accent: AppColors.accentDown,
                  bytesPerSec: history.currentRxPerSec,
                  peakBytesPerSec: history.peakRxPerSec,
                  sessionBytes: history.sessionRxBytes,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SpeedTile(
                  label: t.upload,
                  peakLabel: t.peak,
                  sessionLabel: t.session,
                  icon: Icons.north_rounded,
                  accent: AppColors.accentUp,
                  bytesPerSec: history.currentTxPerSec,
                  peakBytesPerSec: history.peakTxPerSec,
                  sessionBytes: history.sessionTxBytes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _UsageStrip(
            strings: t,
            hourBytes: usage.hourBytes,
            dayBytes: usage.dayBytes,
          ),
          const SizedBox(height: 16),
          _ChartCard(
            strings: t,
            snapshots: history.snapshots,
            error: feed.hasError ? feed.error : null,
          ),
          const SizedBox(height: 16),
          MonthlyUsageCard(strings: t, stats: usage),
          const SizedBox(height: 16),
          StabilityCard(strings: t),
        ],
      ),
    );
  }
}

// ─────────────────────────── heading ─────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.strings,
    required this.isLive,
    required this.onReset,
  });
  final AppStrings strings;
  final bool isLive;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.tabMonitor,
                style: TextStyle(
                  color: AppColors.sun,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                strings.monitorSubtitle,
                style: TextStyle(color: AppColors.onGlass, fontSize: 14),
              ),
            ],
          ),
        ),
        _LiveBadge(isLive: isLive),
        const LanguageButton(),
        IconButton(
          onPressed: () => showLanScanSheet(context),
          icon: Icon(Icons.devices_rounded, color: AppColors.textMid),
          tooltip: strings.lanTitle,
        ),
        IconButton(
          onPressed: onReset,
          icon: Icon(Icons.restart_alt_rounded, color: AppColors.textMid),
          tooltip: strings.resetSession,
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.green : AppColors.textLo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            _PulsingDot(color: AppColors.green)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: 7),
          Text(
            isLive ? 'LIVE' : 'IDLE',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6 * (1 - t)),
                blurRadius: 6 + 6 * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────── hourly / daily usage ────────────────────

class _UsageStrip extends StatelessWidget {
  const _UsageStrip({
    required this.strings,
    required this.hourBytes,
    required this.dayBytes,
  });
  final AppStrings strings;
  final int hourBytes;
  final int dayBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: glassCard(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _UsageCell(
                  icon: Icons.schedule_rounded,
                  label: strings.usagePastHour,
                  bytes: hourBytes,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: AppColors.onGlass.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _UsageCell(
                  icon: Icons.today_rounded,
                  label: strings.usageToday,
                  bytes: dayBytes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.usageNote,
            style: TextStyle(color: AppColors.textLo, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _UsageCell extends StatelessWidget {
  const _UsageCell({
    required this.icon,
    required this.label,
    required this.bytes,
  });
  final IconData icon;
  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final f = formatBytes(bytes);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textMid),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textLo, fontSize: 11),
            ),
            const SizedBox(height: 1),
            Text(
              '${f.value} ${f.unit}',
              style: TextStyle(
                color: AppColors.onGlass,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── speed tile ──────────────────────────

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({
    required this.label,
    required this.peakLabel,
    required this.sessionLabel,
    required this.icon,
    required this.accent,
    required this.bytesPerSec,
    required this.peakBytesPerSec,
    required this.sessionBytes,
  });

  final String label;
  final String peakLabel;
  final String sessionLabel;
  final IconData icon;
  final Color accent;
  final int bytesPerSec;
  final int peakBytesPerSec;
  final int sessionBytes;

  @override
  Widget build(BuildContext context) {
    final rate = formatRate(bytesPerSec);
    final peak = formatRate(peakBytesPerSec);
    final total = formatBytes(sessionBytes);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCard(glow: accent).copyWith(
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMid,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  rate.value,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    rate.unit,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(label: peakLabel, value: '${peak.value} ${peak.unit}'),
              const SizedBox(width: 18),
              _MiniStat(
                  label: sessionLabel, value: '${total.value} ${total.unit}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

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
            style: TextStyle(
              color: AppColors.textLo,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMid,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── chart card ──────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.strings,
    required this.snapshots,
    this.error,
  });

  final AppStrings strings;
  final List<dynamic> snapshots;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.last2min,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _Legend(color: AppColors.accentDown, label: strings.download),
              const SizedBox(width: 14),
              _Legend(color: AppColors.accentUp, label: strings.upload),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (error != null) {
      return _CenteredHint(
        icon: Icons.error_outline_rounded,
        text: '${strings.sourceUnavailable}\n$error',
      );
    }
    if (snapshots.isEmpty) {
      return _CenteredHint(
        icon: Icons.timelapse_rounded,
        text: strings.waitingFirst,
      );
    }
    return LiveTrafficChart(snapshots: snapshots.cast());
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.textMid, fontSize: 12),
        ),
      ],
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textLo, size: 30),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLo, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
