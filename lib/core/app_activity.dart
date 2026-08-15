import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the window is visible and focused — i.e. while animating is
/// worth the cost.
///
/// The gauge and the starfield repaint 60 times a second; once the window is
/// in the tray or in the background that is wasted battery. Widgets watch this
/// provider and stop their [Ticker]s accordingly.
final uiActiveProvider =
    NotifierProvider<UiActivityNotifier, bool>(UiActivityNotifier.new);

class UiActivityNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return _isActive(binding.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The parameter shadows Notifier.state, hence the explicit this.
    final active = _isActive(state);
    if (active != this.state) this.state = active;
  }

  /// resumed means visible and focused. inactive/hidden/paused/detached mean
  /// minimised, covered or backgrounded — no animation needed.
  bool _isActive(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed;
}
