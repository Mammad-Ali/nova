import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/core/l10n/app_strings.dart';
import 'package:net_pulse/features/widgets/widget_bridge.dart';

/// The Mac widgets (Swift) ask for their words by key; the app (Dart)
/// supplies them. A key missing on the Dart side would quietly fall back to
/// English, so this keeps the two lists in step.
void main() {
  test('every label the widgets use is supplied in every language', () {
    final swift = File('macos/NovaWidgets/NovaWidgets.swift').readAsStringSync();
    final used = RegExp(r'label\("(\w+)"').allMatches(swift).map((m) => m[1]!).toSet();
    expect(used, isNotEmpty);

    for (final locale in AppLocale.values) {
      final labels = widgetLabels(AppStrings.of(locale));
      expect(labels.keys.toSet(), containsAll(used), reason: '$locale');
      expect(labels.values.where((v) => v.trim().isEmpty), isEmpty, reason: '$locale');
    }
  });
}
