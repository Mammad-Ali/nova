import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A number that rolls like a mechanical odometer: when the value changes,
/// the digit wheels spin up from zero to the final figure.
class OdometerText extends StatefulWidget {
  const OdometerText({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 1,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final int decimals;
  final TextStyle style;
  final Duration duration;

  @override
  State<OdometerText> createState() => _OdometerTextState();
}

class _OdometerTextState extends State<OdometerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value;
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant OdometerText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _current();
      _to = widget.value;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _current() =>
      lerpDouble(_from, _to, Curves.easeOutCubic.transform(_c.value)) ?? _to;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => _reels(math.max(0, _current())),
    );
  }

  Widget _reels(double v) {
    if (!v.isFinite) v = 0;
    final decimals = widget.decimals;
    final scaled = v * math.pow(10, decimals);
    final fontSize = widget.style.fontSize ?? 26;
    final h = fontSize * 1.18;
    final w = fontSize * 0.62;

    // Wheel count comes from the target value (guarding against inf/NaN).
    final safeTo = _to.isFinite ? _to : 0.0;
    final intDigits =
        math.max(1, (math.log(math.max(safeTo, 1)) / math.ln10).floor() + 1)
            .clamp(1, 7);
    final totalWheels = intDigits + decimals;

    final children = <Widget>[];
    for (var p = totalWheels - 1; p >= 0; p--) {
      if (p == decimals - 1) {
        children.add(Text('.', style: widget.style));
      }
      children.add(_reel(_offset(scaled, p), h, w));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Offset of wheel p: a crisp digit, rolling only through the last 20%
  /// before it increments — the way a real odometer behaves.
  double _offset(double scaled, int p) {
    final raw = scaled / math.pow(10, p);
    final base = raw.floorToDouble();
    final frac = raw - base;
    final roll = frac <= 0.8 ? 0.0 : (frac - 0.8) / 0.2;
    return (base % 10) + roll;
  }

  Widget _reel(double offset, double h, double w) {
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, -offset * h),
            child: Column(
              children: [
                for (var i = 0; i < 11; i++)
                  SizedBox(
                    width: w,
                    height: h,
                    child: Center(
                      child: Text('${i % 10}', style: widget.style),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
