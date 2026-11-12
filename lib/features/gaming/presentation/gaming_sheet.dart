import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/gaming.dart';
import 'gaming_provider.dart';

/// "Gaming check": ping, jitter and loss to the data centres online games
/// run in, and which of them suits fast games.
void showGamingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _GamingSheet(),
  );
}

class _GamingSheet extends ConsumerStatefulWidget {
  const _GamingSheet();

  @override
  ConsumerState<_GamingSheet> createState() => _GamingSheetState();
}

class _GamingSheetState extends ConsumerState<_GamingSheet> {
  @override
  void initState() {
    super.initState();
    // Opening it is the request, as with the device scan.
    Future.microtask(ref.read(gamingCheckProvider.notifier).run);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(gamingCheckProvider);
    final best = s.best;

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
                      Icon(Icons.sports_esports_rounded, color: AppColors.green),
                      const SizedBox(width: 10),
                      Text(
                        t.gamingTitle,
                        style: TextStyle(color: AppColors.onGlass, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb ? '${t.gamingIntro} ${t.gamingWebNote}' : t.gamingIntro,
                    style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  for (final region in gameRegions)
                    _RegionRow(
                      region: region,
                      result: s.results[region.id],
                      best: region.id == best && !s.running,
                      running: s.running,
                      strings: t,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: s.running ? null : ref.read(gamingCheckProvider.notifier).run,
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

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.region,
    required this.result,
    required this.best,
    required this.running,
    required this.strings,
  });
  final GameRegion region;
  final RegionResult? result;
  final bool best;
  final bool running;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final t = strings;
    final r = result;
    final verdict = r?.verdict;
    final color = verdictColor(verdict);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: glassCard(radius: 16, glow: best ? AppColors.green : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        gamingCity(region.id, t),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.onGlass, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (best) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.gamingBest,
                          style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                if (region.games.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.fill(t.gamingGames, [region.games.join(', ')]),
                    style: TextStyle(color: AppColors.textLo, fontSize: 12),
                  ),
                ],
                if (verdict != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    gamingVerdictLabel(verdict, t),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (r == null)
            SizedBox(
              width: 16,
              height: 16,
              child: running ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.textLo) : null,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  r.pingMs == null ? '—' : '${r.pingMs!.round()} ms',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (r.jitterMs != null)
                  Text(
                    AppStrings.fill(t.gamingJitter, ['${r.jitterMs!.round()}']) +
                        (r.lossPercent > 0
                            ? ' · ${AppStrings.fill(t.gamingLoss, [r.lossPercent.toStringAsFixed(0)])}'
                            : ''),
                    style: TextStyle(color: AppColors.textLo, fontSize: 11.5),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Color verdictColor(GamingVerdict? verdict) => switch (verdict) {
      GamingVerdict.great => AppColors.green,
      GamingVerdict.good => AppColors.accentAlt,
      GamingVerdict.slow => AppColors.amber,
      GamingVerdict.far || GamingVerdict.lost => AppColors.red,
      null => AppColors.textMid,
    };

String gamingVerdictLabel(GamingVerdict verdict, AppStrings t) => switch (verdict) {
      GamingVerdict.great => t.gamingGreat,
      GamingVerdict.good => t.gamingGood,
      GamingVerdict.slow => t.gamingSlow,
      GamingVerdict.far => t.gamingFar,
      GamingVerdict.lost => t.gamingLost,
    };

String gamingCity(String id, AppStrings t) => switch (id) {
      'frankfurt' => t.gamingCityFrankfurt,
      'stockholm' => t.gamingCityStockholm,
      'london' => t.gamingCityLondon,
      'paris' => t.gamingCityParis,
      'telAviv' => t.gamingCityTelAviv,
      'uae' => t.gamingCityUae,
      'mumbai' => t.gamingCityMumbai,
      _ => id,
    };
