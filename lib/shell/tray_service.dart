import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/settings/app_settings.dart';
import '../core/utils/byte_format.dart';

/// Desktop platforms that have a window and a tray / menu bar.
bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Menu-bar icon (macOS) / tray icon (Windows, Linux): shows the current
/// speed and hides the window instead of quitting when it is closed. Both
/// can be turned off in Settings; without an icon, closing the window quits.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  /// The window side (close to hide) is set up.
  bool _windowReady = false;

  /// The icon is in the menu bar or tray.
  bool _ready = false;
  String _lastTooltip = '';
  String _lastTitle = '';

  // Settings → Menu bar.
  bool _enabled = true;
  MenuBarContent _content = MenuBarContent.speedAndHour;
  bool _bits = false;

  /// On macOS the menu bar is anchored on the right, so an item that changes
  /// width drags its icon sideways. tray_manager has no setting for this;
  /// the native side (MainFlutterWindow.swift) gives the title equal-width
  /// digits and holds the item at the width of [_widestTitle].
  static const _titleChannel = MethodChannel('net_pulse/tray');
  bool _titleSteadied = false;

  /// Menu entries — the keys are handled in [onTrayMenuItemClick].
  static const _kShow = 'show';
  static const _kQuit = 'quit';

  Future<void> init() async {
    if (!isDesktop || _windowReady) return;

    await windowManager.ensureInitialized();
    // Closing the window doesn't quit the app: it goes to the tray and keeps
    // counting traffic (onWindowClose decides).
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    _windowReady = true;

    if (_enabled) await _showIcon();
  }

  /// Applies Settings → Menu bar: the icon on or off, and what its title
  /// shows.
  Future<void> configure({
    required bool enabled,
    required MenuBarContent content,
    required bool bits,
  }) async {
    if (!isDesktop) return;
    if (content != _content || bits != _bits) {
      _content = content;
      _bits = bits;
      // A new kind of title has a new widest case to hold the width for.
      _titleSteadied = false;
      _lastTitle = '';
    }
    _enabled = enabled;
    if (!_windowReady) return;
    if (enabled && !_ready) await _showIcon();
    if (!enabled && _ready) await _hideIcon();
  }

  Future<void> _showIcon() async {
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

  Future<void> _hideIcon() async {
    trayManager.removeListener(this);
    _ready = false;
    _titleSteadied = false;
    _lastTitle = '';
    _lastTooltip = '';
    try {
      await trayManager.destroy();
    } catch (_) {}
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
  /// The menu bar is tight on space, so the title stays compact — by default
  /// the current total speed plus the hourly total; Settings can change it.
  /// The full split (download/upload separately) lives in the hover tooltip.
  Future<void> updateStatus({
    required int rxPerSec,
    required int txPerSec,
    required int hourBytes,
    required int dayBytes,
  }) async {
    if (!_ready) return;

    // Every reading has the same number of characters, so with equal-width
    // digits the title keeps its width as the numbers change.
    String rate(int bytes) =>
        _bits ? formatFixedWidthBits(bytes) : '${formatFixedWidth(bytes)}/s';
    final title = _title(
      rate(rxPerSec + txPerSec),
      rate(rxPerSec),
      rate(txPerSec),
      formatFixedWidth(hourBytes),
      formatFixedWidth(dayBytes),
    );

    if (title != _lastTitle) {
      _lastTitle = title;
      try {
        await trayManager.setTitle(title);
        // Once the item has a title to measure, on the Mac.
        if (Platform.isMacOS && !_titleSteadied) {
          _titleSteadied = true;
          await _titleChannel.invokeMethod<bool>('steadyTitle', _widestTitle());
        }
      } catch (_) {
        // The title is decoration; a failure here must not break the app.
      }
    }

    final hour = formatBytes(hourBytes);
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

  /// The title for the chosen content, from its formatted parts.
  String _title(String total, String down, String up, String hour, String day) =>
      switch (_content) {
        MenuBarContent.speedAndHour => ' $total · $hour/h',
        MenuBarContent.speed => ' $total',
        MenuBarContent.downUp => ' ↓$down ↑$up',
        MenuBarContent.today => ' $day/d',
        MenuBarContent.iconOnly => '',
      };

  /// The widest title the chosen content can produce: digits all have one
  /// width there, and M is the widest unit letter.
  String _widestTitle() {
    final rate = _bits ? '88.8Mbps' : '88.8M/s';
    return _title(rate, rate, rate, '88.8M', '88.8M');
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
    // Hide the window instead of quitting — monitoring continues. Without
    // an icon there would be no way back to it, so then closing quits.
    if (!_enabled) {
      await quit();
    } else if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
