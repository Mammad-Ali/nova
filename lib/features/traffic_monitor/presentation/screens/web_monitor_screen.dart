import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/home_shell.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_button.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../more/presentation/more_links.dart';
import '../../../more/presentation/web_extras.dart' show downloadWithNotice;
import '../../../speedtest/data/datasources/ip_info.dart';
import '../../../speedtest/domain/entities/speedtest_record.dart';
import '../../../speedtest/presentation/providers/speedtest_history_provider.dart';
import '../../../speedtest/presentation/providers/speedtest_provider.dart';
import '../../../speedtest/presentation/widgets/history_sheet.dart';
import '../../data/web/browser_connection.dart';
import '../widgets/stability_card.dart';

/// The Monitor tab of the website. A page can't read the system's traffic
/// counters, so this is what a browser can see: the line's stability, the
/// connection as the browser describes it, and the visitor's own tests.
class WebMonitorScreen extends ConsumerWidget {
  const WebMonitorScreen({super.key});

  /// From this width on, the cards sit in two columns.
  static const _wide = 980.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wide;
        const gap = SizedBox(height: 16);
        final connection = Reveal(child: _ConnectionCard(strings: t));
        final stability = Reveal(
          delay: wide ? const Duration(milliseconds: 90) : Duration.zero,
          child: StabilityCard(strings: t),
        );
        final tests = Reveal(child: _TestsCard(strings: t));
        final inApp = Reveal(
          delay: wide ? const Duration(milliseconds: 90) : Duration.zero,
          child: _InAppCard(strings: t),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 24, wide ? 40 : 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1320 : 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(strings: t),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: [connection, gap, tests])),
                        const SizedBox(width: 20),
                        Expanded(child: Column(children: [stability, gap, inApp])),
                      ],
                    )
                  else ...[
                    stability,
                    gap,
                    connection,
                    gap,
                    tests,
                    gap,
                    inApp,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.strings});
  final AppStrings strings;

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
              Text(strings.webMonitorSubtitle, style: TextStyle(color: AppColors.onGlass, fontSize: 14)),
            ],
          ),
        ),
        const _LiveDot(),
        const LanguageButton(),
      ],
    );
  }
}

