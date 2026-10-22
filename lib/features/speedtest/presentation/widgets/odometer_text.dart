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

    final offsets = odometerOffsets(scaled, totalWheels);
    final children = <Widget>[];
    for (var p = totalWheels - 1; p >= 0; p--) {
      if (p == decimals - 1) {
        children.add(Text('.', style: widget.style));
      }
      children.add(_reel(offsets[p], h, w));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
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

/// Wheel positions for [scaled], lowest wheel first.
///
/// Each wheel shows a crisp digit. The lowest one rolls only through the last
/// 20% before it ticks over, and a higher wheel turns only while every wheel
/// below it is passing from 9 to 0 — the way a mechanical odometer carries.
///
/// Deriving a wheel's roll from all the digits below it instead (8.9 for the
/// hundreds of 890) left the leading digit stuck half-turned on any value
/// whose next digit was 8 or 9: 89.0 showed a half-rolled 8, 18.4 a raised 1.
@visibleForTesting
List<double> odometerOffsets(double scaled, int wheels) {
  final whole = scaled.floorToDouble();
  final frac = scaled - whole;
  var roll = frac <= 0.8 ? 0.0 : (frac - 0.8) / 0.2;

  final offsets = <double>[];
  for (var p = 0; p < wheels; p++) {
    final digit = (whole / math.pow(10, p)).floor() % 10;
    offsets.add(digit + roll);
    // The next wheel only moves while this one rolls from 9 to 0.
    if (digit != 9) roll = 0;
  }
  return offsets;
}
