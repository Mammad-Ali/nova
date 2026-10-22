import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../domain/entities/speedtest_models.dart';

/// The speed test as a browser can run it.
///
/// Same contract as the native engine — `run()` streams progress, `cancel()`
/// stops it — but the implementation differs completely: no isolates and no
/// sockets exist in a browser, so measurement rides on `XMLHttpRequest`,
/// whose progress events report bytes as they arrive.
///
/// Only Cloudflare is used here. The other two sources the app falls back to
/// serve data happily to a native client but send no `Access-Control-Allow-
/// Origin` header, so a browser refuses to read their responses.
class SpeedTestEngine {
  StreamController<SpeedTestProgress>? _out;
  final List<web.XMLHttpRequest> _inFlight = [];
  var _cancelled = false;

  static const _downUrl = 'https://speed.cloudflare.com/__down';
  static const _upUrl = 'https://speed.cloudflare.com/__up';
  static const _serverName = 'Cloudflare';

  /// Cloudflare answers 429 to chunks larger than about 5 MB.
  static const _chunkBytes = 5000000;
  static const _uploadBytes = 2000000;
  static const _connections = 4;
  static const _phase = Duration(seconds: 8);

  /// TCP needs a moment to reach full speed; bytes before this don't count.
  static const _rampUp = Duration(milliseconds: 1500);

  /// Smoothing for the gauge needle, matching the native engine.
  static const _alpha = 0.25;

  Stream<SpeedTestProgress> run() {
    final out = _out = StreamController<SpeedTestProgress>();
    out.onCancel = cancel;
    unawaited(_run());
    return out.stream;
  }

  void cancel() {
    _cancelled = true;
    for (final xhr in _inFlight) {
      xhr.abort();
    }
    _inFlight.clear();
    _close();
  }

  void _emit(SpeedTestProgress p) {
    final out = _out;
    if (out != null && !out.isClosed) out.add(p);
  }

  void _close() {
    final out = _out;
    _out = null;
    if (out != null && !out.isClosed) out.close();
  }

  Future<void> _run() async {
    try {
      final (pingMs, jitterMs) = await _measurePing();
      if (_cancelled) return;

      _emit(SpeedTestProgress(
        phase: TestPhase.ping,
        pingMs: pingMs,
        jitterMs: jitterMs,
        serverName: _serverName,
      ));

      // Latency is sampled again during the download, while the link is busy:
      // the gap against the idle figure is the bufferbloat.
      final loaded = <double>[];
      final downloadMbps = await _measure(
        isUpload: false,
        pingMs: pingMs,
        jitterMs: jitterMs,
        loadedSamples: loaded,
      );
      if (_cancelled) return;

      final uploadMbps = await _measure(
        isUpload: true,
        pingMs: pingMs,
        jitterMs: jitterMs,
        downloadMbps: downloadMbps,
        loadedPingMs: _median(loaded),
      );
      if (_cancelled) return;

      _emit(SpeedTestProgress(
        phase: TestPhase.done,
        phaseProgress: 1,
        pingMs: pingMs,
        jitterMs: jitterMs,
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        loadedPingMs: _median(loaded),
        serverName: _serverName,
      ));
    } catch (e) {
      if (!_cancelled) {
        _emit(SpeedTestProgress(phase: TestPhase.error, error: '$e'));
      }
    } finally {
      _close();
    }
  }

  // ───────────────────────────── latency ─────────────────────────────

  Future<(double, double)> _measurePing() async {
    _emit(const SpeedTestProgress(phase: TestPhase.ping));
    // Warm-up, not counted: the first request also pays for DNS and the TLS
    // handshake. Counting it left the median intact but threw jitter, the
    // mean step between samples, up by an order of magnitude — 170 ms on a
    // line with a steady 57 ms ping. The native engine has always done this.
    await _probe();
    final rtts = <double>[];
    for (var i = 0; i < 6 && !_cancelled; i++) {
      final rtt = await _probe();
      if (rtt != null) rtts.add(rtt);
      _emit(SpeedTestProgress(
        phase: TestPhase.ping,
        phaseProgress: (i + 1) / 6,
        serverName: _serverName,
      ));
    }
    if (rtts.isEmpty) throw Exception('the server did not answer');
    return (_median(rtts) ?? 0, _meanAbsDeviation(rtts));
  }