/// A green dot that breathes: the stability probe below is running.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 22,
        height: 22,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final v = Curves.easeOut.transform(_pulse.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 8 + 14 * v,
                  height: 8 + 14 * v,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green.withValues(alpha: 0.35 * (1 - v)),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── your connection ───────────────────────────

class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard({required this.strings});
  final AppStrings strings;

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  BrowserConnection? _conn = readBrowserConnection();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The browser updates its guess as the line changes: read it again
    // every few seconds rather than keep a stale figure.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _conn = readBrowserConnection());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    final info = ref.watch(ipInfoProvider);
    final data = info.asData?.value;
    final conn = _conn;

    final provider = info.isLoading
        ? t.providerDetecting
        : data != null && data.hasIsp
            ? data.isp!
            : '—';
    final type = switch (conn?.type) {
      'wifi' => (Icons.wifi_rounded, t.connWifi),
      'cellular' => (Icons.signal_cellular_alt_rounded, t.connCellular),
      'ethernet' => (Icons.settings_ethernet_rounded, t.connEthernet),
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type?.$1 ?? Icons.public_rounded, size: 18, color: AppColors.accentAlt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.connTitle,
                  style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (conn?.saveData ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.connSaveData,
                    style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Row(label: t.providerLabel, value: provider),
          if (data != null && data.location.isNotEmpty) _Row(label: '', value: data.location, faint: true),
          if (type != null) _Row(label: t.connType, value: type.$2),
          if (conn?.downlinkMbps != null)
            _Row(
              label: t.connSpeed,
              // Chrome reports 10 at most: past that it only knows "more".
              value: conn!.downlinkMbps! >= 10 ? '≥ 10 Mbps' : '≈ ${conn.downlinkMbps!.toStringAsFixed(1)} Mbps',
            ),
          if (conn?.rttMs != null) _Row(label: t.connLatency, value: '≈ ${conn!.rttMs} ms'),
          const SizedBox(height: 10),
          Text(
            conn == null ? t.connNoApi : t.connEstimateNote,
            style: TextStyle(color: AppColors.textLo, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.faint = false});
  final String label;
  final String value;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: faint ? 0 : 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: faint ? AppColors.textLo : AppColors.onGlass,
                fontSize: faint ? 12 : 14,
                fontWeight: faint ? FontWeight.w500 : FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── your tests ─────────────────────────────

class _TestsCard extends ConsumerWidget {
  const _TestsCard({required this.strings});
  final AppStrings strings;

  /// Tests on the chart: enough to see a trend, few enough to read.
  static const _shown = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = strings;
    final records = ref.watch(speedTestHistoryProvider);
    final recent = records.length > _shown ? records.sublist(records.length - _shown) : records;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: AppColors.accentAlt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.testsTitle,
                  style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (records.isNotEmpty)
                TextButton(
                  onPressed: () => showSpeedTestHistorySheet(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accentAlt),
                  child: Text('${t.historyTitle}  →'),
                ),
            ],
          ),
          if (records.isEmpty) ...[
            const SizedBox(height: 10),
            Text(t.testsNone, style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.45)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                ref.read(homeTabProvider.notifier).show(0);
                ref.read(speedTestControllerProvider.notifier).start();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(t.startTest),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Figure(label: t.reportTests, value: '${records.length}'),
                _Figure(
                  label: t.reportAvgDown,
                  value: _mbps(records.map((r) => r.downloadMbps).reduce((a, b) => a + b) / records.length),
                ),
                _Figure(
                  label: t.reportFastest,
                  value: _mbps(records.map((r) => r.downloadMbps).reduce(math.max)),
                  color: AppColors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.fill(t.testsLast, ['${recent.length}']),
                    style: TextStyle(color: AppColors.textLo, fontSize: 12),
                  ),
                ),
                _Key(color: AppColors.accentDown, label: t.download),
                const SizedBox(width: 12),
                _Key(color: AppColors.accentUp, label: t.upload),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(height: 150, child: _TestsChart(records: recent)),
          ],
        ],
      ),
    );
  }

  static String _mbps(double v) => '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} Mbps';
}

/// Download and upload of the recent tests, drawn in from the left as the
/// card comes into view.
class _TestsChart extends StatelessWidget {
  const _TestsChart({required this.records});
  final List<SpeedTestRecord> records;

  @override
  Widget build(BuildContext context) {
    final top = records.fold<double>(1, (m, r) => math.max(m, math.max(r.downloadMbps, r.uploadMbps)));
    LineChartBarData line(Color color, double Function(SpeedTestRecord) value, double grow) => LineChartBarData(
          spots: [
            for (var i = 0; i < records.length; i++) FlSpot(i.toDouble(), value(records[i]) * grow),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2.4,
          dotData: FlDotData(show: records.length <= 12),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
            ),
          ),
        );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, grow, _) => LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: 0,
          maxX: math.max(1, records.length - 1).toDouble(),
          minY: 0,
          maxY: top * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.onGlass.withValues(alpha: 0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} Mbps',
                    TextStyle(color: s.bar.color, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            line(AppColors.accentDown, (r) => r.downloadMbps, grow),
            line(AppColors.accentUp, (r) => r.uploadMbps, grow),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textLo, fontSize: 11.5)),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? AppColors.onGlass,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: AppColors.textLo, fontSize: 11.5)),
        ],
      );
}

// ───────────────────────────── in the app ─────────────────────────────

class _InAppCard extends StatelessWidget {
  const _InAppCard({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final t = strings;
    final mine = visitorDownload();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: glassCard(glow: AppColors.sun),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.sun),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.inAppTitle,
                  style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.inAppText, style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5)),
          const SizedBox(height: 14),
          FilledButton.icon(
            // Straight to the installer for this system; otherwise the
            // releases page, which lists them all.
            onPressed: () => mine != null ? downloadWithNotice(context, t, mine) : openLink(kReleasesUrl),
            icon: Icon(mine?.icon ?? Icons.download_rounded, size: 18),
            label: Text(mine != null ? AppStrings.fill(t.getAppFor, [mine.label]) : t.getApp),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
