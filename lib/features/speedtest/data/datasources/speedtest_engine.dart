import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../../domain/entities/speedtest_models.dart';
import 'speedtest_servers.dart';

/// Управляет фоновым изолятом, который прогоняет полный speedtest и стримит
/// [SpeedTestProgress] в UI-изолят. Позволяет отменить тест на лету, не
/// блокируя интерфейс и не оставляя открытых сокетов.
class SpeedTestEngine {
  Isolate? _isolate;
  ReceivePort? _fromIsolate;
  SendPort? _control;
  StreamController<SpeedTestProgress>? _out;

  /// Запускает тест и возвращает поток событий прогресса.
  Stream<SpeedTestProgress> run() {
    final out = _out = StreamController<SpeedTestProgress>();

    _fromIsolate = ReceivePort()
      ..listen((msg) {
        if (msg is SendPort) {
          // Первое сообщение — управляющий порт изолята (для отмены).
          _control = msg;
        } else if (msg is SpeedTestProgress) {
          if (!out.isClosed) out.add(msg);
          if (msg.phase == TestPhase.done || msg.phase == TestPhase.error) {
            _dispose();
          }
        }
      });

    Isolate.spawn(_isolateEntry, _fromIsolate!.sendPort).then(
      (iso) => _isolate = iso,
      onError: (Object e) {
        if (!out.isClosed) {
          out.add(SpeedTestProgress(phase: TestPhase.error, error: '$e'));
        }
        _dispose();
      },
    );

    out.onCancel = cancel;
    return out.stream;
  }

  /// Мягкая отмена: просим изолят закрыть сокеты и выйти.
  void cancel() {
    _control?.send('cancel');
    // Подстраховка: если изолят завис в сети — принудительно снимем его.
    Future<void>.delayed(const Duration(milliseconds: 700), _dispose);
  }

  void _dispose() {
    _fromIsolate?.close();
    _fromIsolate = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _control = null;
    final out = _out;
    _out = null;
    if (out != null && !out.isClosed) out.close();
  }
}

// ─────────────────────────── isolate side ───────────────────────────

/// Точка входа изолята. Настраивает управляющий порт и запускает прогон.
Future<void> _isolateEntry(SendPort toMain) async {
  final control = ReceivePort();
  toMain.send(control.sendPort); // отдаём порт для команды 'cancel'

  var cancelled = false;
  control.listen((m) {
    if (m == 'cancel') cancelled = true;
  });

  final runner = _Runner(emit: toMain.send, cancelled: () => cancelled);

  try {
    await runner.run();
  } catch (e) {
    toMain.send(SpeedTestProgress(phase: TestPhase.error, error: '$e'));
  } finally {
    control.close();
  }
}

/// Бросается, когда сервер ответил не тем, чего мы ждём (429, 5xx и т.п.).
class _ServerUnavailable implements Exception {
  _ServerUnavailable(this.status);
  final int status;
  @override
  String toString() => 'server responded $status';
}

/// Вся сетевая логика теста. Работает целиком внутри фонового изолята.
class _Runner {
  _Runner({required this.emit, required this.cancelled});

  final void Function(SpeedTestProgress) emit;
  final bool Function() cancelled;

  static const _connections = 4; // параллельные соединения
  static const _ewmaAlpha = 0.25; // сглаживание стрелки
  static const _phaseDuration = Duration(seconds: 8);
  static const _rampUp = Duration(milliseconds: 1500); // разгон TCP

  double? _ping, _jitter, _download, _upload, _loadedPing;
  SpeedTestServer? _server;

  /// RTT, собранные во время скачивания (для bufferbloat).
  final List<double> _loadedRtts = [];

  /// Один общий буфер для отдачи (генерим случайные байты ровно раз,
  /// чтобы не жечь CPU в горячем цикле и обойти сжатие на стороне сервера).
  late final Uint8List _uploadBuffer = _makeBuffer(1 << 20); // 1 МБ

  Future<void> run() async {
    // Выбираем живой сервер: перебираем по приоритету, пока не ответит.
    _server = await _selectServer();
    if (_server == null) {
      emit(const SpeedTestProgress(
        phase: TestPhase.error,
        error: 'Не удалось связаться ни с одним тестовым сервером. '
            'Проверьте подключение к интернету.',
      ));
      return;
    }

    final (ping, jitter) = await _measurePing();
    _ping = ping;
    _jitter = jitter;
    if (cancelled()) return _finish();

    _download = await _measureThroughput(isUpload: false);
    if (_loadedRtts.isNotEmpty) _loadedPing = _median(List.of(_loadedRtts));
    if (cancelled()) return _finish();

    _upload = await _measureThroughput(isUpload: true);
    _finish();
  }

