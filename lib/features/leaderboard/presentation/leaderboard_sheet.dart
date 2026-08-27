import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/leaderboard_models.dart';
import 'leaderboard_providers.dart';
import 'sign_in_sheet.dart';

/// Opens the speed leaderboard.
void showLeaderboardSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LeaderboardSheet(),
  );
}

class _LeaderboardSheet extends ConsumerWidget {
  const _LeaderboardSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(leaderboardProvider);
    final account = ref.watch(accountProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onGlass.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.lbTitle,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (s.loading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentAlt,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: ref
                            .read(leaderboardProvider.notifier)
                            .refresh,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: AppColors.textMid,
                        ),
                      ),
                  ],
                ),
              ),
              _AccountRow(strings: t, account: account),
              const SizedBox(height: 10),
              _ScopeTabs(strings: t, scope: s.scope),
              const SizedBox(height: 10),
              _MetricChips(strings: t, metric: s.metric),
              const SizedBox(height: 6),
              Flexible(
                child: _Table(state: s, strings: t),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        t.lbDemoNotice,
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.strings, required this.account});
  final AppStrings strings;
  final NovaAccount? account;

  @override
  Widget build(BuildContext context) {
    final signedIn = account != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => showSignInSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: glassCard(radius: 14),
          child: Row(
            children: [
              Icon(
                signedIn
                    ? Icons.account_circle_rounded
                    : Icons.person_outline_rounded,
                size: 20,
                color: signedIn ? AppColors.sun : AppColors.textLo,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  signedIn ? account!.nickname : strings.lbGuestHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: signedIn ? AppColors.onGlass : AppColors.textLo,
                    fontSize: signedIn ? 14 : 12,
                    fontWeight: signedIn ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                signedIn ? strings.settings : strings.lbSignInGoogle,
                style: TextStyle(
                  color: AppColors.accentAlt,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeTabs extends ConsumerWidget {
  const _ScopeTabs({required this.strings, required this.scope});
  final AppStrings strings;
  final LeaderboardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = {
      LeaderboardScope.world: strings.lbScopeWorld,
      LeaderboardScope.country: strings.lbScopeCountry,
      LeaderboardScope.provider: strings.lbScopeProvider,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.onGlass.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            for (final entry in labels.entries)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(leaderboardProvider.notifier)
                      .setScope(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: entry.key == scope ? Colors.white : null,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: entry.key == scope
                            ? Colors.black
                            : AppColors.textLo,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricChips extends ConsumerWidget {
  const _MetricChips({required this.strings, required this.metric});
  final AppStrings strings;
  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = {
      LeaderboardMetric.download: strings.download,
      LeaderboardMetric.upload: strings.upload,
      LeaderboardMetric.ping: strings.ping,
    };
    final colors = {
      LeaderboardMetric.download: AppColors.accentDown,
      LeaderboardMetric.upload: AppColors.accentUp,
      LeaderboardMetric.ping: AppColors.green,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            GestureDetector(
              onTap: () =>
                  ref.read(leaderboardProvider.notifier).setMetric(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: entry.key == metric
                      ? colors[entry.key]!.withValues(alpha: 0.16)
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: entry.key == metric
                        ? colors[entry.key]!.withValues(alpha: 0.45)
                        : AppColors.onGlass.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: entry.key == metric
                        ? colors[entry.key]
                        : AppColors.textLo,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state, required this.strings});
  final LeaderboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(36),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentAlt),
        ),
      );
    }
    if (state.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
        child: Text(
          strings.lbEmptyScope,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textLo, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      itemCount: state.entries.length,
      itemBuilder: (_, i) => _Row(
        place: i + 1,
        entry: state.entries[i],
        metric: state.metric,
        youLabel: strings.lbYou,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.entry,
    required this.metric,
    required this.youLabel,
  });

  final int place;
  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    final mine = entry.isMe;
    final accent = place == 1 ? AppColors.sun : AppColors.textLo;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.accentAlt.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mine
              ? AppColors.accentAlt.withValues(alpha: 0.40)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$place',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· $youLabel',
                        style: TextStyle(
                          color: AppColors.accentAlt,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.country} · ${entry.provider}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textLo, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _value(entry, metric),
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

String _value(LeaderboardEntry e, LeaderboardMetric metric) => switch (metric) {
  LeaderboardMetric.download => '${e.downloadMbps.toStringAsFixed(1)} Mbps',
  LeaderboardMetric.upload => '${e.uploadMbps.toStringAsFixed(1)} Mbps',
  LeaderboardMetric.ping => '${e.pingMs.toStringAsFixed(0)} ms',
};
