import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/dns_test.dart';
import 'dns_provider.dart';

/// "DNS speed test": how fast the DNS server in use answers, next to the
/// public ones, and whether switching would help.
void showDnsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _DnsSheet(),
  );
}

/// Names for Android's "Private DNS" setting, which takes a host name
/// rather than an address. OpenDNS offers none.
const _privateDnsHost = {
  '1.1.1.1': 'one.one.one.one',
  '8.8.8.8': 'dns.google',
  '9.9.9.9': 'dns.quad9.net',
  '94.140.14.14': 'dns.adguard-dns.com',
};

class _DnsSheet extends ConsumerStatefulWidget {
  const _DnsSheet();

  @override
  ConsumerState<_DnsSheet> createState() => _DnsSheetState();
}

class _DnsSheetState extends ConsumerState<_DnsSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(dnsTestProvider.notifier).run);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(dnsTestProvider);
    final done = !s.running && s.results.isNotEmpty;

    // Fastest first once all are in; in the order asked while they come.
    final rows = [...s.resolvers];
    if (done) {
      double key(DnsResolver r) => s.results[r.address]?.medianMs ?? double.infinity;
      rows.sort((a, b) => key(a).compareTo(key(b)));
    }
    final slowest = s.results.values
        .map((r) => r.medianMs ?? 0)
        .fold<double>(1, (a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                      Icon(Icons.dns_rounded, color: AppColors.accentAlt),
                      const SizedBox(width: 10),
                      Text(
                        t.dnsTitle,
                        style: TextStyle(color: AppColors.onGlass, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(t.dnsIntro, style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 14),
                  for (final resolver in rows)
                    _ResolverRow(
                      resolver: resolver,
                      result: s.results[resolver.address],
                      slowest: slowest,
                      running: s.running,
                      strings: t,
                    ),
                  if (done) ...[
                    const SizedBox(height: 12),
                    _Advice(state: s, strings: t),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: s.running ? null : ref.read(dnsTestProvider.notifier).run,
                    icon: Icon(s.running ? Icons.hourglass_top_rounded : Icons.refresh_rounded, size: 20),
                    label: Text(s.running ? t.gamingRunning : t.gamingAgain),
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

class _ResolverRow extends StatelessWidget {
  const _ResolverRow({
    required this.resolver,
    required this.result,
    required this.slowest,
    required this.running,
    required this.strings,
  });
  final DnsResolver resolver;
  final DnsResult? result;
  final double slowest;
  final bool running;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final t = strings;
    final r = result;
    final ms = r?.medianMs;
    final color = ms == null
        ? AppColors.red
        : ms < 20
            ? AppColors.green
            : ms < 60
                ? AppColors.accentAlt
                : AppColors.amber;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: glassCard(radius: 16, glow: resolver.current ? AppColors.accentAlt : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: resolver.current ? t.dnsCurrent : resolver.name,
                      style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '   ${resolver.address}',
                      style: TextStyle(color: AppColors.textLo, fontSize: 12),
                    ),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (r == null)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: running ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.textLo) : null,
                )
              else
                Text(
                  ms == null ? t.gamingLost : '${ms.toStringAsFixed(ms < 10 ? 1 : 0)} ms',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (r != null && ms != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (ms / slowest).clamp(0.02, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
              ),
            ),
            if (r.answered < r.asked) ...[
              const SizedBox(height: 4),
              Text(
                AppStrings.fill(t.dnsAnswered, ['${r.answered}', '${r.asked}']),
                style: TextStyle(color: AppColors.textLo, fontSize: 11.5),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Keep it, or switch — and how.
class _Advice extends StatelessWidget {
  const _Advice({required this.state, required this.strings});
  final DnsTestState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final t = strings;
    final current = state.current;
    final best = state.bestPublic;
    final currentResult = current == null ? null : state.results[current.address];
    final bestResult = best == null ? null : state.results[best.address];
    final switching = best != null &&
        bestResult != null &&
        (currentResult == null || worthSwitching(currentResult, bestResult));

    String ms(DnsResult? r) => r?.medianMs == null ? '—' : r!.medianMs!.round().toString();
    final text = switching
        ? AppStrings.fill(t.dnsSwitch, [best.name, ms(bestResult), ms(currentResult)])
        : t.dnsKeep;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (switching ? AppColors.amber : AppColors.green).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (switching ? AppColors.amber : AppColors.green).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: AppColors.onGlass, fontSize: 13.5, height: 1.4)),
          if (switching) ...[
            const SizedBox(height: 10),
            Text(t.dnsHowTo, style: TextStyle(color: AppColors.onGlass, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _steps(t, best),
              style: TextStyle(color: AppColors.textMid, fontSize: 12.5, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  static String _steps(AppStrings t, DnsResolver best) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => AppStrings.fill(t.dnsStepsMac, [best.address]),
      TargetPlatform.windows => AppStrings.fill(t.dnsStepsWindows, [best.address]),
      TargetPlatform.android => _privateDnsHost[best.address] == null
          ? t.dnsStepsAndroidNone
          : AppStrings.fill(t.dnsStepsAndroid, [_privateDnsHost[best.address]!]),
      _ => AppStrings.fill(t.dnsStepsRouter, [best.address]),
    };
    return defaultTargetPlatform == TargetPlatform.linux
        ? platform
        : '$platform\n${AppStrings.fill(t.dnsStepsRouter, [best.address])}';
  }
}
