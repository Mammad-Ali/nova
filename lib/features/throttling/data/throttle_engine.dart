import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../speedtest/data/datasources/speedtest_servers.dart';
import '../domain/throttle_result.dart';

/// Checks whether the ISP throttles video: measures throughput against a
/// neutral CDN and against Netflix's video CDN, then compares the two.
///
/// Runs in its own isolate, like the main speed test, so byte counting never
/// stutters the UI.
class ThrottleEngine {
  Isolate? _isolate;
  ReceivePort? _port;

  /// Returns the result, or throws with a human-readable message.
  Future<ThrottleResult> run() async {
    final port = _port = ReceivePort();
    final completer = Completer<ThrottleResult>();

    port.listen((msg) {
      if (msg is ThrottleResult && !completer.isCompleted) {
        completer.complete(msg);
      } else if (msg is String && !completer.isCompleted) {
        completer.completeError(msg);
      }
      _dispose();
    });

    _isolate = await Isolate.spawn(_entry, port.sendPort);
    return completer.future.timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        _dispose();
        throw 'The check timed out';
      },
    );
  }

  void cancel() => _dispose();

  void _dispose() {
    _port?.close();
    _port = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

// ─────────────────────────── isolate side ───────────────────────────

const _phase = Duration(seconds: 5);
const _connections = 2;

Future<void> _entry(SendPort toMain) async {
  try {
    // 1. Video CDN: fast.com hands out URLs for the nearest Netflix servers.
    final videoUrls = await _fastComTargets();
    if (videoUrls.isEmpty) {
      toMain.send('Could not obtain a video server address');
      return;
    }
    final videoMbps = await _measure(videoUrls);

    // 2. Neutral CDN — the same source the main test uses.
    final neutral = kSpeedTestServers.first;
    final neutralMbps = await _measure(
      List.filled(_connections, neutral.chunkUrl()),
      rangeHeader: neutral.rangeHeader(),
    );

    toMain.send(ThrottleResult(
      neutralMbps: neutralMbps,
      videoMbps: videoMbps,
      verdict: verdictFor(neutralMbps, videoMbps),
      videoHost: Uri.parse(videoUrls.first).host,
    ));
  } catch (e) {
    toMain.send('$e');
  }
}

/// fast.com's public API — the one their own web client uses. Returns URLs
/// of the nearest Netflix Open Connect servers.
Future<List<String>> _fastComTargets() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final uri = Uri.parse('https://api.fast.com/netflix/speedtest/v2'
        '?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3');
    final resp = await (await client.getUrl(uri)).close();
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final targets = (json['targets'] as List<dynamic>?) ?? const [];
    return [
      for (final t in targets)
        if ((t as Map<String, dynamic>)['url'] is String) t['url'] as String,
    ];
  } finally {
    client.close(force: true);
  }
}

/// Downloads from the given URLs over several connections and returns Mbps.
Future<double> _measure(List<String> urls, {String? rangeHeader}) async {
  final started = DateTime.now();
  final deadline = started.add(_phase);
  // Skip the first second: TCP is still ramping up.
  final measureFrom = started.add(const Duration(milliseconds: 1000));

  var bytes = 0;
  DateTime? from;

  void count(int n) {
    final now = DateTime.now();
    if (now.isAfter(measureFrom)) {
      from ??= now;
      bytes += n;
    }
  }

  Future<void> worker(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 5);
    try {
      while (DateTime.now().isBefore(deadline)) {
        final req = await client.getUrl(Uri.parse(url));
        if (rangeHeader != null) {
          req.headers.set(HttpHeaders.rangeHeader, rangeHeader);
        } else {
          // Netflix serves the whole file; cap the chunk so we don't keep
          // pulling past the deadline.
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-9999999');
        }
        final resp = await req.close();
        if (resp.statusCode != 200 && resp.statusCode != 206) {
          await resp.drain<void>();
          return;
        }
        await for (final chunk in resp) {
          count(chunk.length);
          if (!DateTime.now().isBefore(deadline)) break;
        }
      }
    } catch (_) {
      // On a drop the worker simply finishes.
    } finally {
      client.close(force: true);
    }
  }

  // Spread URLs across workers (there may be fewer URLs than connections).
  final jobs = [
    for (var i = 0; i < _connections; i++) worker(urls[i % urls.length]),
  ];
  await Future.wait(jobs);

  final elapsed = from == null
      ? 1.0
      : DateTime.now().difference(from!).inMicroseconds / 1e6;
  return bytes * 8 / (elapsed <= 0 ? 1 : elapsed) / 1e6;
}
