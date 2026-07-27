import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/throttle_engine.dart';
import '../domain/throttle_result.dart';

/// Состояние проверки на троттлинг.
class ThrottleState {
  const ThrottleState({this.result, this.running = false, this.error});

  final ThrottleResult? result;
  final bool running;
  final String? error;
}

final throttleProvider =
    NotifierProvider<ThrottleNotifier, ThrottleState>(ThrottleNotifier.new);

class ThrottleNotifier extends Notifier<ThrottleState> {
  ThrottleEngine? _engine;

  @override
  ThrottleState build() {
    ref.onDispose(() => _engine?.cancel());
    return const ThrottleState();
  }

  Future<void> run() async {
    if (state.running) return;
    state = const ThrottleState(running: true);

    final engine = _engine = ThrottleEngine();
    try {
      final result = await engine.run();
      state = ThrottleState(result: result);
    } catch (e) {
      state = ThrottleState(error: '$e');
    } finally {
      _engine = null;
    }
  }
}
