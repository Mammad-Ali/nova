import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../speedtest/presentation/providers/speedtest_history_provider.dart';
import '../data/rtt_probe.dart';
import '../domain/call_check.dart';

/// Where a call check is.
class CallCheckState {
  const CallCheckState({
    this.running = false,
    this.samples = const [],
    this.progress = 0,
    this.result,
  });

  final bool running;

  /// Round trips so far, oldest first (null = lost).
  final List<double?> samples;

  /// 0..1 through the check.
  final double progress;

  /// Set once a check has finished.
  final CallMetrics? result;

  /// The figures so far, for the live readout while the check runs.
  CallMetrics get live => CallMetrics.fromSamples(samples);
}

final callCheckProvider =
    NotifierProvider.autoDispose<CallCheckNotifier, CallCheckState>(
        CallCheckNotifier.new);

/// Sends a small request four times a second for twenty seconds — a call
/// sends its audio and video in a steady stream, so what matters is how
/// evenly the replies come back, not how fast a single one is.
class CallCheckNotifier extends Notifier<CallCheckState> {
  static const duration = Duration(seconds: 20);
  static const _interval = Duration(milliseconds: 250);

  /// A speed test older than this says little about the connection now.
  static const _speedFreshFor = Duration(hours: 6);

  bool _cancelled = false;

  @override
  CallCheckState build() {
    ref.onDispose(() => _cancelled = true);
    return const CallCheckState();
  }

  Future<void> run() async {
    if (state.running) return;
    _cancelled = false;
    state = const CallCheckState(running: true);

    final probe = RttProbe();
    final samples = <double?>[];
    // Not counted: the first trip also pays for DNS and the TLS handshake,
    // which a call does once, before anyone speaks.
    await probe.once();
    final clock = Stopwatch()..start();
    try {
      while (clock.elapsed < duration && !_cancelled) {
        final started = clock.elapsed;
        samples.add(await probe.once());
        state = CallCheckState(
          running: true,
          samples: List.unmodifiable(samples),
          progress: (clock.elapsedMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
        );
        final wait = _interval - (clock.elapsed - started);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
    } finally {
      probe.close();
    }
    if (_cancelled) return;

    final history = ref.read(speedTestHistoryProvider);
    final last = history.isEmpty ? null : history.last;
    final fresh = last != null &&
        DateTime.now().difference(last.timestamp) < _speedFreshFor;
    state = CallCheckState(
      samples: List.unmodifiable(samples),
      progress: 1,
      result: CallMetrics.fromSamples(
        samples,
        downMbps: fresh ? last.downloadMbps : null,
        upMbps: fresh ? last.uploadMbps : null,
      ),
    );
  }
}
