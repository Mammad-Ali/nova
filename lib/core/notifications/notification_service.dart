import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// System notifications. [local_notifier] is desktop-only, so on mobile these
/// methods quietly do nothing.
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
      // The app works fine without notifications.
    }
  }

  Future<void> show(String title, String body) async {
    if (!_supported || !_ready) return;
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {}
  }
}
