import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/utils/byte_format.dart';

/// Desktop platforms that have a window and a tray / menu bar.
bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Menu-bar icon (macOS) / tray icon (Windows, Linux): shows the current
/// speed and hides the window instead of quitting when it is closed.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _ready = false;
  String _lastTooltip = '';
  String _lastTitle = '';

  /// Menu entries — the keys are handled in [onTrayMenuItemClick].
  static const _kShow = 'show';
  static const _kQuit = 'quit';

  Future<void> init() async {
    if (!isDesktop || _ready) return;

    await windowManager.ensureInitialized();
    // Closing the window doesn't quit the app: it goes to the tray and keeps
    // counting traffic.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/tray/tray_icon.ico'
          : 'assets/tray/tray_template.png',
      isTemplate: Platform.isMacOS, // macOS tints it for the menu-bar theme
    );
    await trayManager.setToolTip('Nova');
    await _rebuildMenu();

    _ready = true;
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: _kShow, label: 'Nova'),
      MenuItem.separator(),
      MenuItem(key: _kQuit, label: 'Quit'),
    ]));
  }

  /// Updates the text next to the icon (like the battery's "80%") and the
  /// tooltip.
  ///
  /// The menu bar is tight on space, so the title stays compact: current total
  /// speed plus the hourly total. The full split (download/upload separately)
  /// lives in the hover tooltip.
  Future<void> updateStatus({
    required int rxPerSec,
    required int txPerSec,
    required int hourBytes,
  }) async {
    if (!_ready) return;

    final rate = formatRate(rxPerSec + txPerSec);
    final hour = formatBytes(hourBytes);
    final title =
        ' ${rate.value}${_compactUnit(rate.unit)} · ${hour.value}${_compactUnit(hour.unit)}/h';

    if (title != _lastTitle) {
      _lastTitle = title;
      try {
        await trayManager.setTitle(title);
      } catch (_) {
        // The title is decoration; a failure here must not break the app.
      }
    }

    final rx = formatRate(rxPerSec);
    final tx = formatRate(txPerSec);
    final tooltip = 'Nova\n'
        '↓ ${rx.value} ${rx.unit}   ↑ ${tx.value} ${tx.unit}\n'
        'Past hour: ${hour.value} ${hour.unit}';
    if (tooltip != _lastTooltip) {
      _lastTooltip = tooltip;
      try {
        await trayManager.setToolTip(tooltip);
      } catch (_) {}
    }
  }

  /// "KB/s" → "K/s", "MB" → "M" and so on — shorter units for the menu bar.
  String _compactUnit(String unit) {
    if (unit == 'B/s' || unit == 'B') return unit;
    return unit.replaceFirst('B', '');
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> dispose() async {
    if (!_ready) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    _ready = false;
  }

  // ── TrayListener ──────────────────────────────────────────────────

  /// Called on a left click on the icon — opens the compact panel.
  /// Wired up from main.dart so this service stays free of Riverpod.
  VoidCallback? onIconTap;

  @override
  void onTrayIconMouseDown() {
    // Left click opens the compact panel, right click the menu (below).
    final handler = onIconTap;
    if (handler != null) {
      handler();
    } else {
      showWindow();
    }
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _kShow:
        showWindow();
      case _kQuit:
        quit();
    }
  }

  // ── WindowListener ────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    // Hide the window instead of quitting — monitoring continues.
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
