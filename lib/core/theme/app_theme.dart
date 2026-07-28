import 'package:flutter/material.dart';

/// Набор цветов одной темы. Цвета названы по роли, а не по оттенку
/// (`accentDown`, а не `cyan`), поэтому одна и та же вёрстка работает
/// и в тёмной, и в светлой теме.
class PulsarPalette {
  const PulsarPalette({
    required this.brightness,
    required this.bg0,
    required this.bg1,
    required this.surface,
    required this.accentDown,
    required this.accentUp,
    required this.accentAlt,
    required this.accentInfo,
    required this.green,
    required this.amber,
    required this.red,
    required this.nebulaIndigo,
    required this.nebulaViolet,
    required this.nebulaPink,
    required this.textHi,
    required this.textMid,
    required this.textLo,
    required this.onGlass,
    required this.glassFill,
    required this.glassBorder,
    required this.starColor,
  });

  final Brightness brightness;

  /// Фон: bg0 — самый дальний слой, bg1 — верх градиента.
  final Color bg0;
  final Color bg1;
  final Color surface;

  /// Акценты: download / upload и два вспомогательных.
  final Color accentDown;
  final Color accentUp;
  final Color accentAlt;
  final Color accentInfo;

  /// Семантика оценок.
  final Color green;
  final Color amber;
  final Color red;

  /// Туманность — фон, градиенты, частицы.
  final Color nebulaIndigo;
  final Color nebulaViolet;
  final Color nebulaPink;

  /// Текст по убыванию контраста.
  final Color textHi;
  final Color textMid;
  final Color textLo;

  /// Основной цвет текста и иконок поверх стекла: в тёмной теме белый,
  /// в светлой — почти чёрный. Заменяет прежние жёсткие `Colors.white`.
  final Color onGlass;

  /// Заливка и граница «стеклянных» карточек.
  final Color glassFill;
  final Color glassBorder;

  /// Цвет звёзд на фоне.
  final Color starColor;

  bool get isDark => brightness == Brightness.dark;

  /// Индиго → фиолет → розовый.
  LinearGradient get primaryGradient => LinearGradient(
        colors: [nebulaIndigo, nebulaViolet, nebulaPink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Тёмная тема — «глубокий космос».
const kDarkPalette = PulsarPalette(
  brightness: Brightness.dark,
  bg0: Color(0xFF04050C),
  bg1: Color(0xFF090B18),
  surface: Color(0xFF11132A),
  accentDown: Color(0xFF818CF8),
  accentUp: Color(0xFFE879F9),
  accentAlt: Color(0xFF60A5FA),
  accentInfo: Color(0xFF6366F1),
  green: Color(0xFF4ADE80),
  amber: Color(0xFFFBBF24),
  red: Color(0xFFFB7185),
  nebulaIndigo: Color(0xFF4F46E5),
  nebulaViolet: Color(0xFF9333EA),
  nebulaPink: Color(0xFFDB2777),
  textHi: Color(0xFFEEF0FA),
  textMid: Color(0xB3EEF0FA),
  textLo: Color(0x66EEF0FA),
  onGlass: Color(0xFFFFFFFF),
  glassFill: Color(0x0BFFFFFF),
  glassBorder: Color(0x17FFFFFF),
  starColor: Color(0xFFFFFFFF),
);

/// Светлая тема — «рассвет»: то же звёздное небо, но перед восходом.
/// Акценты приглушены, чтобы держать контраст на светлом фоне.
const kLightPalette = PulsarPalette(
  brightness: Brightness.light,
  bg0: Color(0xFFEDEBFA),
  bg1: Color(0xFFF7F5FF),
  surface: Color(0xFFFFFFFF),
  accentDown: Color(0xFF4F46E5),
  accentUp: Color(0xFFC026D3),
  accentAlt: Color(0xFF2563EB),
  accentInfo: Color(0xFF4338CA),
  green: Color(0xFF059669),
  amber: Color(0xFFB45309),
  red: Color(0xFFDC2626),
  nebulaIndigo: Color(0xFF6366F1),
  nebulaViolet: Color(0xFF9333EA),
  nebulaPink: Color(0xFFDB2777),
  textHi: Color(0xFF0F1030),
  textMid: Color(0xB30F1030),
  textLo: Color(0x730F1030),
  onGlass: Color(0xFF0F1030),
  glassFill: Color(0x99FFFFFF),
  glassBorder: Color(0x1A0F1030),
  starColor: Color(0xFF4F46E5),
);

/// Активная палитра. Меняется в `NetPulseApp.build` до построения дерева,
/// поэтому виджеты, читающие [AppColors], получают уже новые цвета.
PulsarPalette _active = kDarkPalette;

/// Переключает палитру. Возвращает true, если она действительно изменилась.
bool applyPalette(PulsarPalette palette) {
  if (identical(_active, palette)) return false;
  _active = palette;
  return true;
}

/// Фасад над активной палитрой — чтобы не тащить BuildContext туда, где его
/// нет (CustomPainter, отрисовка карточки для шаринга и т.п.).
class AppColors {
  AppColors._();

  static PulsarPalette get palette => _active;
  static bool get isDark => _active.isDark;

  static Color get bg0 => _active.bg0;
  static Color get bg1 => _active.bg1;
  static Color get surface => _active.surface;

  static Color get accentDown => _active.accentDown;
  static Color get accentUp => _active.accentUp;
  static Color get accentAlt => _active.accentAlt;
  static Color get accentInfo => _active.accentInfo;

  static Color get green => _active.green;
  static Color get amber => _active.amber;
  static Color get red => _active.red;

  static Color get nebulaIndigo => _active.nebulaIndigo;
  static Color get nebulaViolet => _active.nebulaViolet;
  static Color get nebulaPink => _active.nebulaPink;

  static Color get textHi => _active.textHi;
  static Color get textMid => _active.textMid;
  static Color get textLo => _active.textLo;

  /// Основной цвет текста поверх стекла (бывший жёсткий `Colors.white`).
  static Color get onGlass => _active.onGlass;

  static Color get starColor => _active.starColor;

  static LinearGradient get primaryGradient => _active.primaryGradient;
}

/// Декорация «стеклянной» карточки. [glow] добавляет мягкое свечение цвета.
///
/// Свечения намеренно мало: интерфейс должен читаться поверх звёздного фона,
/// а не соперничать с ним.
BoxDecoration glassCard({Color? glow, double radius = 22}) {
  return BoxDecoration(
    color: _active.glassFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _active.glassBorder),
    boxShadow: glow == null
        ? null
        : [
            BoxShadow(
              color: glow.withValues(alpha: _active.isDark ? 0.07 : 0.12),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
  );
}

ThemeData buildNetPulseTheme([PulsarPalette? p]) {
  final palette = p ?? _active;
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.accentDown,
    onPrimary: palette.isDark ? Colors.black : Colors.white,
    secondary: palette.accentUp,
    onSecondary: palette.isDark ? Colors.black : Colors.white,
    error: palette.red,
    onError: Colors.white,
    surface: palette.surface,
    onSurface: palette.textHi,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg0,
    splashFactory: InkRipple.splashFactory,
  );
}
