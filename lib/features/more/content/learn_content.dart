import '../../../core/l10n/app_strings.dart';
import 'learn_az.dart';
import 'learn_de.dart';
import 'learn_en.dart';
import 'learn_hu.dart';
import 'learn_ru.dart';

/// One titled entry: a glossary term, a guide, a question with its answer.
class Article {
  const Article(this.title, this.body);

  final String title;
  final String body;
}

/// The long-form pages behind the Learn, About and Help entries, in one
/// language.
///
/// Kept apart from AppStrings on purpose: these are paragraphs, not labels,
/// and a translator reads them as a document rather than as a list of keys.
/// Every language must carry the same entries in the same order — a test
/// checks it.
class LearnContent {
  const LearnContent({
    required this.glossary,
    required this.guides,
    required this.faq,
    required this.about,
    required this.privacy,
    required this.help,
    required this.reportButton,
  });

  final List<Article> glossary;
  final List<Article> guides;
  final List<Article> faq;

  /// One paragraph: what Nova is.
  final String about;
  final List<Article> privacy;
  final List<Article> help;

  /// Label of the button under Help that opens the GitHub issue page.
  final String reportButton;
}

LearnContent learnContentFor(AppLocale locale) => switch (locale) {
      AppLocale.en => learnEn,
      AppLocale.az => learnAz,
      AppLocale.ru => learnRu,
      AppLocale.de => learnDe,
      AppLocale.hu => learnHu,
    };
