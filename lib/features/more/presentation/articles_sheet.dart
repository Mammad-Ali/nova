import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../content/learn_content.dart';
import 'more_links.dart';

/// A page of titled paragraphs: glossary, guides, FAQ, privacy, help.
void showArticlesSheet(
  BuildContext context, {
  required String title,
  String? intro,
  List<Article> articles = const [],
  String? actionLabel,
  String? actionUrl,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SheetFrame(
      title: title,
      child: _Articles(
        intro: intro,
        articles: articles,
        actionLabel: actionLabel,
        actionUrl: actionUrl,
      ),
    ),
  );
}

/// What Nova is, which version is running, and where the code lives.
void showAboutSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AboutSheet(),
  );
}

class _AboutSheet extends ConsumerWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final content = learnContentFor(ref.watch(localeProvider));
    final version = ref.watch(appVersionProvider).asData?.value;

    return SheetFrame(
      title: t.aboutNova,
      child: _Articles(
        intro: content.about,
        footnote: [
          if (version != null) '${t.versionLabel} $version',
          t.footerLicense,
        ].join(' · '),
        actionLabel: t.aboutSource,
        actionUrl: kRepoUrl,
      ),
    );
  }
}

/// The frame every Nova sheet uses: black, rounded top, drag handle, title.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Flexible(child: child),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Articles extends StatelessWidget {
  const _Articles({
    this.intro,
    this.articles = const [],
    this.footnote,
    this.actionLabel,
    this.actionUrl,
  });

  final String? intro;
  final List<Article> articles;
  final String? footnote;
  final String? actionLabel;
  final String? actionUrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (intro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              intro!,
              style: TextStyle(color: AppColors.textMid, fontSize: 14, height: 1.5),
            ),
          ),
        for (final a in articles)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: glassCard(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.body,
                  style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        if (actionLabel != null && actionUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () => openLink(actionUrl!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(actionLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onGlass,
                side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              footnote!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLo, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
