import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true, когда окно на виду и в фокусе — то есть анимации имеет смысл рисовать.
///
/// Спидометр и звёздный фон перерисовываются 60 раз в секунду; когда окно
/// свёрнуто в трей или ушло в фон, это впустую тратит батарею. Виджеты
/// подписываются на этот провайдер и останавливают свои [Ticker].
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
    // Параметр перекрывает поле Notifier.state, поэтому к нему — через this.
    final active = _isActive(state);
    if (active != this.state) this.state = active;
  }

  /// resumed — окно видно и в фокусе. inactive/hidden/paused/detached —
  /// свёрнуто, перекрыто или ушло в фон: анимации не нужны.
  bool _isActive(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed;
}
