import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_theme.dart';

/// Управляет запуском салюта конфетти.
class ConfettiController extends ChangeNotifier {
  int token = 0;
  void fire() {
    token++;
    notifyListeners();
  }
}

/// Полноэкранный слой конфетти. Играет короткий залп при каждом [ConfettiController.fire].
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.controller});
  final ConfettiController controller;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Confetto> _parts = [];
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final math.Random _rnd = math.Random();
  Duration _last = Duration.zero;
  int _seen = 0;

  static const _colors = [
    AppColors.auroraGreen,
    AppColors.auroraTeal,
    AppColors.auroraViolet,
    AppColors.amber,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    widget.controller.addListener(_onFire);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFire);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onFire() {
    if (widget.controller.token == _seen) return;
    _seen = widget.controller.token;
    _spawn();
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _spawn() {
    for (var i = 0; i < 90; i++) {
      final angle = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 2.2;
      final speed = 0.5 + _rnd.nextDouble() * 0.8;
      _parts.add(_Confetto(
        pos: Offset(0.5 + (_rnd.nextDouble() - 0.5) * 0.2, 0.32),
        vel: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        rot: _rnd.nextDouble() * math.pi,
        spin: (_rnd.nextDouble() - 0.5) * 12,
        life: 1.8 + _rnd.nextDouble() * 1.0,
        maxLife: 2.8,
        color: _colors[_rnd.nextInt(_colors.length)],
        size: 6 + _rnd.nextDouble() * 7,
      ));
    }
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    const g = 1.5;

    for (final c in _parts) {
      c.vel = Offset(c.vel.dx * 0.99, c.vel.dy + g * dt);
      c.pos = c.pos + c.vel * dt;
      c.rot += c.spin * dt;
      c.life -= dt;
    }
    _parts.removeWhere((c) => c.life <= 0 || c.pos.dy > 1.2);
    _frame.value++;

    if (_parts.isEmpty) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_parts, _frame),
      ),
    );
  }
}

class _Confetto {
  _Confetto({
    required this.pos,
    required this.vel,
    required this.rot,
    required this.spin,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.size,
  });

  Offset pos; // нормированные координаты 0..1
  Offset vel;
  double rot;
  double spin;
  double life;
  final double maxLife;
  final Color color;
  final double size;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts, Listenable repaint) : super(repaint: repaint);
  final List<_Confetto> parts;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in parts) {
      final alpha = (c.life / c.maxLife).clamp(0.0, 1.0);
      final p = Offset(c.pos.dx * size.width, c.pos.dy * size.height);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(c.rot);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: c.size, height: c.size * 0.6),
        Paint()..color = c.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => false;
}
