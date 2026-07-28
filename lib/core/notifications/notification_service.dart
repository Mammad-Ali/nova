import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Системные уведомления. Пакет [local_notifier] умеет только десктоп,
/// поэтому на мобильных методы тихо ничего не делают.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _ready = false;

  bool get _supported =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await localNotifier.setup(appName: 'Nova');
      _ready = true;
    } catch (_) {
      // Без уведомлений приложение работает как обычно.
    }
  }

  Future<void> show(String title, String body) async {
    if (!_supported || !_ready) return;
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {}
  }
}
