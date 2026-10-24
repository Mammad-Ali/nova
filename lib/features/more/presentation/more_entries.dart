import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../leaderboard/domain/leaderboard_models.dart';
import '../../leaderboard/presentation/leaderboard_sheet.dart';
import '../../leaderboard/presentation/provider_ranking_sheet.dart';
import '../../leaderboard/presentation/sign_in_sheet.dart';
import '../../services_ping/presentation/service_ping_sheet.dart';
import '../../settings/settings_sheet.dart';
import '../../speedtest/presentation/widgets/history_sheet.dart';
import '../content/learn_content.dart';
import 'articles_sheet.dart';
import 'more_links.dart';

/// Everything reachable from the More tab in the app and the footer on the
/// site. Both read this one list, so they can never drift apart.
enum MoreEntry {
  glossary,
  guides,
  faq,
  leaderboard,
  ranking,
  services,
  about,
  privacy,
  source,
  history,
  settings,
  help,
  account,
}

class MoreSection {
  const MoreSection(this.title, this.entries);

  final String title;
  final List<MoreEntry> entries;
}

List<MoreSection> moreSections(AppStrings t) => [
      MoreSection(t.secLearn, const [
        MoreEntry.glossary,
        MoreEntry.guides,
        MoreEntry.faq,
      ]),
      MoreSection(t.secTools, const [
        MoreEntry.leaderboard,
        MoreEntry.ranking,
        MoreEntry.services,
      ]),
      MoreSection(t.secAbout, const [
        MoreEntry.about,
        MoreEntry.privacy,
        MoreEntry.source,
      ]),
      MoreSection(t.secProfile, const [
        MoreEntry.history,
        MoreEntry.settings,
        MoreEntry.help,
        MoreEntry.account,
      ]),
    ];

String moreEntryLabel(MoreEntry entry, AppStrings t, NovaAccount? account) =>
    switch (entry) {
      MoreEntry.glossary => t.learnGlossary,
      MoreEntry.guides => t.learnGuides,
      MoreEntry.faq => t.learnFaq,
      MoreEntry.leaderboard => t.lbTitle,
      MoreEntry.ranking => t.toolsRanking,
      MoreEntry.services => t.servicesTitle,
      MoreEntry.about => t.aboutNova,
      MoreEntry.privacy => t.aboutPrivacy,
      MoreEntry.source => t.aboutSource,
      MoreEntry.history => t.historyTitle,
      MoreEntry.settings => t.settings,
      MoreEntry.help => t.profileHelp,
      MoreEntry.account => account == null
          ? t.profileAccount
          : AppStrings.fill(t.profileSignedIn, [account.nickname]),
    };

IconData moreEntryIcon(MoreEntry entry) => switch (entry) {
      MoreEntry.glossary => Icons.menu_book_rounded,
      MoreEntry.guides => Icons.school_rounded,
      MoreEntry.faq => Icons.help_outline_rounded,
      MoreEntry.leaderboard => Icons.emoji_events_rounded,
      MoreEntry.ranking => Icons.leaderboard_rounded,
      MoreEntry.services => Icons.travel_explore_rounded,
      MoreEntry.about => Icons.info_outline_rounded,
      MoreEntry.privacy => Icons.shield_outlined,
      MoreEntry.source => Icons.code_rounded,
      MoreEntry.history => Icons.history_rounded,
      MoreEntry.settings => Icons.tune_rounded,
      MoreEntry.help => Icons.support_rounded,
      MoreEntry.account => Icons.account_circle_outlined,
    };

/// Whether the entry leaves the app (opens a web page) rather than a sheet.
bool moreEntryIsLink(MoreEntry entry) => entry == MoreEntry.source;

void openMoreEntry(BuildContext context, WidgetRef ref, MoreEntry entry) {
  final t = ref.read(stringsProvider);
  final content = learnContentFor(ref.read(localeProvider));

  switch (entry) {
    case MoreEntry.glossary:
      showArticlesSheet(context, title: t.learnGlossary, articles: content.glossary);
    case MoreEntry.guides:
      showArticlesSheet(context, title: t.learnGuides, articles: content.guides);
    case MoreEntry.faq:
      showArticlesSheet(context, title: t.learnFaq, articles: content.faq);
    case MoreEntry.leaderboard:
      showLeaderboardSheet(context);
    case MoreEntry.ranking:
      showProviderRankingSheet(context);
    case MoreEntry.services:
      showServicePingSheet(context);
    case MoreEntry.about:
      showAboutSheet(context);
    case MoreEntry.privacy:
      showArticlesSheet(context, title: t.aboutPrivacy, articles: content.privacy);
    case MoreEntry.source:
      openLink(kRepoUrl);
    case MoreEntry.history:
      showSpeedTestHistorySheet(context);
    case MoreEntry.settings:
      showSettingsSheet(context);
    case MoreEntry.help:
      showArticlesSheet(
        context,
        title: t.profileHelp,
        articles: content.help,
        actionLabel: content.reportButton,
        actionUrl: kIssuesUrl,
      );
    case MoreEntry.account:
      showSignInSheet(context);
  }
}
