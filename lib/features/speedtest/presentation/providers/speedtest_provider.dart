import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/speedtest_engine.dart';
import '../../domain/entities/speedtest_models.dart';
import '../../domain/entities/speedtest_record.dart';
import '../../domain/gauge_scale.dart';
import 'speedtest_history_provider.dart';

/// Immutable state of the Speedtest tab.
class SpeedTestState {
  const SpeedTestState({
    this.phase = TestPhase.idle,
    this.displayMbps = 0,
    this.phaseProgress = 0,
    this.scale = GaugeScale.standard,
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

  /// Top of the gauge scale. Grows in steps and never jumps back down.
  /// The speedometer's scale for this test.
  final GaugeScale scale;

  final double? pingMs;
  final double? jitterMs;
  final double? downloadMbps;
  final double? uploadMbps;

  /// Latency under load — the basis for the bufferbloat rating.
  final double? loadedPingMs;

  /// The server the measurement actually ran against.
  final String? serverName;

  final String? error;

  bool get isRunning => phase.isRunning;
  bool get hasResults => downloadMbps != null || uploadMbps != null;

  SpeedTestState copyWith({
    TestPhase? phase,
    double? displayMbps,
    double? phaseProgress,
    GaugeScale? scale,
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
      scale: scale ?? this.scale,
      pingMs: pingMs ?? this.pingMs,
      jitterMs: jitterMs ?? this.jitterMs,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      loadedPingMs: loadedPingMs ?? this.loadedPingMs,
      serverName: serverName ?? this.serverName,
      error: error,
    );
  }

  /// Applies an engine event while keeping metrics gathered so far.
  SpeedTestState applyProgress(SpeedTestProgress p, GaugeScale scale) {
    return SpeedTestState(
      phase: p.phase,
      displayMbps: p.displayMbps,
      phaseProgress: p.phaseProgress,
      scale: scale,
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

  @override
  SpeedTestState build() {
    ref.onDispose(_teardown);
    return const SpeedTestState();
  }

  /// Starts a test.
  void start() {
    if (state.isRunning) return;
    _teardown();
    // A multi-gigabit line gets the big dial from the start, so the scale
    // doesn't switch under the needle mid-test.
    final history = ref.read(speedTestHistoryProvider);
    final lastBest = history.isEmpty ? 0.0 : history.last.downloadMbps;
    state = SpeedTestState(phase: TestPhase.ping, scale: GaugeScale.fitting(lastBest));

    final engine = _engine = SpeedTestEngine();
    _sub = engine.run().listen(
      (p) {
        final observed = [
          p.displayMbps,
          p.downloadMbps ?? 0,
          p.uploadMbps ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        state = state.applyProgress(p, _fitScale(observed, state.scale));

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

  /// Stops the test on user request, keeping any results already gathered.
  void stop() {
    _teardown();
    state = state.copyWith(
      phase: state.hasResults ? TestPhase.done : TestPhase.idle,
    );
  }

  /// Resets to a clean state.
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

  /// Saves a finished test to history. Only called when the engine reached
  /// the end on its own; a manual stop() is never recorded, even if partial
  /// results already exist.
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

  /// Picks the next scale step above the value, never below the current one.
  /// The scale only ever grows during a test: a dial whose numbers change
  /// under the needle is exactly what made results hard to read.
  GaugeScale _fitScale(double observed, GaugeScale current) {
    final needed = GaugeScale.fitting(observed);
    return needed.max > current.max ? needed : current;
  }
}
