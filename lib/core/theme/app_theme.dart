import 'package:flutter/material.dart';

/// Единая палитра и стили тёмной темы NetPulse.
///
/// Всё держим в одном месте, чтобы обе вкладки (Speedtest и Монитор)
/// выглядели как одно целое.
class AppColors {
  AppColors._();

  // Фон
  static const bg0 = Color(0xFF070A12); // самый тёмный
  static const bg1 = Color(0xFF0B1220);
  static const surface = Color(0xFF121826);

  // Акценты
  static const cyan = Color(0xFF22D3EE); // download / rx
  static const violet = Color(0xFFA855F7); // upload / tx
  static const blue = Color(0xFF3B82F6);
  static const indigo = Color(0xFF6366F1);
  static const green = Color(0xFF34D399);
  static const teal = Color(0xFF2DD4BF);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF87171);

  // Палитра «северного сияния» — для фона и общего свечения.
  static const auroraGreen = Color(0xFF34D399);
  static const auroraTeal = Color(0xFF22D3EE);
  static const auroraViolet = Color(0xFF8B5CF6);

  // Текст
  static const textHi = Color(0xFFF1F5F9);
  static const textMid = Color(0xB3F1F5F9); // ~70%
  static const textLo = Color(0x66F1F5F9); // ~40%

  // Северное сияние: зелёный → бирюза → фиолет.
  static const primaryGradient = LinearGradient(
    colors: [auroraGreen, auroraTeal, auroraViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Декорация «стеклянной» карточки. [glow] добавляет мягкое свечение цвета.
BoxDecoration glassCard({Color? glow, double radius = 22}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: glow == null
        ? null
        : [
            BoxShadow(
              color: glow.withValues(alpha: 0.10),
              blurRadius: 28,
              spreadRadius: -6,
            ),
          ],
  );
}

ThemeData buildNetPulseTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.cyan,
    secondary: AppColors.violet,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg0,
    splashFactory: InkRipple.splashFactory,
  );
}
