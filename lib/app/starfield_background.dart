import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_activity.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/speedtest/presentation/widgets/speed_gauge.dart' show warpMbps;
import '../features/traffic_monitor/presentation/providers/traffic_provider.dart';

/// Nova's living backdrop: a black sky, three parallax layers of white stars
/// and white particles orbiting the centre under real orbital mechanics.
///
/// Physics: every particle is pulled toward the centre by `a = GM/r²`,
/// integrated with semi-implicit Euler. The cursor acts as a repulsor, so a
/// bubble of empty space follows it. Connection speed only brightens the
/// particles — the backdrop itself stays colourless — until a test passes
/// 500 Mbps: then the stars go to warp speed, streaking out from the centre.
///
/// In the apps the sky can be 3D instead (Settings → Animations): stars in
/// a volume, flying toward the viewer in perspective — faster with the
/// speed, streaking at warp — while the camera leans toward the mouse (or a
/// finger on a phone), so near stars slide more than far ones.
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
    final speedFrac = st.scale.fractionOf(st.displayMbps);
    final hist = ref.watch(trafficHistoryProvider);
    final rate = (hist.currentRxPerSec + hist.currentTxPerSec).toDouble();
    final trafficFrac = (rate / (12.5 * 1024 * 1024)).clamp(0.0, 1.0);
    _sim.level = math.max(speedFrac, trafficFrac).toDouble();
    _sim.warpTarget = st.isRunning && st.displayMbps >= warpMbps ? 1 : 0;
    final threeD = !kIsWeb && ref.watch(appSettingsProvider.select((s) => s.starfield3d));
    _sim.depthTarget = threeD ? 1 : 0;

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
/// A star in the 3D sky: x and y across, z the distance from the viewer
/// (1 far, 0 at the eye). It flies toward the viewer and starts again far
/// away when it passes.
class _Star3 {
  _Star3(this.x, this.y, this.z, this.size, this.twinkleRate, this.phase);

