import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Текущий язык приложения. Сохраняется на диск, по умолчанию — русский.
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
      // Хранилище недоступно — остаёмся на языке по умолчанию.
    }
  }

  Future<void> set(AppLocale locale) async {
    if (locale == state) return;
    state = locale; // переключаем сразу, даже если сохранить не удастся
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.name);
    } catch (_) {}
  }
}

/// Готовый набор строк для текущего языка. Виджеты делают
/// `final t = ref.watch(stringsProvider);` и берут `t.someKey`.
final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings.of(ref.watch(localeProvider));
});
