import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/traffic_monitor/presentation/providers/traffic_provider.dart';

/// Живой фон: дрейфующее звёздное поле поверх мягких волн «северного сияния».
///
/// Двигается всегда (не только во время теста); скорость подсвечивает сияние
/// ярче и чуть разгоняет звёзды.
class StarfieldBackground extends ConsumerStatefulWidget {
  const StarfieldBackground({super.key});

  @override
  ConsumerState<StarfieldBackground> createState() =>
      _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends ConsumerState<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _anim = _BgAnim();
  final List<_Star> _stars = _buildStars(110);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _anim.advance(dt.clamp(0.0, 0.05));
  }

  @override
  Widget build(BuildContext context) {
    // Уровень скорости: во время теста — стрелка спидометра, иначе — трафик.
    final st = ref.watch(speedTestControllerProvider);
    final speedFrac =
        st.gaugeMax > 0 ? (st.displayMbps / st.gaugeMax).clamp(0.0, 1.0) : 0.0;
    final hist = ref.watch(trafficHistoryProvider);
    final rate = (hist.currentRxPerSec + hist.currentTxPerSec).toDouble();
    final trafficFrac = (rate / (12.5 * 1024 * 1024)).clamp(0.0, 1.0);
    _anim.level = math.max(speedFrac, trafficFrac).toDouble();

    return Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StarfieldPainter(_anim, _stars),
        ),
      ),
    );
  }
}

class _BgAnim extends ChangeNotifier {
  double time = 0;
  double level = 0;

  /// Накопленный дрейф звёзд. Интегрируем по dt, а не считаем как время ×
  /// скорость — иначе при изменении скорости позиция скачком «прыгает».
  double drift = 0;

  void advance(double dt) {
    time += dt;
    drift += dt * (0.015 + level * 0.05);
    notifyListeners();
  }
}

class _Star {
  _Star(this.x, this.y, this.size, this.speed, this.phase, this.twinkle);
  final double x, y; // 0..1
  final double size;
  final double speed; // множитель дрейфа
  final double phase;
  final double twinkle;
}

List<_Star> _buildStars(int n) {
  final rnd = math.Random(7);
  return List.generate(n, (_) {
    final big = rnd.nextDouble() < 0.14;
    return _Star(
      rnd.nextDouble(),
      rnd.nextDouble(),
      big ? 1.6 + rnd.nextDouble() * 1.8 : 0.5 + rnd.nextDouble() * 1.1,
      0.4 + rnd.nextDouble() * 1.2,
      rnd.nextDouble() * math.pi * 2,
      0.5 + rnd.nextDouble() * 2.5,
    );
  });
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.anim, this.stars) : super(repaint: anim);

  final _BgAnim anim;
  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim.time;
    final level = anim.level;

    // Базовый градиент.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg1, AppColors.bg0],
        ).createShader(Offset.zero & size),
    );

    // Волны северного сияния — три мягких пятна, дрейфуют и «дышат».
    _aurora(canvas, w, h, t, level, AppColors.auroraGreen,
        cx: 0.28, cy: 0.30, dx: 0.06, dy: 0.05, sp: 0.35, base: 0.10);
    _aurora(canvas, w, h, t, level, AppColors.auroraViolet,
        cx: 0.74, cy: 0.34, dx: 0.07, dy: 0.06, sp: 0.27, base: 0.10);
    _aurora(canvas, w, h, t, level, AppColors.auroraTeal,
        cx: 0.5, cy: 0.82, dx: 0.08, dy: 0.04, sp: 0.22, base: 0.08);

    // Звёзды.
    final starPaint = Paint();
    for (final s in stars) {
      // Медленный дрейф вверх с оборачиванием (дрейф уже проинтегрирован).
      final y = ((s.y - anim.drift * s.speed) % 1.0 + 1.0) % 1.0;
      final x = (s.x + math.sin(t * 0.05 * s.speed + s.phase) * 0.01) % 1.0;

      final tw = 0.55 + 0.45 * math.sin(t * s.twinkle + s.phase);
      final alpha = (0.25 + 0.6 * tw) * (0.7 + 0.3 * level);
      starPaint.color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0));
      final r = s.size * (0.85 + 0.3 * tw);
      canvas.drawCircle(Offset(x * w, y * h), r, starPaint);
    }
  }

  void _aurora(
    Canvas canvas,
    double w,
    double h,
    double t,
    double level,
    Color color, {
    required double cx,
    required double cy,
    required double dx,
    required double dy,
    required double sp,
    required double base,
  }) {
    final x = (cx + math.sin(t * sp) * dx) * w;
    final y = (cy + math.cos(t * sp * 0.8) * dy) * h;
    final breathe = 0.5 + 0.5 * math.sin(t * sp * 1.3);
    final radius = math.min(w, h) * (0.42 + 0.05 * breathe);
    final alpha = (base + 0.22 * level) * (0.7 + 0.3 * breathe);
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha.clamp(0.0, 1.0)),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}
