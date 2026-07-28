import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/utils/byte_format.dart';

/// Десктопные платформы, где есть окно и трей/меню-бар.
bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Иконка в меню-баре (macOS) / трее (Windows, Linux):
/// показывает текущую скорость в подсказке и прячет окно вместо закрытия.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _ready = false;
  String _lastTooltip = '';
  String _lastTitle = '';

  /// Пункты меню — ключи обрабатываются в [onTrayMenuItemClick].
  static const _kShow = 'show';
  static const _kQuit = 'quit';

  Future<void> init() async {
    if (!isDesktop || _ready) return;

    await windowManager.ensureInitialized();
    // Закрытие окна не убивает приложение — оно уходит в трей и продолжает
    // считать трафик.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/tray/tray_icon.ico'
          : 'assets/tray/tray_template.png',
      isTemplate: Platform.isMacOS, // macOS сам перекрасит под тему меню-бара
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

  /// Обновляет текст рядом с иконкой (как у батареи «80%») и подсказку.
  ///
  /// В самой строке меню места мало, поэтому показываем компактно: текущую
  /// суммарную скорость и итог за час. Полную раскладку (отдельно
  /// download/upload) — в подсказке при наведении.
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
        // Заголовок — украшение; его сбой не должен ломать приложение.
      }
    }

    final rx = formatRate(rxPerSec);
    final tx = formatRate(txPerSec);
    final tooltip = 'Nova\n'
        '↓ ${rx.value} ${rx.unit}   ↑ ${tx.value} ${tx.unit}\n'
        'За час: ${hour.value} ${hour.unit}';
    if (tooltip != _lastTooltip) {
      _lastTooltip = tooltip;
      try {
        await trayManager.setToolTip(tooltip);
      } catch (_) {}
    }
  }

  /// «KB/s» → «K/s», «MB» → «M» и т.п. — сокращаем единицы для тесной строки меню.
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

  /// Вызывается при левом клике по иконке — открывает мини-панель.
  /// Ставится из main.dart, чтобы сервис не зависел от Riverpod.
  VoidCallback? onIconTap;

  @override
  void onTrayIconMouseDown() {
    // Левый клик — мини-панель, правый — меню (см. ниже).
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
    // Прячем окно вместо выхода — мониторинг продолжается в фоне.
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
