import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_activity.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_button.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../leaderboard/presentation/leaderboard_sheet.dart';
import '../../../more/presentation/web_extras.dart';
import '../../../services_ping/presentation/service_ping_sheet.dart';
import '../../../settings/settings_sheet.dart';
import '../../../throttling/presentation/throttle_card.dart';
import '../../../wifi/wifi_chip.dart';
import '../../data/datasources/ip_info.dart';
import '../../domain/entities/speedtest_models.dart';
import '../providers/speedtest_history_provider.dart';
import '../providers/speedtest_provider.dart';
import '../widgets/bufferbloat_card.dart';
import '../widgets/comfort_section.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/history_sheet.dart';
import '../widgets/odometer_text.dart';
import '../widgets/result_summary.dart';
import '../widgets/speed_gauge.dart';

/// The active speed test tab — measures the connection's peak throughput.
class SpeedTestScreen extends ConsumerStatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  ConsumerState<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends ConsumerState<SpeedTestScreen> {
  final _confetti = ConfettiController();

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(speedTestControllerProvider);
    final ctrl = ref.read(speedTestControllerProvider.notifier);

    // Fire confetti when a personal best has just been beaten.
    ref.listen(speedTestControllerProvider, (prev, next) {
      final justFinished = next.phase == TestPhase.done &&
          (prev == null || prev.phase != TestPhase.done);
      if (justFinished && next.downloadMbps != null) {
        final hist = ref.read(speedTestHistoryProvider);
        if (hist.length >= 2) {
          final best = hist
              .sublist(0, hist.length - 1)
              .map((r) => r.downloadMbps)
              .reduce((a, b) => a > b ? a : b);
          if (next.downloadMbps! > best + 0.01) _confetti.fire();
        }
      }
    });

    // The gauge is always sun yellow; only the metrics below use colour.
    const gaugeColor = AppColors.sun;
    final gaugeValue = s.isRunning ? s.displayMbps : (s.downloadMbps ?? 0);

    final showComfort = !s.isRunning &&
        s.downloadMbps != null &&
        s.uploadMbps != null &&
        s.pingMs != null;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Title(strings: t),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: SpeedGauge(
                    value: gaugeValue,
                    max: s.gaugeMax,
                    color: gaugeColor,
                    active: s.isRunning,
                    paused: !ref.watch(uiActiveProvider),
                    child: _GaugeCenter(
                      phaseLabel: _phaseLabel(t, s.phase),
                      value: s.isRunning ? s.displayMbps : s.downloadMbps,
                      color: gaugeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PhaseBar(
                  active: s.isRunning,
                  progress: s.phaseProgress,
                  color: gaugeColor),
              const SizedBox(height: 14),
              _ProviderRow(strings: t, serverName: s.serverName),
              const SizedBox(height: 8),
              const WifiChip(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.wifi_tethering_rounded,
                      label: t.ping,
                      value: s.pingMs,
                      unit: 'ms',
                      accent: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.graphic_eq_rounded,
                      label: t.jitter,
                      value: s.jitterMs,
                      unit: 'ms',
                      accent: AppColors.accentInfo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.south_rounded,
                      label: t.download,
                      value: s.downloadMbps,
                      unit: 'Mbps',
                      accent: AppColors.accentDown,
                      highlight: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.north_rounded,
                      label: t.upload,
                      value: s.uploadMbps,
                      unit: 'Mbps',
                      accent: AppColors.accentUp,
                    ),
                  ),
                ],
              ),
              if (showComfort && s.loadedPingMs != null) ...[
                const SizedBox(height: 16),
                BufferbloatCard(
                  strings: t,
                  idlePingMs: s.pingMs!,
                  loadedPingMs: s.loadedPingMs!,
                ),
              ],
              if (showComfort) ...[
                const SizedBox(height: 16),
                ResultSummary(
                  strings: t,
                  download: s.downloadMbps!,
                  upload: s.uploadMbps!,
                  ping: s.pingMs!,
                  jitter: s.jitterMs ?? 0,
                ),
                const SizedBox(height: 16),
                ComfortSection(
                  strings: t,
                  download: s.downloadMbps!,
                  upload: s.uploadMbps!,
                  ping: s.pingMs!,
                ),
                // The throttling check runs in an isolate and streams from
                // Netflix's CDN — neither is available to a browser.
                if (!kIsWeb) ...[
                  const SizedBox(height: 16),
                  const ThrottleCard(),
                ],
              ],
              if (s.phase == TestPhase.error) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: s.error ?? t.errorGeneric),
              ],
              const SizedBox(height: 28),
              _ActionButton(
                label: s.isRunning ? t.stopTest : t.startTest,
                running: s.isRunning,
                onTap: s.isRunning ? ctrl.stop : ctrl.start,
              ),
              // The browser has no tab bar: what the app keeps under Monitor
              // and More appears here instead, below the test.
              if (kIsWeb) const WebExtras(),
            ],
          ),
        ),
        Positioned.fill(child: ConfettiOverlay(controller: _confetti)),
      ],
    );
  }
}

