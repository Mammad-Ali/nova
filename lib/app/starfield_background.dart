import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_activity.dart';
import '../core/theme/app_theme.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/traffic_monitor/presentation/providers/traffic_provider.dart';

/// Nova's living backdrop: a black sky, three parallax layers of white stars
/// and white particles orbiting the centre under real orbital mechanics.
///
/// Physics: every particle is pulled toward the centre by `a = GM/r²`,
/// integrated with semi-implicit Euler. The cursor acts as a repulsor, so a
/// bubble of empty space follows it. Connection speed only brightens the
/// particles — the backdrop itself stays colourless.
class StarfieldBackground extends ConsumerStatefulWidget {
  const StarfieldBackground({super.key});

  @override
  ConsumerState<StarfieldBackground> createState() =>
      _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends ConsumerState<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _SpaceSim();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _sim.step(dt.clamp(0.0, 0.05));
  }

  @override
  Widget build(BuildContext context) {
    // While the window is hidden or unfocused, don't burn battery on frames
    // nobody sees.
    final active = ref.watch(uiActiveProvider);
    if (active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }

    // Energy level: the gauge value during a test, live traffic otherwise.
    final st = ref.watch(speedTestControllerProvider);
    final speedFrac =
        st.gaugeMax > 0 ? (st.displayMbps / st.gaugeMax).clamp(0.0, 1.0) : 0.0;
    final hist = ref.watch(trafficHistoryProvider);
    final rate = (hist.currentRxPerSec + hist.currentTxPerSec).toDouble();
    final trafficFrac = (rate / (12.5 * 1024 * 1024)).clamp(0.0, 1.0);
    _sim.level = math.max(speedFrac, trafficFrac).toDouble();

    return Positioned.fill(
      child: MouseRegion(
        opaque: false,
        onHover: (e) => _sim.cursor = e.localPosition,
        onExit: (_) => _sim.cursor = null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (e) => _sim.cursor = e.localPosition,
          onPointerUp: (_) => _sim.cursor = null,
          child: RepaintBoundary(
            child: CustomPaint(painter: _SpacePainter(_sim)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── simulation ──────────────────────────

/// A star in a backdrop layer. The position is normalised (0..1) so it
/// survives window resizes.
class _Star {
  _Star(this.x, this.y, this.size, this.twinkleRate, this.phase, this.layer);

  final double x, y;
  final double size;
  final double twinkleRate;
  final double phase;

  /// 0 is the farthest layer, 2 the nearest. Drives the parallax speed.
  final int layer;
}

/// An orbiting particle. Position and velocity are in pixels.
class _Orbiter {
  _Orbiter(this.pos, this.vel, this.mass, this.hueShift);

  Offset pos;
  Offset vel;
  final double mass;

  /// A small palette offset so particles don't share one exact shade.
  final double hueShift;
}

class _SpaceSim extends ChangeNotifier {
  // A dense sky: these counts were chosen for the current design.
  static const _starCount = 250;
  static const _orbiterCount = 80;

  /// Gravitational parameter (GM), tuned so a mid orbit takes ~10-20 seconds:
  /// the motion reads as alive without being busy.
  static const _gm = 26000.0;

  /// Softening term: keeps acceleration finite when a particle passes very
  /// close to the centre.
  static const _softening = 40.0;

  /// Strength and radius of the cursor's repulsion.
  static const _cursorPush = 42000.0;
  static const _cursorRadius = 130.0;

  final math.Random _rnd = math.Random(11);
  final List<_Star> stars = [];
  final List<_Orbiter> orbiters = [];

  Size _size = Size.zero;
  double time = 0;
  double level = 0;
  Offset? cursor;

  /// Accumulated layer drift. Integrated over dt rather than computed as
  /// time × speed — otherwise stars jump whenever the speed changes.
  double drift = 0;

  _SpaceSim() {
    for (var i = 0; i < _starCount; i++) {
      final layer = i % 3; // spread evenly across three depth layers
      final big = _rnd.nextDouble() < 0.12;
      stars.add(_Star(
        _rnd.nextDouble(),
        _rnd.nextDouble(),
        (big ? 1.5 + _rnd.nextDouble() * 1.4 : 0.5 + _rnd.nextDouble() * 0.9) *
            (0.7 + layer * 0.25), // nearer layers are larger
        0.4 + _rnd.nextDouble() * 2.0,
        _rnd.nextDouble() * math.pi * 2,
        layer,
      ));
    }
  }

  /// Per-layer drift speed — the basis of the parallax: far layers barely move.
  static double layerSpeed(int layer) => switch (layer) {
        0 => 0.25,
        1 => 0.6,
        _ => 1.0,
      };

  void step(double dt) {
    time += dt;
    drift += dt * (0.006 + level * 0.02);

    if (_size != Size.zero) {
      final center = Offset(_size.width / 2, _size.height * 0.42);
      final maxR = _size.longestSide * 0.62;

      for (final o in orbiters) {
        // Pull toward the centre: a = GM / (r² + soft²).
        final toCenter = center - o.pos;
        final r2 = toCenter.distanceSquared + _softening * _softening;
        final invR = 1.0 / math.sqrt(r2);
        final accMag = _gm / r2;
        var ax = toCenter.dx * invR * accMag;
        var ay = toCenter.dy * invR * accMag;

        // The cursor pushes particles away: a = k / (d² + soft).
        final c = cursor;
        if (c != null) {
          final away = o.pos - c;
          final d = away.distance;
          if (d < _cursorRadius && d > 0.001) {
            final push = _cursorPush / (d * d + 400);
            ax += away.dx / d * push;
            ay += away.dy / d * push;
          }
        }

        // Semi-implicit Euler: velocity first, then position. It is more
        // stable than plain Euler and doesn't inflate circular orbits.
        o.vel = Offset(o.vel.dx + ax * dt, o.vel.dy + ay * dt);
        o.pos = o.pos + o.vel * dt;

        // Gently pull escapees back so the field doesn't empty out.
        final dist = (o.pos - center).distance;
        if (dist > maxR) {
          final back = (center - o.pos) / dist;
          o.vel = o.vel * 0.9 + back * 40;
        }
      }
    }

    notifyListeners();
  }

  /// Seeds particles onto orbits sized for the canvas.
  void resize(Size size) {
    if (size.isEmpty || (size == _size && orbiters.isNotEmpty)) return;
    _size = size;
    if (orbiters.isNotEmpty) return; // don't reseed orbits on resize

    final center = Offset(size.width / 2, size.height * 0.42);
    final minR = size.shortestSide * 0.16;
    final maxR = size.shortestSide * 0.52;

    for (var i = 0; i < _orbiterCount; i++) {
      final angle = _rnd.nextDouble() * math.pi * 2;
      final radius = minR + _rnd.nextDouble() * (maxR - minR);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;

      // Circular speed v = sqrt(GM/r), perpendicular to the radius.
      // Jittering the factor yields ellipses instead of perfect circles.
      final v = math.sqrt(_gm / radius) * (0.88 + _rnd.nextDouble() * 0.24);
      final dir = _rnd.nextBool() ? 1.0 : -1.0; // some orbit the other way
      final vel = Offset(-math.sin(angle), math.cos(angle)) * v * dir;

      orbiters.add(_Orbiter(
        pos,
        vel,
        0.6 + _rnd.nextDouble() * 0.8,
        _rnd.nextDouble() * 0.35,
      ));
    }
  }
}

// ─────────────────────────── painting ────────────────────────────

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.sim) : super(repaint: sim);

  final _SpaceSim sim;

  @override
  void paint(Canvas canvas, Size size) {
    sim.resize(size);

    // Pure black backdrop, like a real night sky.
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg0);

    _drawStars(canvas, size);
    _drawOrbiters(canvas, size);
  }

  /// Three star layers: far ones nearly still, near ones visibly drifting.
  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sim.stars) {
      final speed = _SpaceSim.layerSpeed(s.layer);
      final y = ((s.y - sim.drift * speed) % 1.0 + 1.0) % 1.0;

      final tw = 0.55 + 0.45 * math.sin(sim.time * s.twinkleRate + s.phase);
      // Far layers are dimmer — that is what sells the depth.
      final depth = 0.45 + 0.275 * s.layer;
      paint.color =
          AppColors.starColor.withValues(alpha: (0.30 + 0.55 * tw) * depth);
      canvas.drawCircle(
        Offset(s.x * size.width, y * size.height),
        s.size * (0.9 + 0.2 * tw),
        paint,
      );
    }
  }

  /// Orbiting particles. Brightness follows the current connection speed.
  void _drawOrbiters(Canvas canvas, Size size) {
    final paint = Paint();
    for (final o in sim.orbiters) {
      // Particles are white like the stars: no colour on the backdrop at all.
      final alpha = (0.35 + 0.35 * sim.level) * o.mass;
      paint.color = AppColors.starColor.withValues(alpha: alpha.clamp(0.0, 0.95));
      canvas.drawCircle(o.pos, 1.1 + 1.5 * o.mass, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}
