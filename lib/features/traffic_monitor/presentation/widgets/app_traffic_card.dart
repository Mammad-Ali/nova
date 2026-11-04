import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/byte_format.dart';
import '../../domain/entities/app_traffic.dart';
import '../providers/app_traffic_provider.dart';

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

    final live = s.mode == AppTrafficMode.live;
    final shown = _expanded ? s.apps : s.apps.take(_collapsed).toList();
    final largest = s.apps.isEmpty ? 1 : s.apps.first.total;

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
          Text(
            live ? t.appsHintLive : t.appsHintToday,
            style: TextStyle(color: AppColors.textLo, fontSize: 12),
          ),
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
              child: Text(t.appsNone, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            )
          else ...[
            for (final app in shown)
              _AppRow(app: app, largest: largest, live: live, strings: t),
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
    required this.strings,
  });
  final AppTraffic app;
  final int largest;
  final bool live;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final name = switch (app.kind) {
      AppTrafficKind.app => app.name,
      AppTrafficKind.system => live ? strings.appsSystemMac : strings.appsSystemAndroid,
      AppTrafficKind.removed => strings.appsRemoved,
      AppTrafficKind.hotspot => strings.appsHotspot,
    };
    final color = _colorFor(app);
    final share = largest == 0 ? 0.0 : (app.total / largest).clamp(0.0, 1.0);
    // Below 1 KB/s is background chatter, not worth a number.
    final moving = live && app.rate >= 1024;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Badge(app: app, name: name, color: color),
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
    );
  }
}

/// A letter in a colored square for apps; an icon for the rest.
class _Badge extends StatelessWidget {
  const _Badge({required this.app, required this.name, required this.color});
  final AppTraffic app;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (app.kind) {
      AppTrafficKind.app => null,
      AppTrafficKind.system => Icons.settings_rounded,
      AppTrafficKind.removed => Icons.delete_outline_rounded,
      AppTrafficKind.hotspot => Icons.wifi_tethering_rounded,
    };
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: icon != null
          ? Icon(icon, size: 17, color: color)
          : Text(
              letter,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
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

/// The same color for an app every time: picked from its name.
Color _colorFor(AppTraffic app) {
  if (app.kind != AppTrafficKind.app) return AppColors.textMid;
  const palette = [
    AppColors.accentDown,
    AppColors.accentUp,
    AppColors.accentAlt,
    AppColors.green,
    AppColors.amber,
    AppColors.red,
    AppColors.sun,
    AppColors.nebulaViolet,
  ];
  var hash = 0;
  for (final unit in app.name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
