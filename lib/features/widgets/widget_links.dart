import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/home_shell.dart';
import '../../shell/compact_mode.dart';
import '../../shell/tray_service.dart';
import '../call_check/presentation/call_check_sheet.dart';
import '../diagnose/presentation/diagnosis_sheet.dart';
import '../speedtest/presentation/providers/speedtest_provider.dart';

/// Carries out a click on a Mac widget. Each one arrives as a nova:// link
/// (NovaLinks in MainFlutterWindow.swift):
///
///   nova://test   bring Nova forward and start a speed test
///   nova://call   … and start the call check
///   nova://cause  … and start "Find the cause"
///   nova://open   just bring Nova forward
///   nova://test?quiet=1
///                 start a speed test and stay out of the way: a widget's
///                 "Start test", whose result shows on the widget
///
/// A click can also launch Nova; its link then waits on the native side
/// until [listen] asks for it.
class WidgetLinks {
  WidgetLinks(this._ref, this._navigator);

  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigator;

  static const _channel = MethodChannel('net_pulse/links');

  Future<void> listen() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') await _handle(call.arguments as String);
    });
    try {
      final waiting = await _channel.invokeListMethod<String>('take') ?? const [];
      for (final link in waiting) {
        await _handle(link);
      }
    } on MissingPluginException {
      // A build without the widget extension.
    }
  }

  Future<void> _handle(String link) async {
    final uri = Uri.tryParse(link);
    final action = uri?.host;
    if (uri == null || action == null) return;

    // A test from a widget runs where Nova is — in the menu bar, or behind
    // other windows — without moving anything; the widget shows the result.
    if (action == 'test' && uri.queryParameters['quiet'] == '1') {
      if (!_ref.read(speedTestControllerProvider).isRunning) {
        _ref.read(speedTestControllerProvider.notifier).start();
      }
      return;
    }

    // Out of the menu-bar panel and onto the speed test, in front.
    final compact = _ref.read(compactModeProvider.notifier);
    if (_ref.read(compactModeProvider)) await compact.exit();
    await TrayService.instance.showWindow();
    _ref.read(homeTabProvider.notifier).show(0);

    // Whatever sheet was open gives way to the one asked for.
    final navigator = _navigator.currentState;
    navigator?.popUntil((route) => route.isFirst);
    final context = _navigator.currentContext;

    switch (action) {
      case 'test':
        final test = _ref.read(speedTestControllerProvider);
        if (!test.isRunning) _ref.read(speedTestControllerProvider.notifier).start();
      case 'call':
        if (context != null && context.mounted) showCallCheckSheet(context, start: true);
      case 'cause':
        if (context != null && context.mounted) showDiagnosisSheet(context, start: true);
      default:
        break; // "open": being in front is the whole point
    }
  }
}
