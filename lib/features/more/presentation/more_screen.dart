import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../leaderboard/presentation/leaderboard_providers.dart';
import 'more_entries.dart';
import 'more_links.dart';

/// The third tab: Learn, Tools, About and Profile — the same four sections
/// the site shows in its footer.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final account = ref.watch(accountProvider);
    final version = ref.watch(appVersionProvider).asData?.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tabMore,
                      style: TextStyle(
                        color: AppColors.sun,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.moreSubtitle,
                      style: TextStyle(color: AppColors.onGlass, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const LanguageButton(),
            ],
          ),
          const SizedBox(height: 20),
          for (final section in moreSections(t)) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
              decoration: glassCard(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Text(
                      section.title.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textLo,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final entry in section.entries)
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(moreEntryIcon(entry),
                          size: 21, color: AppColors.textMid),
                      title: Text(
                        moreEntryLabel(entry, t, account),
                        style: TextStyle(color: AppColors.onGlass, fontSize: 14.5),
                      ),
                      trailing: Icon(
                        moreEntryIsLink(entry)
                            ? Icons.open_in_new_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textLo,
                      ),
                      onTap: () => openMoreEntry(context, ref, entry),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
          Text(
            [
              'Nova',
              if (version != null) '${t.versionLabel} $version',
              t.footerLicense,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLo, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
