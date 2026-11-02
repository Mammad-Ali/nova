import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/call_check.dart';
import 'call_check_provider.dart';

/// Opens the call check.
void showCallCheckSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CallCheckSheet(),
  );
}

class _CallCheckSheet extends ConsumerWidget {
  const _CallCheckSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(callCheckProvider);
    final result = s.result;
    final shown = result ?? s.live;
    final started = s.running || result != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Icon(Icons.video_call_rounded, color: AppColors.accentAlt),
                      const SizedBox(width: 10),
                      Text(
                        t.callCheckTitle,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.callCheckHint,
                    style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4),
                  ),
                  if (started) ...[
                    const SizedBox(height: 16),
                    _RoundTripChart(samples: s.samples),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Figure(label: t.ping, value: _ms(shown.latencyMs)),
                        const SizedBox(width: 8),
                        _Figure(label: t.jitter, value: _ms(shown.jitterMs)),
                        const SizedBox(width: 8),
                        _Figure(
                          label: t.callLoss,
                          value: s.samples.isEmpty ? '—' : '${shown.lossPercent.toStringAsFixed(shown.lossPercent < 10 ? 1 : 0)} %',
                        ),
                      ],
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    for (final kind in CallKind.values)
                      _VerdictRow(
                        label: _kindLabel(t, kind),
                        verdict: judgeCall(kind, result),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      result.downMbps == null
                          ? t.callNoSpeed
                          : AppStrings.fill(t.callSpeedFrom, [
                              '↓ ${result.downMbps!.toStringAsFixed(1)}  ↑ ${result.upMbps!.toStringAsFixed(1)} Mbps',
                            ]),
                      style: TextStyle(color: AppColors.textLo, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ..._tips(t, result),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: s.running ? null : ref.read(callCheckProvider.notifier).run,
                    icon: Icon(
                      s.running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(
                      s.running
                          ? AppStrings.fill(t.callCheckLeft, [
                              '${math.max(0, (CallCheckNotifier.duration.inSeconds * (1 - s.progress)).ceil())}',
                            ])
                          : result == null
                              ? t.callCheckStart
                              : t.callCheckAgain,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.onGlass.withValues(alpha: 0.10),
                      disabledForegroundColor: AppColors.textMid,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (s.running) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s.progress,
                        minHeight: 4,
                        color: AppColors.accentAlt,
                        backgroundColor: AppColors.onGlass.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One tip per problem, in the order a person can do something about it.
  List<Widget> _tips(AppStrings t, CallMetrics result) {
    final problems = <CallProblem>{
      for (final kind in CallKind.values) ...callProblems(kind, result).keys,
    };
    if (problems.isEmpty) {
      return [_Tip(text: t.callAllGood, color: AppColors.green, icon: Icons.check_circle_rounded)];
    }
    return [
      for (final problem in CallProblem.values)
        if (problems.contains(problem))
          _Tip(
            text: switch (problem) {
              CallProblem.unreachable => t.callTipUnreachable,
              CallProblem.loss => t.callTipLoss,
              CallProblem.jitter => t.callTipJitter,
              CallProblem.latency => t.callTipLatency,
              CallProblem.upload => t.callTipUpload,
              CallProblem.download => t.callTipDownload,
            },
            color: AppColors.amber,
            icon: Icons.lightbulb_outline_rounded,
          ),
    ];
  }
}

String _ms(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ms';

String _kindLabel(AppStrings t, CallKind kind) => switch (kind) {
      CallKind.voice => t.callVoice,
      CallKind.video => t.callVideo,
      CallKind.group => t.callGroup,
    };

/// Every round trip as it came back; lost ones drop to a red mark on the
/// floor of the chart.
class _RoundTripChart extends StatelessWidget {
  const _RoundTripChart({required this.samples});
  final List<double?> samples;

  @override
  Widget build(BuildContext context) {
    const slots = 80; // 20 s × 4 a second
    final ok = [for (final s in samples) ?s];
    final top = math.max(100.0, ok.isEmpty ? 100.0 : ok.reduce(math.max) * 1.2);
    final spots = [
      for (var i = 0; i < samples.length; i++)
        if (samples[i] != null) FlSpot(i.toDouble(), samples[i]!),
    ];
    final lost = [
      for (var i = 0; i < samples.length; i++)
        if (samples[i] == null) FlSpot(i.toDouble(), 0),
    ];

    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      decoration: glassCard(radius: 16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: slots - 1,
          minY: 0,
          maxY: top,
          clipData: const FlClipData.all(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: AppColors.accentAlt,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentAlt.withValues(alpha: 0.22),
                    AppColors.accentAlt.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            if (lost.isNotEmpty)
              LineChartBarData(
                spots: lost,
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.red,
                    strokeWidth: 0,
                  ),
                ),
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: glassCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.textLo, fontSize: 11.5)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.onGlass,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerdictRow extends ConsumerWidget {
  const _VerdictRow({required this.label, required this.verdict});
  final String label;
  final CallVerdict verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final (color, icon, text) = switch (verdict) {
      CallVerdict.ready => (AppColors.green, Icons.check_circle_rounded, t.callReady),
      CallVerdict.shaky => (AppColors.amber, Icons.error_outline_rounded, t.callShaky),
      CallVerdict.notReady => (AppColors.red, Icons.cancel_rounded, t.callNotReady),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.onGlass, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textMid, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
