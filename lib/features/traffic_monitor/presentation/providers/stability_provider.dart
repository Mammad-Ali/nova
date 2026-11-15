import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../call_check/data/rtt_probe.dart';
import '../../domain/entities/ping_sample.dart';

/// Connection stability over roughly the last two minutes.
class StabilityStats {
  const StabilityStats({
    required this.samples,
    required this.running,
  });

  const StabilityStats.initial()
      : samples = const <PingSample>[],
        running = true;

  /// Samples, oldest to newest.
  final List<PingSample> samples;

  /// Whether monitoring is running (it can be paused).
  final bool running;

  PingSample? get latest => samples.isEmpty ? null : samples.last;

  /// The most recent successful ping, in ms.
  double? get currentMs {
    for (var i = samples.length - 1; i >= 0; i--) {
      final r = samples[i].rttMs;
      if (r != null) return r;
    }
    return null;
  }

  List<double> get _oks =>
      [for (final s in samples) if (s.rttMs != null) s.rttMs!];

  double? get avgMs {
    final ok = _oks;
    if (ok.isEmpty) return null;
    return ok.reduce((a, b) => a + b) / ok.length;
  }

  double? get maxMs {
    final ok = _oks;
    if (ok.isEmpty) return null;
    return ok.reduce((a, b) => a > b ? a : b);
  }

  /// Mean variation in latency between consecutive samples.
  double? get jitterMs {
    final ok = _oks;
    if (ok.length < 2) return null;
    var sum = 0.0;
    for (var i = 1; i < ok.length; i++) {
      sum += (ok[i] - ok[i - 1]).abs();
    }
    return sum / (ok.length - 1);
  }

  int get lostCount => samples.where((s) => s.lost).length;

  /// Loss rate, 0..100.
  double get lossPercent =>
      samples.isEmpty ? 0 : lostCount * 100 / samples.length;

  /// Consecutive failures right now (>0 means the link is down).
  int get currentOutage {
    var n = 0;
    for (var i = samples.length - 1; i >= 0 && samples[i].lost; i--) {
      n++;
    }
    return n;
  }
}

final stabilityProvider =
    NotifierProvider<StabilityNotifier, StabilityStats>(StabilityNotifier.new);

/// Fires a tiny HTTPS request every two seconds and records the latency —
/// with the call check's probe, which works in the browser too.
/// A failure counts as a lost packet, which is how brief outages get caught —
/// they never show up on the traffic chart.
class StabilityNotifier extends Notifier<StabilityStats> {
  /// 60 samples × 2 s = a two-minute window.
  static const capacity = 60;
  static const _interval = Duration(seconds: 2);

  final ListQueue<PingSample> _buffer = ListQueue<PingSample>(capacity);
  Timer? _timer;
  RttProbe? _client;
  bool _inFlight = false;

  @override
  StabilityStats build() {
    ref.onDispose(_stopTimer);
    _start();
    return const StabilityStats.initial();
  }

  void _start() {
    _client = RttProbe();
    _timer = Timer.periodic(_interval, (_) => _probe());
    _probe(); // probe immediately instead of waiting two seconds
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _client?.close();
    _client = null;
  }

  /// Pauses or resumes monitoring.
  void toggle() {
    if (state.running) {
      _stopTimer();
      state = StabilityStats(samples: state.samples, running: false);
    } else {
      _start();
      state = StabilityStats(samples: state.samples, running: true);
    }
  }

  void reset() {
    _buffer.clear();
    state = StabilityStats(samples: const [], running: state.running);
  }

  Future<void> _probe() async {
    final client = _client;
    if (client == null || _inFlight) return; // never overlap requests
    _inFlight = true;

    // Null when lost: a timeout or a drop counts as a lost packet.
    final rtt = await client.once();
    _inFlight = false;

    _append(PingSample(timestamp: DateTime.now(), rttMs: rtt));
  }

  void _append(PingSample s) {
    if (_buffer.length >= capacity) _buffer.removeFirst();
    _buffer.addLast(s);
    state = StabilityStats(
      samples: List<PingSample>.unmodifiable(_buffer),
      running: state.running,
    );
  }
}
