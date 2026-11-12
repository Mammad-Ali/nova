import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/byte_format.dart';
import '../../domain/entities/app_traffic.dart';
import '../providers/app_traffic_provider.dart';
import '../providers/app_usage_tracker.dart';
import 'app_badge.dart';
import 'app_detail_sheet.dart';

/// "Apps using the network": who took how much, and on the Mac who is
/// taking it right now. Not shown where the system doesn't say (Windows,
/// the browser).
class AppTrafficCard extends ConsumerStatefulWidget {
  const AppTrafficCard({super.key, required this.strings});
  final AppStrings strings;

  @override
  ConsumerState<AppTrafficCard> createState() => _AppTrafficCardState();
}

class _AppTrafficCardState extends ConsumerState<AppTrafficCard> {
  static const _collapsed = 6;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    final s = ref.watch(appTrafficProvider);
    if (s.mode == AppTrafficMode.unavailable) return const SizedBox.shrink();

    final mac = s.mode == AppTrafficMode.mac;
    final live = s.period == AppPeriod.now;
    final limits = ref.watch(appLimitsProvider);
    // Limits are per day: a 7-day total says nothing about them.
    final limitsApply = s.period == AppPeriod.today;
    final shown = _expanded ? s.apps : s.apps.take(_collapsed).toList();
    final largest = s.apps.isEmpty ? 1 : s.apps.first.total;
    final hint = switch ((mac, s.period)) {
      (true, AppPeriod.now) => t.appsHintLive,
      (true, _) => t.appsHintCounted,
      (false, AppPeriod.week) => t.appsHintWeek,
      (false, _) => t.appsHintToday,
    };

    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apps_rounded, size: 18, color: AppColors.accentAlt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.appsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 10),
          _PeriodPicker(
            periods: s.periods,
            selected: s.period,
            strings: t,
            onSelect: ref.read(appTrafficProvider.notifier).setPeriod,
          ),
          const SizedBox(height: 8),
          Text(hint, style: TextStyle(color: AppColors.textLo, fontSize: 12)),
          const SizedBox(height: 10),
          if (s.needsAccess)
            _AccessRequest(
              strings: t,
              onAllow: ref.read(appTrafficProvider.notifier).openAccessSettings,
            )
          else if (!s.loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (s.apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                mac && !live ? t.appsNoHistory : t.appsNone,
                style: TextStyle(color: AppColors.textMid, fontSize: 13),
              ),
            )
          else ...[
            for (final app in shown)
              _AppRow(
                app: app,
                largest: largest,
                live: live,
                mac: mac,
                overLimit: limitsApply && limits[app.key] != null && app.total >= limits[app.key]!,
                strings: t,
                onTap: () => showAppDetailSheet(context, app: app, strings: t),
              ),
            if (s.apps.length > _collapsed)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? t.appsShowLess
                        : AppStrings.fill(t.appsShowAll, ['${s.apps.length}']),
                    style: TextStyle(color: AppColors.accentAlt, fontSize: 13),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: card);
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.largest,
    required this.live,
    required this.mac,
    required this.overLimit,
    required this.strings,
    required this.onTap,
  });
  final AppTraffic app;
  final int largest;
  final bool live;
  final bool mac;
  final bool overLimit;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = appDisplayName(app, strings, mac: mac);
    final color = overLimit ? AppColors.red : appColor(app);
    final share = largest == 0 ? 0.0 : (app.total / largest).clamp(0.0, 1.0);
    // Below 1 KB/s is background chatter, not worth a number.
    final moving = live && app.rate >= 1024;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AppBadge(app: app, name: name, color: appColor(app)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (overLimit) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          strings.appsOverLimit,
                          style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (moving) ...[
                      _Rate(icon: Icons.south_rounded, bytesPerSec: app.rateIn, color: AppColors.accentDown),
                      const SizedBox(width: 8),
                      _Rate(icon: Icons.north_rounded, bytesPerSec: app.rateOut, color: AppColors.accentUp),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      formatBytes(app.total).toString(),
                      style: TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.icon, required this.bytesPerSec, required this.color});
  final IconData icon;
  final double bytesPerSec;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          Text(
            formatRate(bytesPerSec).toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}

class _AccessRequest extends StatelessWidget {
  const _AccessRequest({required this.strings, required this.onAllow});
  final AppStrings strings;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.appsAccess, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAllow, child: Text(strings.appsAllow)),
          ],
        ),
      );
}

/// Now · Today · 7 days.
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({
    required this.periods,
    required this.selected,
    required this.strings,
    required this.onSelect,
  });
  final List<AppPeriod> periods;
  final AppPeriod selected;
  final AppStrings strings;
  final ValueChanged<AppPeriod> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        children: [
          for (final period in periods)
            ChoiceChip(
              label: Text(switch (period) {
                AppPeriod.now => strings.appsPeriodNow,
                AppPeriod.today => strings.appsPeriodToday,
                AppPeriod.week => strings.appsPeriodWeek,
              }),
              selected: period == selected,
              onSelected: (_) => onSelect(period),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: period == selected ? Colors.black : AppColors.onGlass,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: Colors.white,
              backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
              side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.14)),
            ),
        ],
      );
}
