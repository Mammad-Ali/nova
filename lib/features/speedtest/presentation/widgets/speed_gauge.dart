import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/gauge_scale.dart';

/// A 270° radial gauge with a sun-yellow, numbered scale ([GaugeScale]).
///
/// The current value is marked by a thin ray running from the centre to the
/// scale. Yellow particles orbit the dial, and their rotation speed follows
/// the measured connection speed: the faster the link, the faster the corona.
///
/// Fast lines get a show during the test: from [glowMbps] the arc glows and
/// sparks fly off the needle; from [warpMbps] the sparks thicken, a shockwave
/// rings out as the needle crosses, and the number shimmers gold (the stars
/// behind go to warp speed — see starfield_background.dart).
class SpeedGauge extends StatefulWidget {
  const SpeedGauge({
    super.key,
    required this.value,
    required this.scale,
    required this.child,
    this.color,
    this.active = false,
    this.paused = false,
  });

  final double value;
  final GaugeScale scale;
  final Widget child;

  /// Scale colour. null means the app's sun-yellow accent.
  final Color? color;

  /// Whether a test is running (enables the ray's sweep on start).
  final bool active;

  /// Window hidden or unfocused — the animation can stop to save battery.
  final bool paused;

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

/// Where the gauge starts to glow and spark.
const glowMbps = 100.0;

/// Where it goes to warp speed.
const warpMbps = 500.0;

/// A spark thrown off the needle tip. Position and velocity are in units of
/// the dial's radius, so they scale with the gauge.
class _Spark {
  _Spark(this.pos, this.vel, this.life, this.size);

  Offset pos;
  Offset vel;
  double age = 0;
  final double life;
  final double size;
}

class _SpeedGaugeState extends State<SpeedGauge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _anim = _GaugeAnim();

  Duration _last = Duration.zero;
  double _clock = 0; // absolute time, seconds
  double _orbit = 0; // orbital phase
  double _display = 0; // smoothed fraction of the scale
  double _revStart = -1; // when the sweep started
  bool _prevActive = false;
  late Color _color = widget.color ?? AppColors.sun;

  // The fast-line show: both ease in and out rather than switch.
  double _glow = 0;
  double _warp = 0;
  double _shockAt = -1;
  bool _wasWarp = false;
  double _sparkDebt = 0;
  final List<_Spark> _sparks = [];
  final math.Random _rnd = math.Random();

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

    final target = widget.scale.fractionOf(widget.value);
    _display += (target - _display) * (1 - math.exp(-dtc * 6));

    // Sweep the ray when a test starts: a quick 0 → 1 → actual value.
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

    _animateShow(dtc, shown);

    // Corona rotation: barely creeping at rest, a vortex at full speed.
    _orbit += dtc * (0.05 + shown * 1.6);
    // Ease the colour across phase changes (download ↔ upload).
    _color = Color.lerp(
        _color, widget.color ?? AppColors.sun, 1 - math.exp(-dtc * 5))!;

