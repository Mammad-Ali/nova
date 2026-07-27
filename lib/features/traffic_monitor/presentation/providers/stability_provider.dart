import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ping_sample.dart';

/// Сводка стабильности связи за последние ~2 минуты.
class StabilityStats {
  const StabilityStats({
    required this.samples,
    required this.running,
  });

  const StabilityStats.initial()
      : samples = const <PingSample>[],
        running = true;

  /// Замеры, старые → новые.
  final List<PingSample> samples;

  /// Идёт ли мониторинг (можно поставить на паузу).
  final bool running;

  PingSample? get latest => samples.isEmpty ? null : samples.last;

  /// Последний успешный пинг, мс.
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

  /// Среднее колебание задержки между соседними замерами.
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

  /// Доля потерь, 0..100.
  double get lossPercent =>
      samples.isEmpty ? 0 : lostCount * 100 / samples.length;

  /// Обрывов подряд прямо сейчас (>0 — связь лежит).
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

/// Раз в 2 секунды делает крошечный HTTPS-запрос и записывает задержку.
/// Неудача считается потерей пакета — так ловятся микрообрывы связи,
/// которые не видны по графику трафика.
class StabilityNotifier extends Notifier<StabilityStats> {
  /// 60 замеров × 2 с = окно в 2 минуты.
  static const capacity = 60;
  static const _interval = Duration(seconds: 2);
  static final _probeUrl = Uri.parse('https://speed.cloudflare.com/__down?bytes=0');

  final ListQueue<PingSample> _buffer = ListQueue<PingSample>(capacity);
  Timer? _timer;
  HttpClient? _client;
  bool _inFlight = false;

  @override
  StabilityStats build() {
    ref.onDispose(_stopTimer);
    _start();
    return const StabilityStats.initial();
  }

  void _start() {
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 30);
    _timer = Timer.periodic(_interval, (_) => _probe());
    _probe(); // первый замер сразу, чтобы не ждать 2 секунды
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _client?.close(force: true);
    _client = null;
  }

  /// Пауза / возобновление мониторинга.
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
    if (client == null || _inFlight) return; // не наслаиваем запросы
    _inFlight = true;

    double? rtt;
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(_probeUrl);
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>().timeout(const Duration(seconds: 4));
      sw.stop();
      if (resp.statusCode == 200) rtt = sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      rtt = null; // таймаут/обрыв → считаем потерей
    } finally {
      _inFlight = false;
    }

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
