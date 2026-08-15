import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../../domain/entities/speedtest_models.dart';
import 'speedtest_servers.dart';

/// Drives a background isolate that runs the full speed test and streams
/// [SpeedTestProgress] back to the UI isolate. The test can be cancelled
/// mid-flight without blocking the UI or leaking open sockets.
class SpeedTestEngine {
  Isolate? _isolate;
  ReceivePort? _fromIsolate;
  SendPort? _control;
  StreamController<SpeedTestProgress>? _out;

  /// Starts the test and returns a stream of progress events.
  Stream<SpeedTestProgress> run() {
    final out = _out = StreamController<SpeedTestProgress>();

    _fromIsolate = ReceivePort()
      ..listen((msg) {
        if (msg is SendPort) {
          // First message is the isolate's control port, used to cancel.
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

  /// Graceful cancel: ask the isolate to close its sockets and exit.
  void cancel() {
    _control?.send('cancel');
    // Safety net: if the isolate is stuck on the network, kill it.
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

/// Isolate entry point. Sets up the control port and starts the run.
Future<void> _isolateEntry(SendPort toMain) async {
  final control = ReceivePort();
  toMain.send(control.sendPort); // hand over the port for 'cancel'

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

/// Thrown when a server answers with something unexpected (429, 5xx, ...).
class _ServerUnavailable implements Exception {
  _ServerUnavailable(this.status);
  final int status;
  @override
  String toString() => 'server responded $status';
}

/// All the test's network logic. Runs entirely inside the background isolate.
class _Runner {
  _Runner({required this.emit, required this.cancelled});

  final void Function(SpeedTestProgress) emit;
  final bool Function() cancelled;

  static const _connections = 4; // parallel connections
  static const _ewmaAlpha = 0.25; // needle smoothing
  static const _phaseDuration = Duration(seconds: 8);
  static const _rampUp = Duration(milliseconds: 1500); // TCP ramp-up

  double? _ping, _jitter, _download, _upload, _loadedPing;
  SpeedTestServer? _server;

  /// Round-trip times sampled while downloading (used for bufferbloat).
  final List<double> _loadedRtts = [];

  /// A single shared upload buffer. Random bytes are generated exactly once
  /// to keep the hot loop cheap and to defeat server-side compression.
  late final Uint8List _uploadBuffer = _makeBuffer(1 << 20); // 1 MB

  Future<void> run() async {
    // Pick a reachable server: walk the list by priority until one answers.
    _server = await _selectServer();
    if (_server == null) {
      emit(const SpeedTestProgress(
        phase: TestPhase.error,
        error: 'Could not reach any test server. '
            'Check your internet connection.',
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

  // ── Server selection ──────────────────────────────────────────────
  //
  // Probe each source with a tiny request. The first one answering 200/206
  // wins, so the test survives rate limits such as HTTP 429.
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
        // Pull a little data to confirm bytes actually flow.
        var got = 0;
        await for (final chunk in resp) {
          got += chunk.length;
          if (got > 32 * 1024) break;
        }
        if (ok && got > 0) return server;
      } catch (_) {
        // Server unreachable — try the next one.
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

  // ── Ping and jitter ───────────────────────────────────────────────
  Future<(double, double)> _measurePing() async {
    emit(SpeedTestProgress(
        phase: TestPhase.ping, serverName: _server?.name));
    final server = _server!;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    await _probe(client, server); // warm-up: absorbs DNS + TLS handshake

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

  /// Tiny request; returns the round-trip time in ms, or null on failure.
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

  // ── Throughput (download / upload) ────────────────────────────────
  Future<double> _measureThroughput({required bool isUpload}) async {
    final server = _server!;
    final phase = isUpload ? TestPhase.upload : TestPhase.download;

    // Not every source accepts uploads. If the chosen one doesn't, fall back
    // to the first server in the list that supports POST.
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

    var totalBytes = 0; // whole phase — drives the live readout
    var measuredBytes = 0; // post ramp-up only — drives the final number
    DateTime? measuredStart;

    void count(int n) {
      totalBytes += n;
      final now = DateTime.now();
      if (now.isAfter(measureFrom)) {
        measuredStart ??= now;
        measuredBytes += n;
      }
    }

    // Sampler: every 200 ms computes the instantaneous rate, smooths it with
    // an EWMA and emits an event for the gauge.
    var smoothed = 0.0;
    var lastBytes = 0;
    var lastTick = DateTime.now();
    final sampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();
      final dt = now.difference(lastTick).inMicroseconds / 1e6;
      if (dt <= 0) return;
      final inst = (totalBytes - lastBytes) * 8 / dt / 1e6; // Mbps
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

    // While downloading we measure latency in parallel — that is bufferbloat:
    // how much the link swells under load.
    Timer? bloatProbe;
    HttpClient? probeClient;
    if (!isUpload) {
      probeClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      bloatProbe = Timer.periodic(const Duration(milliseconds: 350), (_) async {
        if (DateTime.now().isBefore(measureFrom)) return; // wait for ramp-up
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
        // A dropped connection or a server refusal just ends this worker;
        // the others keep pulling.
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
    return measuredBytes * 8 / (elapsed <= 0 ? 1 : elapsed) / 1e6; // Mbps
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

    // 200 is a normal response, 206 a partial one (Range). Anything else
    // (a 429 rate limit, say) does not count as data.
    if (resp.statusCode != 200 && resp.statusCode != 206) {
      await resp.drain<void>();
      throw _ServerUnavailable(resp.statusCode);
    }
    await for (final data in resp) {
      count(data.length);
      if (cancelled() || !DateTime.now().isBefore(deadline)) {
        break; // breaking the stream cancels the subscription and closes it
      }
    }
  }

  Future<void> _uploadOnce(
    HttpClient c,
    SpeedTestServer server,
    void Function(int) count,
    DateTime deadline,
  ) async {
    const chunksPerReq = 8; // 8 MB per request
    final buf = _uploadBuffer;
    final req = await c.postUrl(Uri.parse(server.uploadUrl!));
    req.headers.contentType = ContentType.binary;
    req.contentLength = buf.length * chunksPerReq;

    for (var i = 0; i < chunksPerReq; i++) {
      if (cancelled() || !DateTime.now().isBefore(deadline)) {
        req.abort(); // abort forces the connection closed
        return;
      }
      req.add(buf);
      count(buf.length);
      await req.flush(); // backpressure: the counter tracks the wire
    }
    final resp = await req.close();
    await resp.drain<void>();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Upload server: the current one if it accepts POST, else the first that does.
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