    _anim.update(shown, _orbit, shown, widget.active, _color, widget.scale);
  }

  /// Glow, sparks, shockwave and gold: only while a test runs and the needle
  /// is past [glowMbps] / [warpMbps].
  void _animateShow(double dt, double fraction) {
    final mbps = widget.active ? widget.value : 0.0;
    _glow += ((mbps >= glowMbps ? 1.0 : 0.0) - _glow) * (1 - math.exp(-dt * 4));
    _warp += ((mbps >= warpMbps ? 1.0 : 0.0) - _warp) * (1 - math.exp(-dt * 3));

    final inWarp = mbps >= warpMbps;
    if (inWarp && !_wasWarp) _shockAt = _clock;
    _wasWarp = inWarp;

    // Sparks: a steady stream past 100 Mbps, a fountain past 500.
    if (mbps >= glowMbps) _sparkDebt += dt * (16 + 70 * _warp);
    final a = _GaugePainter.startAngle + _GaugePainter.sweepAngle * fraction;
    final dir = Offset(math.cos(a), math.sin(a));
    final tangent = Offset(-dir.dy, dir.dx);
    while (_sparkDebt >= 1) {
      _sparkDebt -= 1;
      final out = 0.25 + _rnd.nextDouble() * (0.5 + 0.6 * _warp);
      final side = (_rnd.nextDouble() - 0.5) * 0.7;
      _sparks.add(_Spark(
        dir * 0.95,
        dir * out + tangent * side,
        0.5 + _rnd.nextDouble() * 0.6,
        1.0 + _rnd.nextDouble() * (1.4 + _warp),
      ));
    }
    for (final s in _sparks) {
      s.age += dt;
      s.pos += s.vel * dt;
      s.vel *= 1 - 1.4 * dt; // air drag: they slow as they fade
    }
    _sparks.removeWhere((s) => s.age >= s.life);

    final shock = _shockAt < 0 ? -1.0 : (_clock - _shockAt) / 1.2;
    if (shock > 1) _shockAt = -1;
    _anim.show(_glow, _warp, _sparks, shock, _clock);
  }

  @override
  void didUpdateWidget(covariant SpeedGauge old) {
    super.didUpdateWidget(old);
    if (widget.paused && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isActive) {
      _last = Duration.zero; // otherwise dt would jump by the whole pause
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _GaugePainter(_anim),
        child: Center(child: _GoldOnWarp(anim: _anim, child: widget.child)),
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
  GaugeScale scale = GaugeScale.standard;
  double glow = 0;
  double warp = 0;
  List<_Spark> sparks = const [];

  /// 0..1 through the shockwave, or below 0 when there is none.
  double shock = -1;
  double clock = 0;

  /// Set before [update], which repaints.
  void show(double g, double w, List<_Spark> s, double sh, double c) {
    glow = g;
    warp = w;
    sparks = s;
    shock = sh;
    clock = c;
  }

  void update(double f, double o, double s, bool a, Color c, GaugeScale sc) {
    fraction = f;
    orbit = o;
    speed = s;
    active = a;
    color = c;
    scale = sc;
    notifyListeners();
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.anim) : super(repaint: anim);

  final _GaugeAnim anim;

  static const _startDeg = 135.0;
  static const _sweepDeg = 270.0;
  static const startAngle = _startDeg * math.pi / 180;
  static const sweepAngle = _sweepDeg * math.pi / 180;

  /// Orbiting particle count: 12 at rest, 64 at full speed — during a test a
  /// dense corona spins up around the scale.
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

    // Scale track.
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

    _drawScale(canvas, center, radius, start, sweep, f);
    _drawShockwave(canvas, center, radius);

    // Past 100 Mbps the filled part glows from beneath.
    if (anim.glow > 0.01) {
      canvas.drawArc(
        rect,
        start,
        sweep * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 + 12 * anim.glow
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(baseColor, Colors.white, 0.25 * anim.warp)!
              .withValues(alpha: (0.40 + 0.25 * anim.warp) * anim.glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 10 * anim.glow),
      );
    }

    // Filled part of the scale.
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
    _drawSparks(canvas, center, radius, baseColor);
  }

  void _drawSparks(Canvas canvas, Offset center, double radius, Color color) {
    if (anim.sparks.isEmpty) return;
    final paint = Paint();
    final hot = Color.lerp(color, Colors.white, 0.35 + 0.4 * anim.warp)!;
    for (final s in anim.sparks) {
      final left = 1 - s.age / s.life;
      paint.color = Color.lerp(color, hot, left)!.withValues(alpha: left.clamp(0.0, 1.0));
      canvas.drawCircle(center + s.pos * radius, s.size * (0.4 + 0.6 * left), paint);
    }
  }

  /// One ring bursting outwards as the needle crosses 500 Mbps.
  void _drawShockwave(Canvas canvas, Offset center, double radius) {
    final t = anim.shock;
    if (t < 0 || t > 1) return;
    final ease = 1 - math.pow(1 - t, 3).toDouble();
    canvas.drawCircle(
      center,
      radius * (1.0 + 1.4 * ease),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 10 * (1 - t)
        ..color = Color.lerp(AppColors.sun, Colors.white, 0.5)!.withValues(alpha: 0.7 * (1 - t))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 6 * t),
    );
  }

  /// The numbered marks, with a short tick halfway between each pair. Marks
  /// the needle has passed light up; the rest stay dim.
  void _drawScale(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    double f,
  ) {
    final scale = anim.scale;
    final marks = scale.marks;
    final major = Paint()..strokeWidth = 1.8;
    final minor = Paint()
      ..strokeWidth = 1.2
      ..color = AppColors.onGlass.withValues(alpha: 0.10);
    final fontSize = (radius * 0.072).clamp(9.0, 13.0);

    for (var i = 0; i < marks.length; i++) {
      final at = scale.markFraction(i);
      final passed = f >= at - 0.001;
      final a = start + sweep * at;
      final d = Offset(math.cos(a), math.sin(a));

      major.color = passed
          ? AppColors.onGlass.withValues(alpha: 0.55)
          : AppColors.onGlass.withValues(alpha: 0.22);
      canvas.drawLine(center + d * (radius - 12), center + d * (radius - 1), major);

      if (i < marks.length - 1) {
        final mid = start + sweep * (at + scale.markFraction(1) / 2);
        final m = Offset(math.cos(mid), math.sin(mid));
        canvas.drawLine(center + m * (radius - 6), center + m * (radius - 1), minor);
      }

      final text = TextPainter(
        text: TextSpan(
          text: GaugeScale.label(marks[i]),
          style: TextStyle(
            color: passed ? AppColors.textMid : AppColors.textLo,
            fontSize: fontSize,
            fontWeight: passed ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Just inside the ticks, centred on the mark's direction.
      final at2 = center + d * (radius - 16 - fontSize * 1.1);
      text.paint(canvas, at2 - Offset(text.width / 2, text.height / 2));
    }
  }

  /// A thin pointer ray from the centre to the current scale position.
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

    // The ray fades toward the centre: bright at the scale, gone at the hub.
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

    // A tiny cap at the tip — the only glow on the dial.
    canvas.drawCircle(
      to,
      3.0 + 1.5 * speed,
      Paint()..color = Color.lerp(color, Colors.white, 0.6)!,
    );

    // Hub.
    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = AppColors.onGlass.withValues(alpha: 0.5),
    );
  }

  /// Particles on circular orbits around the dial. Higher speed means more
  /// of them and a denser ring.
  void _drawOrbiters(
      Canvas canvas, Offset center, double radius, double speed) {
    final count =
        (_minOrbiters + (_maxOrbiters - _minOrbiters) * speed).round();
    final paint = Paint();

    for (var i = 0; i < count; i++) {
      // Rings at different radii — simple but convincing depth.
      final ring = i % 4;
      final rr = radius * (1.09 + ring * 0.065);
      // Outer rings lag behind, like real orbits (farther = slower).
      final rate = 1.0 - ring * 0.17;
      final ang = anim.orbit * rate * math.pi * 2 + i * 2.399; // golden angle
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * rr;

      // Yellow like a solar corona; outer rings are paler.
      paint.color = AppColors.sun
          .withValues(alpha: (0.35 + 0.45 * speed) * (1.0 - ring * 0.17));
      canvas.drawCircle(pos, 1.5 + 1.2 * speed, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => false;
}

/// Past 500 Mbps the number and its labels turn shimmering gold.
class _GoldOnWarp extends StatelessWidget {
  const _GoldOnWarp({required this.anim, required this.child});

  final _GaugeAnim anim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: anim,
      builder: (context, _) {
        if (anim.warp < 0.3) return child;
        // A bright band sweeping across, once a second and a half.
        final sweep = (anim.clock / 1.5) % 1.0;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [Color(0xFFFFB300), Color(0xFFFFE082), Colors.white, Color(0xFFFFE082), Color(0xFFFFB300)],
            stops: [
              0,
              (sweep - 0.15).clamp(0.0, 1.0),
              sweep,
              (sweep + 0.15).clamp(0.0, 1.0),
              1,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
