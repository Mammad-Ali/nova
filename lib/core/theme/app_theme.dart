import 'package:flutter/material.dart';

/// Nova's palette: black space, white stars, a sun-yellow accent.
///
/// There is a single dark theme. Colours are exposed as static members so
/// `CustomPainter` and other non-widget code can read them without a
/// `BuildContext`.
class AppColors {
  AppColors._();

  // True black, so the stars read like a real night sky.
  static const Color bg0 = Color(0xFF000000);
  static const Color bg1 = Color(0xFF000000);
  static const Color surface = Color(0xFF0B0B0E);

  /// Sun yellow — the primary accent: gauge scale, active tab, dial particles.
  static const Color sun = Color(0xFFFFC61A);

  // Metric colours stay distinct: download, upload, ping and jitter are told
  // apart by these.
  static const Color accentDown = Color(0xFF818CF8);
  static const Color accentUp = Color(0xFFE879F9);
  static const Color accentAlt = Color(0xFF60A5FA);
  static const Color accentInfo = Color(0xFF6366F1);

  // Rating semantics.
  static const Color green = Color(0xFF4ADE80);
  static const Color amber = Color(0xFFFBBF24);
  static const Color red = Color(0xFFFB7185);

  // Heading gradient.
  static const Color nebulaIndigo = Color(0xFF4F46E5);
  static const Color nebulaViolet = Color(0xFF9333EA);
  static const Color nebulaPink = Color(0xFFDB2777);

  // Text.
  static const Color textHi = Color(0xFFF5F6FA);
  static const Color textMid = Color(0xB3F5F6FA); // ~70%
  static const Color textLo = Color(0x66F5F6FA); // ~40%

  /// Primary colour for text and icons on glass surfaces.
  static const Color onGlass = Color(0xFFFFFFFF);

  /// Colour of stars and backdrop particles.
  static const Color starColor = Color(0xFFFFFFFF);

  /// Gradient used for screen headings.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [nebulaIndigo, nebulaViolet, nebulaPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Glass card decoration. [glow] adds a soft coloured halo.
BoxDecoration glassCard({Color? glow, double radius = 22}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.045),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
    boxShadow: glow == null
        ? null
        : [
            BoxShadow(
              color: glow.withValues(alpha: 0.07),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
  );
}

ThemeData buildNovaTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.sun,
    onPrimary: Colors.black,
    secondary: AppColors.accentDown,
    surface: AppColors.surface,
    onSurface: AppColors.textHi,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg0,
    splashFactory: InkRipple.splashFactory,
  );
}
