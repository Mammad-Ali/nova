import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../more/presentation/articles_sheet.dart';
import '../../speedtest/data/datasources/ip_info.dart';
import '../domain/leaderboard_models.dart';
import '../domain/provider_ranking.dart';
import 'leaderboard_providers.dart';

/// Providers in the visitor's country, ranked — built from the leaderboard.
final providerRankingProvider =
    FutureProvider.autoDispose<(String?, List<ProviderStat>)>((ref) async {
  final info = await ref.watch(ipInfoProvider.future);
  final entries = await ref.watch(leaderboardRepositoryProvider).top(
        scope: LeaderboardScope.country,
        metric: LeaderboardMetric.download,
        country: info.country,
        provider: info.isp,
      );
  return (info.country, rankProviders(entries));
});

void showProviderRankingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _RankingSheet(),
  );
}

class _RankingSheet extends ConsumerWidget {
  const _RankingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final ranking = ref.watch(providerRankingProvider);
    final (country, stats) = ranking.asData?.value ?? (null, const <ProviderStat>[]);

    return SheetFrame(
      title: country == null ? t.toolsRanking : '${t.toolsRanking} · $country',
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              t.rankHint,
              style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4),
            ),
          ),
          if (ranking.isLoading)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentAlt),
              ),
            )
          else if (stats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                t.rankEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < stats.length; i++)
              _Row(place: i + 1, stat: stats[i], strings: t),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: AppColors.amber),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    t.lbDemoNotice,
                    style: TextStyle(color: AppColors.amber, fontSize: 10.5, height: 1.4),
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

class _Row extends StatelessWidget {
  const _Row({required this.place, required this.stat, required this.strings});

  final int place;
  final ProviderStat stat;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: glassCard(radius: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: place == 1 ? AppColors.sun : AppColors.textLo,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${strings.rankResults}: ${stat.results} · '
                  '${strings.ping} ${stat.pingMs.toStringAsFixed(0)} ms',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${stat.downloadMbps.toStringAsFixed(1)} Mbps',
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
