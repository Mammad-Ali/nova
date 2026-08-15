import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// The app's current language. Persisted to disk; defaults to Russian.
final localeProvider =
    NotifierProvider<LocaleNotifier, AppLocale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'app_locale';

  @override
  AppLocale build() {
    _load();
    return AppLocale.ru;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppLocale.fromCode(prefs.getString(_key));
    } catch (_) {
      // Storage unavailable — keep the default language.
    }
  }

  Future<void> set(AppLocale locale) async {
    if (locale == state) return;
    state = locale; // switch right away, even if persisting fails
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.name);
    } catch (_) {}
  }
}

/// Ready-made strings for the current language. Widgets do
/// `final t = ref.watch(stringsProvider);` and then read `t.someKey`.
final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings.of(ref.watch(localeProvider));
});
