import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/speedtest_models.dart';
import 'speedtest_history_provider.dart';
import 'speedtest_provider.dart';

/// A result under this many Mbps gets one more test, in case it was a dip.
const retestBelowMbps = 50.0;

/// Runs a speed test on its own every few hours (Settings → Automatic tests)
/// while Nova is running — from the menu bar or tray, or with the app open
/// on Android. It counts from the last test of any kind, so a test run by
/// hand moves the next one back. Metered connections (mobile data, a phone's
/// hotspot, Low Data Mode) are skipped: a test moves a lot of data.
final autoTestProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  var startedByUs = false;
  var retested = false;
  Timer? retest;

  Future<void> run({required bool isRetest}) async {
    if (ref.read(speedTestControllerProvider).isRunning) return;
    if (await _onMeteredConnection()) return;
    startedByUs = true;
    retested = isRetest;
    ref.read(speedTestControllerProvider.notifier).start();
  }

  Future<void> check() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.autoTestEnabled) return;
    final history = ref.read(speedTestHistoryProvider);
    final last = history.isEmpty ? null : history.last.timestamp;
    final due = last == null ||
        DateTime.now().difference(last) >= Duration(hours: settings.autoTestHours);
    if (due) await run(isRetest: false);
  }

  // One more try a minute after a slow automatic result.
  ref.listen(speedTestControllerProvider.select((s) => s.phase), (prev, next) {
    if (!startedByUs || prev == next) return;
    if (next == TestPhase.done || next == TestPhase.error || next == TestPhase.idle) {
      startedByUs = false;
      final down = ref.read(speedTestControllerProvider).downloadMbps;
      if (next == TestPhase.done && !retested && down != null && down < retestBelowMbps) {
        retest?.cancel();
        retest = Timer(const Duration(minutes: 1), () => run(isRetest: true));
      }
    }
  });

  final timer = Timer.periodic(const Duration(minutes: 1), (_) => check());
  ref.onDispose(() {
    timer.cancel();
    retest?.cancel();
  });
});

/// Whether the system calls the current connection costly: mobile data, a
/// phone's hotspot, Low Data Mode. Answered natively on macOS and Android;
/// Windows doesn't say, and counts as unmetered.
Future<bool> _onMeteredConnection() async {
  try {
    return await const MethodChannel('net_pulse/network').invokeMethod<bool>('isMetered') ?? false;
  } catch (_) {
    return false;
  }
}