  double x, y, z;
  final double size;
  final double twinkleRate;
  final double phase;
}

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
  final List<_Star3> stars3 = [];

  static const _star3Count = 420;

  /// How 3D the sky is, 0 flat to 1: eased towards [depthTarget] so
  /// switching fades from one sky to the other.
  double depth = 0;
  double depthTarget = 0;

  /// How fast the 3D stars come, in depth per second, and where the camera
  /// looks: -1..1 on each axis, eased towards the mouse.
  double flight = 0.06;
  Offset look = Offset.zero;

  Size _size = Size.zero;
  double time = 0;
  double level = 0;
  Offset? cursor;

  /// Warp speed: eased towards [warpTarget] so the jump in and out is smooth.
  double warp = 0;
  double warpTarget = 0;

  /// Advances only while in warp, so each jump picks up where the last left.
  double warpClock = 0;

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

  _Star3 _newStar3(double z) => _Star3(
        (_rnd.nextDouble() * 2 - 1) * 1.6,
        (_rnd.nextDouble() * 2 - 1) * 1.1,
        z,
        _rnd.nextDouble() < 0.1 ? 1.6 + _rnd.nextDouble() * 1.2 : 0.6 + _rnd.nextDouble() * 0.8,
        0.4 + _rnd.nextDouble() * 2.0,
        _rnd.nextDouble() * math.pi * 2,
      );

  void _step3d(double dt) {
    if (stars3.isEmpty) {
      for (var i = 0; i < _star3Count; i++) {
        stars3.add(_newStar3(0.04 + _rnd.nextDouble() * 0.96));
      }
    }
    // A slow drift at rest; the connection's speed and warp push it on.
    flight = 0.06 + 0.42 * level + 2.4 * warp;
    for (var i = 0; i < stars3.length; i++) {
      final s = stars3[i];
      s.z -= flight * dt;
      if (s.z <= 0.035) stars3[i] = _newStar3(1 + _rnd.nextDouble() * 0.04);
    }
    // The camera leans toward the cursor, and back to the middle without it.
    final c = cursor;
    final target = c == null || _size == Size.zero
        ? Offset.zero
        : Offset(c.dx / _size.width * 2 - 1, c.dy / _size.height * 2 - 1);
    look += (target - look) * (1 - math.exp(-dt * 2.2));
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
    warp += (warpTarget - warp) * (1 - math.exp(-dt * 2.5));
    depth += (depthTarget - depth) * (1 - math.exp(-dt * 2.0));
    if (depth > 0.001) _step3d(dt);
    if (warp > 0.001) warpClock += dt * (0.3 + 0.9 * warp);

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

    if (sim.depth < 0.999) _drawStars(canvas, size, 1 - sim.depth);
    if (sim.depth > 0.001) _drawStars3d(canvas, size, sim.depth);
    _drawOrbiters(canvas, size);
  }

  /// Three star layers: far ones nearly still, near ones visibly drifting.
  /// In warp every star flies out from the centre along its own ray, nearer
  /// layers faster, trailing a streak that grows as it comes closer.
  void _drawStars(Canvas canvas, Size size, double opacity) {
    final paint = Paint();
    final streak = Paint()..strokeCap = StrokeCap.round;
    final warp = sim.warp;
    final center = Offset(size.width / 2, size.height * 0.42);
    for (final s in sim.stars) {
      final speed = _SpaceSim.layerSpeed(s.layer);
      final y = ((s.y - sim.drift * speed) % 1.0 + 1.0) % 1.0;
      final base = Offset(s.x * size.width, y * size.height);

      final tw = 0.55 + 0.45 * math.sin(sim.time * s.twinkleRate + s.phase);
      // Far layers are dimmer — that is what sells the depth.
      final depth = 0.45 + 0.275 * s.layer;

      if (warp < 0.01) {
        paint.color =
            AppColors.starColor.withValues(alpha: (0.30 + 0.55 * tw) * depth * opacity);
        canvas.drawCircle(base, s.size * (0.9 + 0.2 * tw), paint);
        continue;
      }

      final rel = base - center;
      final t = (sim.warpClock * (0.35 + 0.5 * speed) + s.phase / (2 * math.pi)) % 1.0;
      final out = 0.08 + t * t * 1.9; // accelerating outwards
      final trail = math.max(0.0, out - (0.05 + 0.3 * t) * (0.6 + speed));
      final head = Offset.lerp(base, center + rel * out, warp)!;
      final tail = Offset.lerp(base, center + rel * trail, warp)!;
      // Each streak fades in as it leaves the centre, so they don't knot
      // into a burst behind the number.
      final emerge = ((out - 0.08) / 0.45).clamp(0.0, 1.0);
      streak
        ..color = AppColors.starColor.withValues(alpha: ((0.35 + 0.6 * t) * depth * emerge * opacity).clamp(0.0, 1.0))
        ..strokeWidth = s.size * (0.6 + 1.3 * t);
      canvas.drawLine(tail, head, streak);
    }
  }

  /// The 3D sky: each star projected through a camera at the eye, so a
  /// near star is bigger, brighter and moves faster across the screen. The
  /// camera sits a little off centre toward the mouse — near stars slide
  /// more than far ones. Fast enough, a star leaves a streak: where it was a
  /// moment ago, joined to where it is.
  void _drawStars3d(Canvas canvas, Size size, double opacity) {
    final paint = Paint();
    final streak = Paint()..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height * 0.42);
    final focal = size.shortestSide * 0.55;
    final camera = Offset(sim.look.dx * 0.22, sim.look.dy * 0.14);
    // How far back along its path the streak reaches, in depth.
    final trail = sim.flight * 0.05;

    Offset project(double x, double y, double z) =>
        center + Offset((x - camera.dx) / z * focal, (y - camera.dy) / z * focal);

    for (final s in sim.stars3) {
      final head = project(s.x, s.y, s.z);
      if (head.dx < -40 || head.dx > size.width + 40 || head.dy < -40 || head.dy > size.height + 40) continue;
      final near = 1 - s.z;
      final tw = 0.7 + 0.3 * math.sin(sim.time * s.twinkleRate + s.phase);
      // Born far away and faint, so none pops in.
      final appear = ((1.0 - s.z) / 0.3).clamp(0.0, 1.0);
      final alpha = ((0.18 + 0.82 * near) * tw * appear * opacity).clamp(0.0, 1.0);
      final radius = (s.size * 0.16 / s.z).clamp(0.35, 3.4);

      final tail = project(s.x, s.y, s.z + trail);
      if ((head - tail).distanceSquared > 2.5) {
        streak
          ..color = AppColors.starColor.withValues(alpha: alpha)
          ..strokeWidth = radius * 1.2;
        canvas.drawLine(tail, head, streak);
      } else {
        paint.color = AppColors.starColor.withValues(alpha: alpha);
        canvas.drawCircle(head, radius, paint);
      }
    }
  }

  /// Orbiting particles. Brightness follows the current connection speed.
  void _drawOrbiters(Canvas canvas, Size size) {
    final paint = Paint();
    for (final o in sim.orbiters) {
      // Particles are white like the stars: no colour on the backdrop at all.
      // They make way for the streaks in warp.
      final alpha = (0.35 + 0.35 * sim.level) * o.mass * (1 - 0.7 * sim.warp);
      paint.color = AppColors.starColor.withValues(alpha: alpha.clamp(0.0, 0.95));
      canvas.drawCircle(o.pos, 1.1 + 1.5 * o.mass, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}
