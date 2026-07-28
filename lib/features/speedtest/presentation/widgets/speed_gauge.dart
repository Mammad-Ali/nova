import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_theme.dart';

/// Радиальный спидометр на 270° с солнечно-жёлтой шкалой.
///
/// Текущее значение показывает тонкий луч от центра к шкале. Вокруг циферблата
/// вращаются жёлтые частицы, и скорость их вращения напрямую зависит от
/// скорости интернета — чем быстрее канал, тем быстрее крутится «корона».
class SpeedGauge extends StatefulWidget {
  const SpeedGauge({
    super.key,
    required this.value,
    required this.max,
    required this.child,
    this.color,
    this.active = false,
    this.paused = false,
  });

  final double value;
  final double max;
  final Widget child;

  /// Цвет шкалы. null — солнечно-жёлтый акцент приложения.
  final Color? color;

  /// Идёт ли тест сейчас (включает «разгон» луча при старте).
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
  double _orbit = 0; // фаза орбитального движения
  double _display = 0; // сглаженная доля шкалы
  double _revStart = -1; // время старта «разгона»
  bool _prevActive = false;
  late Color _color = widget.color ?? AppColors.sun;

  @override
  void initState() {
    super.initState();
    _color = widget.color ?? AppColors.sun;
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

    // «Разгон» луча при старте теста: короткий взмах 0 → 1 → факт.
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

    // Вращение «короны»: в покое едва ползёт, на максимуме — вихрь.
    _orbit += dtc * (0.05 + shown * 1.6);
    // Плавная смена цвета при переходе фаз (download ↔ upload).
    _color = Color.lerp(
        _color, widget.color ?? AppColors.sun, 1 - math.exp(-dtc * 5))!;

    _anim.update(shown, _orbit, shown, widget.active, _color);
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
  double orbit = 0;
  double speed = 0;
  bool active = false;
  Color color = AppColors.sun;

  void update(double f, double o, double s, bool a, Color c) {
    fraction = f;
    orbit = o;
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

  /// Сколько частиц на орбитах: от 12 в покое до 64 на максимуме —
  /// во время замера вокруг шкалы закручивается плотная «корона».
  static const _minOrbiters = 12;
  static const _maxOrbiters = 64;

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

    _drawOrbiters(canvas, center, radius, speed);

    // Дорожка шкалы.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = AppColors.onGlass.withValues(alpha: 0.05),
    );

    // Тики.
    final tick = Paint()
      ..color = AppColors.onGlass.withValues(alpha: 0.13)
      ..strokeWidth = 1.6;
    for (var i = 0; i <= 9; i++) {
      final a = start + sweep * (i / 9);
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
          center + d * (radius - 9), center + d * (radius - 1), tick);
    }

    // Заполненная часть шкалы.
    canvas.drawArc(
      rect,
      start,
      sweep * f,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            baseColor.withValues(alpha: 0.45),
            baseColor,
            Color.lerp(baseColor, Colors.white, 0.45)!,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(rect),
    );

    _drawRay(canvas, center, radius, start, sweep, f, baseColor, speed);
  }

  /// Тонкий луч-указатель от центра к текущему делению шкалы.
  void _drawRay(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    double f,
    Color color,
    double speed,
  ) {
    final a = start + sweep * f;
    final dir = Offset(math.cos(a), math.sin(a));
    final from = center + dir * (radius * 0.20);
    final to = center + dir * (radius - 7);

    // Луч сужается к центру: у шкалы ярче и толще, у ступицы почти исчезает.
    canvas.drawLine(
      from,
      to,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromPoints(from, to))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Крошечная метка на конце — единственное свечение на циферблате.
    canvas.drawCircle(
      to,
      3.0 + 1.5 * speed,
      Paint()..color = Color.lerp(color, Colors.white, 0.6)!,
    );

    // Ступица.
    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = AppColors.onGlass.withValues(alpha: 0.5),
    );
  }

  /// Частицы на круговых орбитах вокруг циферблата. Чем выше скорость,
  /// тем их больше и тем плотнее кольцо.
  void _drawOrbiters(
      Canvas canvas, Offset center, double radius, double speed) {
    final count =
        (_minOrbiters + (_maxOrbiters - _minOrbiters) * speed).round();
    final paint = Paint();

    for (var i = 0; i < count; i++) {
      // Три кольца на разных радиусах — простая, но убедительная глубина.
      final ring = i % 4;
      final rr = radius * (1.09 + ring * 0.065);
      // Внешние кольца отстают — как настоящие орбиты (дальше = медленнее).
      final rate = 1.0 - ring * 0.17;
      final ang = anim.orbit * rate * math.pi * 2 + i * 2.399; // золотой угол
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * rr;

      // Жёлтые, как солнечная корона; дальние кольца бледнее.
      paint.color = AppColors.sun
          .withValues(alpha: (0.35 + 0.45 * speed) * (1.0 - ring * 0.17));
      canvas.drawCircle(pos, 1.5 + 1.2 * speed, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => false;
}
