import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../leaderboard/presentation/leaderboard_providers.dart';
import 'more_entries.dart';
import 'more_links.dart';

/// The lower half of the web page: what only the app can do, where to get
/// it, and the footer with the same four sections as the app's More tab.
class WebExtras extends StatefulWidget {
  const WebExtras({super.key});

  @override
  State<WebExtras> createState() => _WebExtrasState();
}

class _WebExtrasState extends State<WebExtras> {
  final _downloads = GlobalKey();

  void _scrollToDownloads() {
    final target = _downloads.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        _AppOnly(onGetApp: _scrollToDownloads),
        const SizedBox(height: 28),
        _GetTheApp(key: _downloads),
        const SizedBox(height: 40),
        const _Footer(),
      ],
    );
  }
}

// ─────────────────────────── only in the app ───────────────────────────

class _AppOnly extends ConsumerWidget {
  const _AppOnly({required this.onGetApp});

  final VoidCallback onGetApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final features = [
      (Icons.show_chart_rounded, t.appOnlyMonitorTitle, t.appOnlyMonitorText),
      (Icons.devices_rounded, t.lanTitle, t.appOnlyLanText),
      (Icons.wifi_rounded, t.appOnlyWifiTitle, t.appOnlyWifiText),
      (Icons.ondemand_video_rounded, t.throttleTitle, t.appOnlyThrottleText),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.appOnlyTitle,
          style: TextStyle(
            color: AppColors.sun,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.webOnlyHere,
          style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            // Two cards per row once there is room; one on a phone.
            final columns = box.maxWidth >= 520 ? 2 : 1;
            const gap = 12.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (icon, title, text) in features)
                  SizedBox(
                    width: width,
                    child: _FeatureCard(
                      icon: icon,
                      title: title,
                      text: text,
                      action: t.getApp,
                      onAction: onGetApp,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: glassCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.onGlass),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(color: AppColors.textMid, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentAlt,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
            ),
            child: Text('$action  →'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── downloads ─────────────────────────────

class _GetTheApp extends ConsumerWidget {
  const _GetTheApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mine = visitorDownload();
    final others = [
      for (final target in DownloadTarget.values)
        if (target != mine) target,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: glassCard(radius: 22, glow: AppColors.sun),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.getAppTitle,
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.getAppHint,
            style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (mine != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => startDownload(mine),
                icon: Icon(mine.icon, size: 20),
                label: Text(AppStrings.fill(t.getAppFor, [mine.label])),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.getAppOther,
              style: TextStyle(color: AppColors.textLo, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final target in others)
                OutlinedButton.icon(
                  onPressed: () => startDownload(target),
                  icon: Icon(target.icon, size: 18),
                  label: Text(target.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onGlass,
                    side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.25)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => openLink(kReleasesUrl),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentAlt,
              padding: EdgeInsets.zero,
            ),
            child: Text('${t.getAppAll}  →'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── footer ───────────────────────────────

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final account = ref.watch(accountProvider);
    final version = ref.watch(appVersionProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: AppColors.onGlass.withValues(alpha: 0.12), height: 1),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            // Four columns on a wide screen, two on a phone. The gap is kept
            // tight because a column is only ~140 px wide, and single long
            // words ("Конфиденциальность") must still fit on one line.
            final columns = box.maxWidth >= 560 ? 4 : 2;
            const gap = 10.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 24,
              children: [
                for (final section in moreSections(t))
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            color: AppColors.onGlass,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final entry in section.entries)
                          InkWell(
                            onTap: () => openMoreEntry(context, ref, entry),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                moreEntryLabel(entry, t, account),
                                style: TextStyle(color: AppColors.textMid, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          [
            '© 2026 Nova',
            if (version != null) '${t.versionLabel} $version',
            t.footerLicense,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textLo, fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
