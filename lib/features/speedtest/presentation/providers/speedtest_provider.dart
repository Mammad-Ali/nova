import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/speedtest_engine.dart';
import '../../domain/entities/speedtest_models.dart';
import '../../domain/entities/speedtest_record.dart';
import 'speedtest_history_provider.dart';

/// Иммутабельное состояние вкладки Speedtest.
class SpeedTestState {
  const SpeedTestState({
    this.phase = TestPhase.idle,
    this.displayMbps = 0,
    this.phaseProgress = 0,
    this.gaugeMax = 100,
    this.pingMs,
    this.jitterMs,
    this.downloadMbps,
    this.uploadMbps,
    this.loadedPingMs,
    this.serverName,
    this.error,
  });

  final TestPhase phase;
  final double displayMbps;
  final double phaseProgress;

  /// Верх шкалы спидометра. Растёт ступенями, никогда не «дёргается» вниз.
  final double gaugeMax;

  final double? pingMs;
  final double? jitterMs;
  final double? downloadMbps;
  final double? uploadMbps;

  /// Пинг под нагрузкой — база для оценки bufferbloat.
  final double? loadedPingMs;

  /// Сервер, на котором реально прошёл замер.
  final String? serverName;

  final String? error;

  bool get isRunning => phase.isRunning;
  bool get hasResults => downloadMbps != null || uploadMbps != null;

  SpeedTestState copyWith({
    TestPhase? phase,
    double? displayMbps,
    double? phaseProgress,
    double? gaugeMax,
    double? pingMs,
    double? jitterMs,
    double? downloadMbps,
    double? uploadMbps,
    double? loadedPingMs,
    String? serverName,
    String? error,
  }) {
    return SpeedTestState(
      phase: phase ?? this.phase,
      displayMbps: displayMbps ?? this.displayMbps,
      phaseProgress: phaseProgress ?? this.phaseProgress,
      gaugeMax: gaugeMax ?? this.gaugeMax,
      pingMs: pingMs ?? this.pingMs,
      jitterMs: jitterMs ?? this.jitterMs,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      loadedPingMs: loadedPingMs ?? this.loadedPingMs,
      serverName: serverName ?? this.serverName,
      error: error,
    );
  }

  /// Накатывает событие из движка, сохраняя уже полученные метрики.
  SpeedTestState applyProgress(SpeedTestProgress p, double gaugeMax) {
    return SpeedTestState(
      phase: p.phase,
      displayMbps: p.displayMbps,
      phaseProgress: p.phaseProgress,
      gaugeMax: gaugeMax,
      pingMs: p.pingMs ?? pingMs,
      jitterMs: p.jitterMs ?? jitterMs,
      downloadMbps: p.downloadMbps ?? downloadMbps,
      uploadMbps: p.uploadMbps ?? uploadMbps,
      loadedPingMs: p.loadedPingMs ?? loadedPingMs,
      serverName: p.serverName ?? serverName,
      error: p.error,
    );
  }
}

final speedTestControllerProvider =
    NotifierProvider<SpeedTestController, SpeedTestState>(
        SpeedTestController.new);

class SpeedTestController extends Notifier<SpeedTestState> {
  SpeedTestEngine? _engine;
  StreamSubscription<SpeedTestProgress>? _sub;

  // Ступени шкалы спидометра (Мбит/с).
  static const _steps = [50.0, 100.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0];

  @override
  SpeedTestState build() {
    ref.onDispose(_teardown);
    return const SpeedTestState();
  }

  /// Запуск теста.
  void start() {
    if (state.isRunning) return;
    _teardown();
    state = const SpeedTestState(phase: TestPhase.ping, gaugeMax: 100);

    final engine = _engine = SpeedTestEngine();
    _sub = engine.run().listen(
      (p) {
        final observed = [
          p.displayMbps,
          p.downloadMbps ?? 0,
          p.uploadMbps ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        state = state.applyProgress(p, _fitMax(observed, state.gaugeMax));

        if (p.phase == TestPhase.done) _saveToHistory();
      },
      onError: (Object e) {
        state = state.copyWith(phase: TestPhase.error, error: '$e');
        _teardown();
      },
      onDone: () {
        _sub = null;
        _engine = null;
      },
    );
  }

  /// Остановка теста пользователем. Уже полученные результаты сохраняем.
  void stop() {
    _teardown();
    state = state.copyWith(
      phase: state.hasResults ? TestPhase.done : TestPhase.idle,
    );
  }

  /// Сброс к чистому состоянию.
  void reset() {
    _teardown();
    state = const SpeedTestState();
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _engine?.cancel();
    _engine = null;
  }

  /// Сохраняет завершённый тест в историю. Вызывается только когда движок
  /// сам дошёл до конца (natural completion) — ручная остановка (stop())
  /// в историю не попадает, даже если частичные результаты уже есть.
  void _saveToHistory() {
    final down = state.downloadMbps;
    final up = state.uploadMbps;
    final ping = state.pingMs;
    final jitter = state.jitterMs;
    if (down == null || up == null || ping == null || jitter == null) return;

    ref.read(speedTestHistoryProvider.notifier).add(SpeedTestRecord(
          timestamp: DateTime.now(),
          downloadMbps: down,
          uploadMbps: up,
          pingMs: ping,
          jitterMs: jitter,
        ));
  }

  /// Подбирает ближайшую сверху ступень шкалы, но не ниже текущей.
  double _fitMax(double v, double current) {
    final needed = (v * 1.15).clamp(1.0, double.infinity);
    var chosen = _steps.last;
    for (final s in _steps) {
      if (s >= needed) {
        chosen = s;
        break;
      }
    }
    return chosen > current ? chosen : current;
  }
}
