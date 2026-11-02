import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/diagnosis.dart';
import 'diagnosis_provider.dart';

/// Opens "Find the cause".
///
/// With [start], the check begins right away — how the Mac widgets open it.
void showDiagnosisSheet(BuildContext context, {bool start = false}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DiagnosisSheet(start: start),
  );
}

class _DiagnosisSheet extends ConsumerStatefulWidget {
  const _DiagnosisSheet({required this.start});

  final bool start;

  @override
  ConsumerState<_DiagnosisSheet> createState() => _DiagnosisSheetState();
}

class _DiagnosisSheetState extends ConsumerState<_DiagnosisSheet> {
  @override
  void initState() {
    super.initState();
    // After the first frame, once the sheet is watching the check.
    if (widget.start) Future.microtask(ref.read(diagnosisProvider.notifier).run);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(diagnosisProvider);
    final started = s.running || s.findings.isNotEmpty;

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
                      Icon(Icons.troubleshoot_rounded, color: AppColors.accentAlt),
                      const SizedBox(width: 10),
                      Text(
                        t.diagTitle,
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
                    t.diagHint,
                    style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4),
                  ),
                  if (started) ...[
                    const SizedBox(height: 18),
                    _ChainStart(label: t.diagThisDevice),
                    for (final step in DiagnosisStep.values)
                      _ChainLink(
                        step: step,
                        finding: s.findings[step],
                        measuring: s.current == step,
                        last: step == DiagnosisStep.values.last,
                      ),
                  ],
                  if (s.done) ...[
                    const SizedBox(height: 16),
                    _Verdict(findings: s.findings),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: s.running ? null : ref.read(diagnosisProvider.notifier).run,
                    icon: Icon(
                      s.running ? Icons.hourglass_top_rounded : Icons.troubleshoot_rounded,
                      size: 20,
                    ),
                    label: Text(
                      s.running ? t.diagChecking : (s.done ? t.callCheckAgain : t.diagStart),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _healthColor(LinkHealth? health) => switch (health) {
      LinkHealth.good => AppColors.green,
      LinkHealth.fair => AppColors.amber,
      LinkHealth.bad => AppColors.red,
      LinkHealth.skipped || null => AppColors.textLo,
    };

/// The chain's first node: where everything starts.
class _ChainStart extends StatelessWidget {
  const _ChainStart({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Node(icon: Icons.devices_rounded, color: AppColors.onGlass),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: AppColors.textMid, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// One link: the line from the previous node, its icon, its name, what was
/// measured and how that looks.
class _ChainLink extends ConsumerWidget {
  const _ChainLink({
    required this.step,
    required this.finding,
    required this.measuring,
    required this.last,
  });

  final DiagnosisStep step;
  final LinkFinding? finding;
  final bool measuring;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final color = _healthColor(finding?.health);
    final (icon, label) = switch (step) {
      DiagnosisStep.wifi => (Icons.wifi_rounded, t.diagStepWifi),
      DiagnosisStep.router => (Icons.router_rounded, t.diagStepRouter),
      DiagnosisStep.dns => (Icons.dns_rounded, t.diagStepDns),
      DiagnosisStep.internet => (Icons.public_rounded, t.diagStepInternet),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The connector, coloured by the link it leads to.
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Container(
            width: 2,
            height: 18,
            color: (finding == null ? AppColors.onGlass : color).withValues(alpha: 0.35),
          ),
        ),
        Row(
          children: [
            _Node(icon: icon, color: finding == null && !measuring ? AppColors.textLo : color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (finding != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _detail(t, step, finding!),
                      style: TextStyle(color: AppColors.textMid, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: measuring
                  ? Padding(
                      padding: const EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentAlt),
                    )
                  : finding == null
                      ? null
                      : Icon(
                          switch (finding!.health) {
                            LinkHealth.good => Icons.check_circle_rounded,
                            LinkHealth.fair => Icons.error_outline_rounded,
                            LinkHealth.bad => Icons.cancel_rounded,
                            LinkHealth.skipped => Icons.remove_circle_outline_rounded,
                          },
                          size: 22,
                          color: color,
                        ),
            ),
          ],
        ),
      ],
    );
  }

  /// What was measured, in a few words: "−58 dBm · strong", "192.168.1.1 ·
  /// 4 ms", "28 ms · 0% lost".
  String _detail(AppStrings t, DiagnosisStep step, LinkFinding f) {
    String ms(double v) => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ms';
    String lost(double v) => AppStrings.fill(t.diagLost, [v.toStringAsFixed(0)]);

    switch (step) {
      case DiagnosisStep.wifi:
        if (f.rssi == null) return t.diagNotWifi;
        final word = switch (f.health) {
          LinkHealth.good => t.diagSignalStrong,
          LinkHealth.fair => t.diagSignalFair,
          _ => t.diagSignalWeak,
        };
        return '${f.rssi} dBm · $word';
      case DiagnosisStep.router:
        if (f.address == null) return t.diagRouterHidden;
        if (f.latencyMs == null) return '${f.address} · ${t.servicesUnreachable}';
        return [
          f.address!,
          ms(f.latencyMs!),
          if ((f.lossPercent ?? 0) > 0) lost(f.lossPercent!),
        ].join(' · ');
      case DiagnosisStep.dns:
        if (f.latencyMs == null) return t.servicesUnreachable;
        return [
          ms(f.latencyMs!),
          if ((f.lossPercent ?? 0) > 0) lost(f.lossPercent!),
        ].join(' · ');
      case DiagnosisStep.internet:
        if (f.latencyMs == null) return t.servicesUnreachable;
        return '${ms(f.latencyMs!)} · ${lost(f.lossPercent ?? 0)}';
    }
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// The answer, in words a person can act on.
class _Verdict extends ConsumerWidget {
  const _Verdict({required this.findings});
  final Map<DiagnosisStep, LinkFinding> findings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final (:cause, :serious) = findCause(findings);
    final color = cause == Cause.none
        ? AppColors.green
        : serious
            ? AppColors.red
            : AppColors.amber;
    final (title, body) = switch (cause) {
      Cause.wifi => (t.diagCauseWifiTitle, t.diagCauseWifiBody),
      Cause.router => (t.diagCauseRouterTitle, t.diagCauseRouterBody),
      Cause.dns => (t.diagCauseDnsTitle, t.diagCauseDnsBody),
      Cause.provider => (t.diagCauseProviderTitle, t.diagCauseProviderBody),
      Cause.offline => (t.diagCauseOfflineTitle, t.diagCauseOfflineBody),
      Cause.none => (t.diagCauseNoneTitle, t.diagCauseNoneBody),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCard(radius: 18, glow: color).copyWith(
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cause == Cause.none ? Icons.verified_rounded : Icons.report_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (cause != Cause.none && !serious)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.diagMinor,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