String _phaseLabel(AppStrings t, TestPhase p) => switch (p) {
      TestPhase.idle => t.phaseIdle,
      TestPhase.ping => t.phasePing,
      TestPhase.download => t.phaseDownload,
      TestPhase.upload => t.phaseUpload,
      TestPhase.done => t.phaseDone,
      TestPhase.error => t.phaseError,
    };

// ─────────────────────────── heading ─────────────────────────────

class _Title extends StatelessWidget {
  const _Title({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nova',
                style: TextStyle(
                  color: AppColors.sun,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kIsWeb ? strings.webTagline : strings.speedtestSubtitle,
                style: TextStyle(color: AppColors.onGlass, fontSize: 14),
              ),
            ],
          ),
        ),
        const LanguageButton(),
        IconButton(
          onPressed: () => showServicePingSheet(context),
          icon: Icon(Icons.travel_explore_rounded, color: AppColors.textMid),
          tooltip: strings.servicesTitle,
        ),
        IconButton(
          onPressed: () => showLeaderboardSheet(context),
          icon: Icon(Icons.emoji_events_rounded, color: AppColors.textMid),
          tooltip: strings.lbTitle,
        ),
        IconButton(
          onPressed: () => showSpeedTestHistorySheet(context),
          icon: Icon(Icons.history_rounded, color: AppColors.textMid),
          tooltip: strings.historyTitle,
        ),
        IconButton(
          onPressed: () => showSettingsSheet(context),
          icon: Icon(Icons.tune_rounded, color: AppColors.textMid),
          tooltip: strings.settings,
        ),
      ],
    );
  }
}

// ─────────────────────── gauge centre ────────────────────────────

class _GaugeCenter extends StatelessWidget {
  const _GaugeCenter({
    required this.phaseLabel,
    required this.value,
    required this.color,
  });
  final String phaseLabel;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cross-fade the phase label.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            phaseLabel,
            key: ValueKey(phaseLabel),
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _fmtMbps(value),
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 64,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Mbps',
          style: TextStyle(
            color: AppColors.textLo,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── phase progress ──────────────────────────

class _PhaseBar extends StatelessWidget {
  const _PhaseBar({
    required this.active,
    required this.progress,
    required this.color,
  });
  final bool active;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: active ? progress.clamp(0.0, 1.0) : 0,
        minHeight: 6,
        backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

// ─────────────────────── metric card ─────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final double? value;
  final String unit;
  final Color accent;
  final bool highlight;

  static final _numStyle = TextStyle(
    color: AppColors.onGlass,
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCard(glow: highlight ? accent : null).copyWith(
        border: Border.all(
          color: accent.withValues(alpha: highlight ? 0.30 : 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                value == null
                    ? Text('—', style: _numStyle)
                    // Odometer-style digits.
                    : OdometerText(value: value!, decimals: 1, style: _numStyle),
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row showing the ISP and location, sourced from [ipInfoProvider].
class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.strings, this.serverName});
  final AppStrings strings;

  /// Server chosen by the engine (may differ if the primary was unreachable).
  final String? serverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(ipInfoProvider);
    final data = info.asData?.value;

    var text = '';
    if (info.isLoading) {
      text = strings.providerDetecting;
    } else if (data != null && data.hasIsp) {
      text = data.location.isNotEmpty
          ? '${data.isp} · ${data.location}'
          : data.isp!;
    }
    if (serverName != null) {
      final srv = '${strings.serverLabel}: $serverName';
      text = text.isEmpty ? srv : '$text · $srv';
    }
    if (text.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.onGlass.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.onGlass.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_rounded, size: 15, color: AppColors.accentDown),
            const SizedBox(width: 8),
            Text(
              '${strings.providerLabel}: ',
              style: TextStyle(color: AppColors.textLo, fontSize: 12),
            ),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textHi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── start / stop button ─────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.running,
    required this.onTap,
  });

  final String label;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 62,
        // No fill and no glow: just a thin outline on black.
        decoration: BoxDecoration(
          color: running ? AppColors.red.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: running
                ? AppColors.red.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.75),
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              running ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: running ? AppColors.red : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: running ? AppColors.red : Colors.white,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtMbps(double? v) {
  if (v == null) return '—';
  return v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
