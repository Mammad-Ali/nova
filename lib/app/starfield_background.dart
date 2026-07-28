import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_activity.dart';
import '../core/theme/app_theme.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/traffic_monitor/presentation/providers/traffic_provider.dart';

/// Живой фон Nova: чёрное небо, три слоя белых звёзд с параллаксом плюс
/// белые частицы, вращающиеся вокруг центра по орбитальной механике.
///
/// Физика: на каждую частицу действует притяжение к центру `a = GM/r²`,
/// интегрирование полуявным методом Эйлера. Курсор работает как источник
/// отталкивания, поэтому вокруг него образуется «пузырь» пустоты.
/// Скорость интернета делает частицы ярче, но цвета на фоне нет.
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
    // Пока окно свёрнуто или не в фокусе — не жжём батарею на невидимых кадрах.
    final active = ref.watch(uiActiveProvider);
    if (active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }

    // Уровень «энергии»: во время теста — стрелка спидометра, иначе трафик.
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

// ─────────────────────────── симуляция ───────────────────────────

/// Звезда фонового слоя. Позиция нормирована (0..1), чтобы переживать
/// изменение размера окна.
class _Star {
  _Star(this.x, this.y, this.size, this.twinkleRate, this.phase, this.layer);

  final double x, y;
  final double size;
  final double twinkleRate;
  final double phase;

  /// 0 — самый дальний слой, 2 — ближний. Задаёт скорость параллакса.
  final int layer;
}

/// Частица на орбите. Координаты и скорость — в пикселях.
class _Orbiter {
  _Orbiter(this.pos, this.vel, this.mass, this.hueShift);

  Offset pos;
  Offset vel;
  final double mass;

  /// Небольшой сдвиг по палитре, чтобы частицы не были одного цвета.
  final double hueShift;
}

class _SpaceSim extends ChangeNotifier {
  // Плотное звёздное небо: столько объектов просил пользователь.
  static const _starCount = 250;
  static const _orbiterCount = 80;

  /// Гравитационный параметр (GM). Подобран так, чтобы оборот на средней
  /// орбите занимал ~10-20 секунд: движение заметное, но спокойное.
  static const _gm = 26000.0;

  /// Смягчение в знаменателе: не даёт ускорению уйти в бесконечность,
  /// когда частица подходит вплотную к центру.
  static const _softening = 40.0;

  /// Сила и радиус отталкивания от курсора.
  static const _cursorPush = 42000.0;
  static const _cursorRadius = 130.0;

  final math.Random _rnd = math.Random(11);
  final List<_Star> stars = [];
  final List<_Orbiter> orbiters = [];

  Size _size = Size.zero;
  double time = 0;
  double level = 0;
  Offset? cursor;

  /// Накопленный дрейф слоёв. Интегрируем по dt (а не считаем как
  /// время × скорость) — иначе при смене скорости звёзды прыгают.
  double drift = 0;

  _SpaceSim() {
    for (var i = 0; i < _starCount; i++) {
      final layer = i % 3; // равномерно по трём слоям глубины
      final big = _rnd.nextDouble() < 0.12;
      stars.add(_Star(
        _rnd.nextDouble(),
        _rnd.nextDouble(),
        (big ? 1.5 + _rnd.nextDouble() * 1.4 : 0.5 + _rnd.nextDouble() * 0.9) *
            (0.7 + layer * 0.25), // ближние слои крупнее
        0.4 + _rnd.nextDouble() * 2.0,
        _rnd.nextDouble() * math.pi * 2,
        layer,
      ));
    }
  }

  /// Скорость дрейфа слоя — основа параллакса: дальние почти стоят.
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
        // Притяжение к центру: a = GM / (r² + soft²), направлено к центру.
        final toCenter = center - o.pos;
        final r2 = toCenter.distanceSquared + _softening * _softening;
        final invR = 1.0 / math.sqrt(r2);
        final accMag = _gm / r2;
        var ax = toCenter.dx * invR * accMag;
        var ay = toCenter.dy * invR * accMag;

        // Курсор расталкивает частицы: a = k / (d² + soft), от курсора.
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

        // Полуявный метод Эйлера: сначала скорость, потом позиция — он
        // устойчивее обычного Эйлера и не «раскручивает» круговые орбиты.
        o.vel = Offset(o.vel.dx + ax * dt, o.vel.dy + ay * dt);
        o.pos = o.pos + o.vel * dt;

        // Мягко возвращаем улетевшие частицы, чтобы поле не пустело.
        final dist = (o.pos - center).distance;
        if (dist > maxR) {
          final back = (center - o.pos) / dist;
          o.vel = o.vel * 0.9 + back * 40;
        }
      }
    }

    notifyListeners();
  }

  /// Раскладывает частицы по орбитам под размер холста.
  void resize(Size size) {
    if (size.isEmpty || (size == _size && orbiters.isNotEmpty)) return;
    _size = size;
    if (orbiters.isNotEmpty) return; // при ресайзе орбиты не пересоздаём

    final center = Offset(size.width / 2, size.height * 0.42);
    final minR = size.shortestSide * 0.16;
    final maxR = size.shortestSide * 0.52;

    for (var i = 0; i < _orbiterCount; i++) {
      final angle = _rnd.nextDouble() * math.pi * 2;
      final radius = minR + _rnd.nextDouble() * (maxR - minR);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;

      // Круговая скорость v = sqrt(GM/r), перпендикулярно радиусу.
      // Разброс множителя даёт эллипсы вместо идеальных окружностей.
      final v = math.sqrt(_gm / radius) * (0.88 + _rnd.nextDouble() * 0.24);
      final dir = _rnd.nextBool() ? 1.0 : -1.0; // часть летит в обратную сторону
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

// ─────────────────────────── отрисовка ───────────────────────────

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.sim) : super(repaint: sim);

  final _SpaceSim sim;

  @override
  void paint(Canvas canvas, Size size) {
    sim.resize(size);

    // Чистый чёрный фон — как настоящее ночное небо.
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg0);

    _drawStars(canvas, size);
    _drawOrbiters(canvas, size);
  }

  /// Три слоя звёзд: дальние почти неподвижны, ближние заметно плывут.
  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sim.stars) {
      final speed = _SpaceSim.layerSpeed(s.layer);
      final y = ((s.y - sim.drift * speed) % 1.0 + 1.0) % 1.0;

      final tw = 0.55 + 0.45 * math.sin(sim.time * s.twinkleRate + s.phase);
      // Дальние слои тусклее — это и создаёт ощущение глубины.
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

  /// Частицы на орбитах. Цвет — по текущей скорости интернета.
  void _drawOrbiters(Canvas canvas, Size size) {
    final paint = Paint();
    for (final o in sim.orbiters) {
      // Частицы белые, как звёзды: цвета на фоне нет вообще.
      final alpha = (0.35 + 0.35 * sim.level) * o.mass;
      paint.color = AppColors.starColor.withValues(alpha: alpha.clamp(0.0, 0.95));
      canvas.drawCircle(o.pos, 1.1 + 1.5 * o.mass, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}