  void _finish() {
    emit(SpeedTestProgress(
      phase: TestPhase.done,
      displayMbps: _download ?? 0,
      phaseProgress: 1,
      pingMs: _ping,
      jitterMs: _jitter,
      downloadMbps: _download,
      uploadMbps: _upload,
      loadedPingMs: _loadedPing,
      serverName: _server?.name,
    ));
  }

  // ── Выбор сервера ─────────────────────────────────────────────────
  //
  // Пробуем каждый источник крошечным запросом. Первый, кто ответит 200/206,
  // и становится рабочим — так тест переживает лимиты вроде HTTP 429.
  Future<SpeedTestServer?> _selectServer() async {
    for (final server in kSpeedTestServers) {
      if (cancelled()) return null;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(Uri.parse(server.chunkUrl()));
        final range = server.rangeHeader();
        if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
        final resp = await req.close().timeout(const Duration(seconds: 8));
        final ok = resp.statusCode == 200 || resp.statusCode == 206;
        // Забираем немного данных, чтобы убедиться, что поток реально идёт.
        var got = 0;
        await for (final chunk in resp) {
          got += chunk.length;
          if (got > 32 * 1024) break;
        }
        if (ok && got > 0) return server;
      } catch (_) {
        // Сервер недоступен — пробуем следующий.
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

  // ── Пинг и джиттер ────────────────────────────────────────────────
  Future<(double, double)> _measurePing() async {
    emit(SpeedTestProgress(
        phase: TestPhase.ping, serverName: _server?.name));
    final server = _server!;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    await _probe(client, server); // прогрев: поглощает DNS + TLS handshake

    const samples = 18;
    final rtts = <double>[];
    for (var i = 0; i < samples && !cancelled(); i++) {
      final rtt = await _probe(client, server);
      if (rtt != null) rtts.add(rtt);

      emit(SpeedTestProgress(
        phase: TestPhase.ping,
        phaseProgress: (i + 1) / samples,
        pingMs: rtts.isEmpty ? null : _median(List.of(rtts)),
        serverName: server.name,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    client.close(force: true);

    if (rtts.isEmpty) return (0.0, 0.0);
    return (_median(List.of(rtts)), _meanAbsDeviation(rtts));
  }

  /// Крошечный запрос; возвращает RTT в мс или null при ошибке.
  Future<double?> _probe(HttpClient c, SpeedTestServer server) async {
    try {
      final sw = Stopwatch()..start();
      final req = await c.getUrl(Uri.parse(server.probeUrl()));
      final range = server.probeRangeHeader();
      if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
      final resp = await req.close();
      await resp.drain<void>();
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    }
  }

  // ── Пропускная способность (download / upload) ────────────────────
  Future<double> _measureThroughput({required bool isUpload}) async {
    final server = _server!;
    final phase = isUpload ? TestPhase.upload : TestPhase.download;

    // Отдачу поддерживает не каждый источник. Если у выбранного её нет,
    // берём первый сервер из списка, который умеет POST.
    final upServer = isUpload ? _serverForUpload(server) : server;
    if (isUpload && upServer == null) return 0;

    emit(SpeedTestProgress(
      phase: phase,
      pingMs: _ping,
      jitterMs: _jitter,
      downloadMbps: isUpload ? _download : null,
      serverName: server.name,
    ));

    final started = DateTime.now();
    final deadline = started.add(_phaseDuration);
    final measureFrom = started.add(_rampUp);

    var totalBytes = 0; // всё за фазу — для мгновенной скорости
    var measuredBytes = 0; // только после разгона — для итога
    DateTime? measuredStart;

    void count(int n) {
      totalBytes += n;
      final now = DateTime.now();
      if (now.isAfter(measureFrom)) {
        measuredStart ??= now;
        measuredBytes += n;
      }
    }

    // Сэмплер: раз в 200 мс считает мгновенную скорость, сглаживает EWMA
    // и шлёт событие для стрелки спидометра.
    var smoothed = 0.0;
    var lastBytes = 0;
    var lastTick = DateTime.now();
    final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();
      final dt = now.difference(lastTick).inMicroseconds / 1e6;
      if (dt <= 0) return;
      final inst = (totalBytes - lastBytes) * 8 / dt / 1e6; // Мбит/с
      lastBytes = totalBytes;
      lastTick = now;
      smoothed =
          smoothed == 0 ? inst : _ewmaAlpha * inst + (1 - _ewmaAlpha) * smoothed;

      final p = now.difference(started).inMilliseconds /
          _phaseDuration.inMilliseconds;
      emit(SpeedTestProgress(
        phase: phase,
        displayMbps: smoothed,
        phaseProgress: p.clamp(0.0, 1.0),
        pingMs: _ping,
        jitterMs: _jitter,
        downloadMbps: isUpload ? _download : null,
        serverName: server.name,
      ));
    });

    // Во время скачивания параллельно меряем задержку — это и есть
    // bufferbloat: насколько канал «распухает» под нагрузкой.
    Timer? bloatProbe;
    HttpClient? probeClient;
    if (!isUpload) {
      probeClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      bloatProbe = Timer.periodic(const Duration(milliseconds: 350), (_) async {
        if (DateTime.now().isBefore(measureFrom)) return; // ждём разгона
        final rtt = await _probe(probeClient!, server);
        if (rtt != null) _loadedRtts.add(rtt);
      });
    }

    Future<void> worker() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 5);
      try {
        while (DateTime.now().isBefore(deadline) && !cancelled()) {
          if (isUpload) {
            await _uploadOnce(client, upServer!, count, deadline);
          } else {
            await _downloadOnce(client, server, count, deadline);
          }
        }
      } catch (_) {
        // Обрыв соединения или отказ сервера — воркер просто завершится,
        // остальные продолжат качать.
      } finally {
        client.close(force: true);
      }
    }

    await Future.wait([for (var i = 0; i < _connections; i++) worker()]);
    sampler.cancel();
    bloatProbe?.cancel();
    probeClient?.close(force: true);

    final elapsed = measuredStart == null
        ? 1.0
        : DateTime.now().difference(measuredStart!).inMicroseconds / 1e6;
    return measuredBytes * 8 / (elapsed <= 0 ? 1 : elapsed) / 1e6; // Мбит/с
  }

  Future<void> _downloadOnce(
    HttpClient c,
    SpeedTestServer server,
    void Function(int) count,
    DateTime deadline,
  ) async {
    final req = await c.getUrl(Uri.parse(server.chunkUrl()));
    final range = server.rangeHeader();
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final resp = await req.close();

    // 200 — обычный ответ, 206 — частичный (Range). Всё прочее (например,
    // 429 при лимите) данными не считаем.
    if (resp.statusCode != 200 && resp.statusCode != 206) {
      await resp.drain<void>();
      throw _ServerUnavailable(resp.statusCode);
    }
    await for (final data in resp) {
      count(data.length);
      if (cancelled() || !DateTime.now().isBefore(deadline)) {
        break; // прерываем стрим → подписка отменяется, сокет закроется
      }
    }
  }

  Future<void> _uploadOnce(
    HttpClient c,
    SpeedTestServer server,
    void Function(int) count,
    DateTime deadline,
  ) async {
    const chunksPerReq = 8; // 8 МБ на запрос
    final buf = _uploadBuffer;
    final req = await c.postUrl(Uri.parse(server.uploadUrl!));
    req.headers.contentType = ContentType.binary;
    req.contentLength = buf.length * chunksPerReq;

    for (var i = 0; i < chunksPerReq; i++) {
      if (cancelled() || !DateTime.now().isBefore(deadline)) {
        req.abort(); // прерываем — соединение закроется принудительно
        return;
      }
      req.add(buf);
      count(buf.length);
      await req.flush(); // backpressure: счётчик ~ следует за сетью
    }
    final resp = await req.close();
    await resp.drain<void>();
  }

  // ── Утилиты ───────────────────────────────────────────────────────

  /// Сервер для отдачи: текущий, если умеет POST, иначе первый подходящий.
  SpeedTestServer? _serverForUpload(SpeedTestServer current) {
    if (current.uploadUrl != null) return current;
    for (final s in kSpeedTestServers) {
      if (s.uploadUrl != null) return s;
    }
    return null;
  }

  Uint8List _makeBuffer(int size) {
    final rnd = Random();
    final b = Uint8List(size);
    for (var i = 0; i < size; i++) {
      b[i] = rnd.nextInt(256);
    }
    return b;
  }

  double _median(List<double> xs) {
    xs.sort();
    final n = xs.length;
    return n.isOdd ? xs[n ~/ 2] : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
  }

  double _meanAbsDeviation(List<double> xs) {
    if (xs.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < xs.length; i++) {
      sum += (xs[i] - xs[i - 1]).abs();
    }
    return sum / (xs.length - 1);
  }
}