  /// One tiny request, timed. Returns null if it failed.
  Future<double?> _probe() async {
    final sw = Stopwatch()..start();
    try {
      await _request('GET', '$_downUrl?bytes=0');
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────── throughput ───────────────────────────

  /// Runs one phase and returns its speed in Mbps.
  Future<double> _measure({
    required bool isUpload,
    required double pingMs,
    required double jitterMs,
    double? downloadMbps,
    double? loadedPingMs,
    List<double>? loadedSamples,
  }) async {
    final phase = isUpload ? TestPhase.upload : TestPhase.download;
    final started = DateTime.now();
    final countFrom = started.add(_rampUp);
    final deadline = started.add(_phase);

    var bytes = 0;
    var display = 0.0;
    DateTime? measuringSince;
    Object? failure;

    void count(int delta) {
      final now = DateTime.now();
      if (now.isBefore(countFrom)) return;
      measuringSince ??= now;
      bytes += delta;

      final elapsed = now.difference(measuringSince!).inMicroseconds / 1e6;
      if (elapsed <= 0.05) return;
      final instant = bytes * 8 / elapsed / 1e6;
      display = display == 0 ? instant : display + _alpha * (instant - display);

      _emit(SpeedTestProgress(
        phase: phase,
        displayMbps: display,
        phaseProgress:
            now.difference(started).inMilliseconds / _phase.inMilliseconds,
        pingMs: pingMs,
        jitterMs: jitterMs,
        downloadMbps: downloadMbps,
        loadedPingMs: loadedPingMs,
        serverName: _serverName,
      ));
    }

    // Latency under load: sampled on its own connection while the transfer
    // saturates the link.
    Future<void> sampleLoadedPing() async {
      while (!_cancelled && DateTime.now().isBefore(deadline)) {
        final rtt = await _probe();
        if (rtt != null) loadedSamples?.add(rtt);
      }
    }

    final workers = [
      for (var i = 0; i < _connections; i++)
        _transferLoop(
          isUpload: isUpload,
          deadline: deadline,
          onBytes: count,
          onError: (e) => failure ??= e,
        ),
      if (loadedSamples != null) sampleLoadedPing(),
    ];
    await Future.wait(workers);

    final since = measuringSince;
    if (since == null) {
      // Nothing arrived once counting began. Returning 0 here would grade
      // the line "E" and store a 0 Mbps result in the history, so the phase
      // fails instead and the error banner says why.
      if (_cancelled) return 0;
      final side = isUpload ? 'upload' : 'download';
      throw Exception(
          'No data during $side${failure == null ? '' : ' ($failure)'}');
    }
    final elapsed = DateTime.now().difference(since).inMicroseconds / 1e6;
    return elapsed <= 0 ? 0 : bytes * 8 / elapsed / 1e6;
  }

  /// Keeps transferring chunks until the phase deadline passes.
  Future<void> _transferLoop({
    required bool isUpload,
    required DateTime deadline,
    required void Function(int) onBytes,
    required void Function(Object) onError,
  }) async {
    while (!_cancelled && DateTime.now().isBefore(deadline)) {
      try {
        if (isUpload) {
          await _request(
            'POST',
            _upUrl,
            body: _uploadPayload,
            onUploadProgress: onBytes,
          );
        } else {
          // A fresh query each time, so no chunk is served from cache.
          final url = '$_downUrl?bytes=$_chunkBytes&r=${_nonce()}';
          await _request('GET', url, onDownloadProgress: onBytes);
        }
      } catch (e) {
        // A dropped chunk just ends this worker; the others carry the phase.
        // The reason is kept in case every worker ends up failing.
        onError(e);
        return;
      }
    }
  }

  // ───────────────────────────── plumbing ─────────────────────────────

  static final Uint8List _uploadPayload = _makePayload(_uploadBytes);

  /// Random bytes: incompressible, so no proxy can shrink them in transit.
  static Uint8List _makePayload(int size) {
    final rnd = Random();
    final buf = Uint8List(size);
    for (var i = 0; i < size; i++) {
      buf[i] = rnd.nextInt(256);
    }
    return buf;
  }

  /// Cache-buster for chunk URLs. The bound is a literal on purpose: in
  /// JavaScript, shifts are 32-bit, so `1 << 32` compiles to 0 and
  /// `nextInt(0)` throws — which used to kill every download worker.
  int _nonce() => Random().nextInt(0x7FFFFFFF);

  /// One request, reporting bytes through the progress callbacks. Completes
  /// when the transfer finishes, throws when it fails or is aborted.
  Future<void> _request(
    String method,
    String url, {
    Uint8List? body,
    void Function(int)? onDownloadProgress,
    void Function(int)? onUploadProgress,
  }) {
    final xhr = web.XMLHttpRequest();
    final done = Completer<void>();
    _inFlight.add(xhr);

    var lastDown = 0;
    var lastUp = 0;

    xhr.open(method, url);
    xhr.responseType = 'arraybuffer';

    if (onDownloadProgress != null) {
      xhr.onprogress = ((web.ProgressEvent e) {
        final loaded = e.loaded;
        onDownloadProgress(loaded - lastDown);
        lastDown = loaded;
      }).toJS;
    }
    if (onUploadProgress != null) {
      xhr.upload.onprogress = ((web.ProgressEvent e) {
        final loaded = e.loaded;
        onUploadProgress(loaded - lastUp);
        lastUp = loaded;
      }).toJS;
    }

    void settle({Object? error}) {
      _inFlight.remove(xhr);
      if (done.isCompleted) return;
      if (error == null) {
        done.complete();
      } else {
        done.completeError(error);
      }
    }

    xhr.onload = ((web.Event _) {
      final status = xhr.status;
      // 429 means the chunk was too large or we asked too often.
      settle(error: status == 200 ? null : Exception('server answered $status'));
    }).toJS;
    xhr.onerror = ((web.Event _) {
      settle(error: Exception('network error'));
    }).toJS;
    xhr.onabort = ((web.Event _) {
      settle(error: Exception('cancelled'));
    }).toJS;

    if (body == null) {
      xhr.send();
    } else {
      xhr.send(body.toJS);
    }
    return done.future;
  }

  double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final sorted = [...xs]..sort();
    return sorted[sorted.length ~/ 2];
  }

  double _meanAbsDeviation(List<double> xs) {
    if (xs.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < xs.length; i++) {
      total += (xs[i] - xs[i - 1]).abs();
    }
    return total / (xs.length - 1);
  }
}
