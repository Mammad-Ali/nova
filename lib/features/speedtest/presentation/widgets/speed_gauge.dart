import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_theme.dart';

/// Живой радиальный спидометр на 270°.
///
/// По кольцу единым потоком в одну сторону летят светящиеся «кометы», цвет
/// которых постоянно переливается синий→циан→зелёный→золото (перелив идёт
/// всегда, а скорость лишь ускоряет и делает ярче). При старте теста стрелка
/// эффектно «разгоняется» с нуля, а смена фаз плавно перекрашивает дугу.
class SpeedGauge extends StatefulWidget {
  const SpeedGauge({
    super.key,
    required this.value,
    required this.max,
    required this.child,
    this.color = AppColors.cyan,
    this.active = false,
    this.paused = false,
  });

  final double value;
  final double max;
  final Color color;
  final Widget child;

  /// Идёт ли тест сейчас (включает «разгон» и усиливает свечение).
  final bool active;

  /// Окно свёрнуто или не в фокусе — анимацию можно остановить ради батареи.
  final bool paused;

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _anim = _GaugeAnim();

  Duration _last = Duration.zero;
  double _clock = 0; // абсолютное время, сек
  double _phase = 0; // бег частиц
  double _pulse = 0; // пульсация ядра
  double _display = 0; // сглаженная доля стрелки
  double _revStart = -1; // время старта «разгона»
  bool _prevActive = false;
  late Color _color = widget.color;

  @override
  void initState() {
    super.initState();
    _color = widget.color;
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
    final dtc = dt.clamp(0.0, 0.05);
    _clock += dtc;

    final target = widget.max <= 0
        ? 0.0
        : (widget.value / widget.max).clamp(0.0, 1.0).toDouble();
    _display += (target - _display) * (1 - math.exp(-dtc * 6));

    // «Разгон» стрелки при старте теста: короткий взмах 0→1→факт.
    if (widget.active && !_prevActive) _revStart = _clock;
    _prevActive = widget.active;
    var rev = 0.0;
    if (_revStart >= 0) {
      final rt = (_clock - _revStart) / 0.9;
      if (rt >= 0 && rt < 1) {
        rev = math.sin(rt * math.pi); // 0 → 1 → 0
      } else if (rt >= 1) {
        _revStart = -1;
      }
    }
    final shown = math.max(_display, rev);
    final speed = shown;

    _phase = (_phase + dtc * (0.08 + speed * 1.9)) % 1.0;
    _pulse = (_pulse + dtc * (0.6 + speed * 3.0)) % (2 * math.pi);
    // Плавная смена цвета при переходе фаз (download↔upload).
    _color = Color.lerp(_color, widget.color, 1 - math.exp(-dtc * 5))!;

    _anim.update(shown, _phase, _pulse, speed, widget.active, _color);
  }

  @override
  void didUpdateWidget(covariant SpeedGauge old) {
    super.didUpdateWidget(old);
    if (widget.paused && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isActive) {
      _last = Duration.zero; // без этого dt подскочит на всю паузу
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _GaugePainter(_anim),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _GaugeAnim extends ChangeNotifier {
  double fraction = 0;
  double phase = 0;
  double pulse = 0;
  double speed = 0;
  bool active = false;
  Color color = AppColors.cyan;

  void update(
      double f, double p, double pu, double s, bool a, Color c) {
    fraction = f;
    phase = p;
    pulse = pu;
    speed = s;
    active = a;
    color = c;
    notifyListeners();
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.anim) : super(repaint: anim);

  final _GaugeAnim anim;

  static const _startDeg = 135.0;
  static const _sweepDeg = 270.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = _startDeg * math.pi / 180;
    final sweep = _sweepDeg * math.pi / 180;
    final f = anim.fraction.clamp(0.0, 1.0);
    final speed = anim.speed;
    final baseColor = anim.color;
    final hot = Color.lerp(baseColor, speedColor(speed), 0.6)!;

    // Пульсирующее ядро (за текстом).
    final pulseT = (math.sin(anim.pulse) + 1) / 2;
    final coreR = radius * (0.5 + 0.05 * pulseT);
    final coreAlpha = (0.05 + 0.22 * speed) * (0.6 + 0.4 * pulseT);
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [hot.withValues(alpha: coreAlpha), hot.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );

    // Дорожка.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.05),
    );

    // Тики.
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 2;
    for (var i = 0; i <= 9; i++) {
      final a = start + sweep * (i / 9);
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + d * (radius - 10), center + d * (radius - 1), tick);
    }

    // Кометы единым потоком с постоянным переливом цвета.
    _drawComets(canvas, center, radius, start, sweep, speed);

    // Дуга прогресса.
    canvas.drawArc(
      rect,
      start,
      sweep * f,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            baseColor.withValues(alpha: 0.5),
            baseColor,
            Color.lerp(baseColor, Colors.white, 0.6)!,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(rect),
    );

    // Светящаяся голова дуги.
    if (f > 0.001) {
      final a = start + sweep * f;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(
        p,
        12 + 6 * speed,
        Paint()
          ..color = hot.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
    }
  }

  void _drawComets(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    double speed,
  ) {
    const perRing = 8;
    final rings = [radius, radius * 0.86, radius * 0.72];
    final tailSteps = (3 + speed * 9).round();
    final baseAlpha = (anim.active ? 0.22 : 0.13) + speed * 0.55;

    for (var r = 0; r < rings.length; r++) {
      final rr = rings[r];
      final ringFade = 1.0 - r * 0.20;
      for (var i = 0; i < perRing; i++) {
        // Единое направление для всех колец.
        final headFrac = (((i / perRing) + anim.phase + r * 0.11) % 1.0);
        for (var k = 0; k < tailSteps; k++) {
          final frac = headFrac - k * 0.011;
          if (frac < 0 || frac > 1) continue;
          final a = start + sweep * frac;
          final pos = center + Offset(math.cos(a), math.sin(a)) * rr;
          final tt = 1 - k / tailSteps;

          // Постоянный перелив: положение + время + скорость, треугольная
          // развёртка палитры (плавная петля синий↔золото).
          final ct = (frac * 0.6 + anim.phase * 0.8 + speed * 0.4 + r * 0.2) % 1.0;
          final tri = 1 - (2 * ct - 1).abs();
          final base = speedColor(tri);

          final dotAlpha = (baseAlpha * tt * ringFade).clamp(0.0, 1.0);
          final col = Color.lerp(base, Colors.white, 0.55 * tt)!;
          canvas.drawCircle(
            pos,
            0.7 + 2.8 * tt,
            Paint()..color = col.withValues(alpha: dotAlpha),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => false;
}

/// Цвет по значению 0..1: синий → циан → зелёный → золотой.
Color speedColor(double t) {
  final x = t.clamp(0.0, 1.0);
  const stops = [
    (0.0, Color(0xFF3B82F6)),
    (0.4, Color(0xFF22D3EE)),
    (0.72, Color(0xFF34D399)),
    (1.0, Color(0xFFFBBF24)),
  ];
  for (var i = 0; i < stops.length - 1; i++) {
    final (p0, c0) = stops[i];
    final (p1, c1) = stops[i + 1];
    if (x <= p1) {
      final k = (x - p0) / (p1 - p0);
      return Color.lerp(c0, c1, k)!;
    }
  }
  return stops.last.$2;
}
