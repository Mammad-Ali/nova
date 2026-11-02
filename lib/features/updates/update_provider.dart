import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../more/presentation/more_links.dart';
import 'update_check.dart';

/// A newer release than the one running, or null. Drives the banner on the
/// speed test screen.
final updateProvider =
    NotifierProvider<UpdateNotifier, AvailableUpdate?>(UpdateNotifier.new);

/// Checks GitHub a few seconds after launch and then every six hours — the
/// app often runs for days from the menu bar or tray. The website is always
/// the newest version, so it never checks.
class UpdateNotifier extends Notifier<AvailableUpdate?> {
  /// The version whose banner was closed: it stays closed until a newer one.
  static const _dismissedKey = 'update_dismissed';

  /// The version a system notification was already shown for.
  static const _notifiedKey = 'update_notified';

  static const _firstCheck = Duration(seconds: 8);
  static const _interval = Duration(hours: 6);

  Timer? _timer;

  @override
  AvailableUpdate? build() {
    if (kIsWeb) return null;
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer(_firstCheck, _check);
    return null;
  }

  Future<void> _check() async {
    _timer = Timer(_interval, _check);
    try {
      final current = await ref.read(appVersionProvider.future);
      final update = await fetchUpdate(current);
      final prefs = await SharedPreferences.getInstance();
      if (update == null || prefs.getString(_dismissedKey) == update.version) {
        state = null;
        return;
      }
      state = update;

      // Once per version, so someone who keeps Nova in the menu bar and
      // never opens the window still hears about it.
      if (prefs.getString(_notifiedKey) != update.version) {
        await prefs.setString(_notifiedKey, update.version);
        final t = ref.read(stringsProvider);
        await NotificationService.instance.show(
          AppStrings.fill(t.updateAvailable, [update.version]),
          t.updateNotifyBody,
        );
      }
    } catch (_) {
      // Offline or rate-limited: the next check will try again.
    }
  }

  /// Hides the banner for this version.
  Future<void> dismiss() async {
    final update = state;
    if (update == null) return;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, update.version);
  }
}
