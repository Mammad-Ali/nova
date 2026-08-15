import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// True when the window acts as a compact panel under the menu-bar icon.
final compactModeProvider =
    NotifierProvider<CompactModeNotifier, bool>(CompactModeNotifier.new);

/// Switches the window between its normal form and the compact panel.
///
/// A second window is still unreliable in desktop Flutter, so the panel reuses
/// the same window: frameless, always on top, anchored to the tray icon. The
/// previous size and position are remembered and restored on exit.
class CompactModeNotifier extends Notifier<bool> {
  static const _panelSize = Size(340, 420);

  Rect? _savedFrame;
  bool _busy = false;

  bool get _supported =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  bool build() => false;

  Future<void> toggle() => state ? exit() : enter();

  Future<void> enter() async {
    if (!_supported || state || _busy) return;
    _busy = true;
    try {
      _savedFrame ??= await _currentFrame();

      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      await windowManager.setSize(_panelSize);
      await windowManager.setPosition(await _panelPosition());
      await windowManager.show();
      await windowManager.focus();

      state = true;
    } finally {
      _busy = false;
    }
  }

  Future<void> exit() async {
    if (!_supported || !state || _busy) return;
    _busy = true;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setResizable(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);

      final frame = _savedFrame;
      if (frame != null) {
        await windowManager.setSize(frame.size);
        await windowManager.setPosition(frame.topLeft);
      }
      await windowManager.show();
      await windowManager.focus();

      state = false;
    } finally {
      _busy = false;
    }
  }

  Future<Rect?> _currentFrame() async {
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      return Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
    } catch (_) {
      return null;
    }
  }

  /// Places the panel under the tray icon; if those coordinates aren't
  /// available, falls back to the top-right corner of the screen.
  Future<Offset> _panelPosition() async {
    const margin = 8.0;
    try {
      final bounds = await trayManager.getBounds();
      if (bounds != null) {
        final left = bounds.left + bounds.width / 2 - _panelSize.width / 2;
        return Offset(left.clamp(margin, 100000), bounds.bottom + margin);
      }
    } catch (_) {
      // getBounds isn't supported everywhere — fall through to the fallback.
    }
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      return Offset(
        display.size.width - _panelSize.width - margin,
        36, // below the menu bar
      );
    } catch (_) {
      return const Offset(900, 36);
    }
  }
}
