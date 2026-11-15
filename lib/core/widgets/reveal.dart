import 'package:material_ui/material_ui.dart';

/// Brings [child] into view the first time it scrolls into sight: it rises
/// a little, tilts up from a slight 3D lean and fades in. [delay] staggers
/// cards that appear together, so a row of them arrives one after another.
///
/// Shown at once when the system asks for reduced motion.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _motion = Duration(milliseconds: 720);

  // The delay is part of the animation rather than a timer: nothing is left
  // pending when the page goes away mid-way.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _motion + widget.delay,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / (_motion + widget.delay).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  ScrollPosition? _position;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    if (MediaQuery.of(context).disableAnimations) {
      _start(animate: false);
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position?..addListener(_check);
    }
    // Whatever is on screen when the page opens comes in straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.94) _start(animate: true);
  }

  void _start({required bool animate}) {
    _started = true;
    _position?.removeListener(_check);
    _position = null;
    if (animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          // Settled, the transform is the identity, which costs nothing —
          // but it stays: dropping it would change the tree and rebuild
          // the card from scratch, state and all.
          final away = 1 - _progress.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..translateByDouble(0, 44 * away, 0, 1)
              ..rotateX(0.32 * away)
              ..scaleByDouble(1 - 0.04 * away, 1 - 0.04 * away, 1, 1),
            child: child,
          );
        },
      ),
    );
  }
}
