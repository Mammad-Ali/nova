import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/core/l10n/app_strings.dart';
import 'package:net_pulse/features/more/content/learn_content.dart';

void main() {
  group('languages', () {
    test('every language round-trips through its stored code', () {
      for (final locale in AppLocale.values) {
        expect(AppLocale.fromCode(locale.name), locale);
        expect(locale.nativeName, isNotEmpty);
      }
    });

    test('every translation keeps the placeholders it is filled with', () {
      // A missing {0} would print the template text instead of the number.
      for (final locale in AppLocale.values) {
        final t = AppStrings.of(locale);
        final templates = {
          'alertSlowBody': (t.alertSlowBody, 2),
          'alertLimitBody': (t.alertLimitBody, 2),
          'getAppFor': (t.getAppFor, 1),
          'profileSignedIn': (t.profileSignedIn, 1),
        };
        for (final MapEntry(key: name, value: (text, count)) in templates.entries) {
          for (var i = 0; i < count; i++) {
            expect(text, contains('{$i}'), reason: '${locale.name}.$name lacks {$i}');
          }
        }
      }
    });

    test('fill replaces every placeholder', () {
      final t = AppStrings.of(AppLocale.hu);
      final text = AppStrings.fill(t.alertSlowBody, ['12', '50']);
      expect(text, isNot(contains('{')));
      expect(text, allOf(contains('12'), contains('50')));
    });
  });

  group('long-form pages', () {
    final english = learnContentFor(AppLocale.en);

    test('every language has the same entries as English', () {
      for (final locale in AppLocale.values) {
        final c = learnContentFor(locale);
        final why = 'in ${locale.name}';
        expect(c.glossary.length, english.glossary.length, reason: why);
        expect(c.guides.length, english.guides.length, reason: why);
        expect(c.faq.length, english.faq.length, reason: why);
        expect(c.privacy.length, english.privacy.length, reason: why);
        expect(c.help.length, english.help.length, reason: why);
      }
    });

    test('no entry is left blank', () {
      for (final locale in AppLocale.values) {
        final c = learnContentFor(locale);
        expect(c.about.trim(), isNotEmpty);
        expect(c.reportButton.trim(), isNotEmpty);
        for (final a in [...c.glossary, ...c.guides, ...c.faq, ...c.privacy, ...c.help]) {
          expect(a.title.trim(), isNotEmpty, reason: locale.name);
          expect(a.body.trim(), isNotEmpty, reason: '${locale.name}: ${a.title}');
        }
      }
    });
  });
}
