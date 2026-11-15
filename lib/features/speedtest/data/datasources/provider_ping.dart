import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Latency to a provider server (azerbaijan_servers.dart) the way the
/// Speedtest network measures it: "PING <time>" on a plain connection to the
/// server's port, answered with "PONG <time>". Timing HTTP requests to the
/// same servers came out some 40 ms high — small requests wait on TCP's
/// delayed acknowledgements — while this matches what `ping` shows.
class ProviderPinger {
  ProviderPinger._(this._socket, this._lines);

  final Socket _socket;
  final StreamIterator<String> _lines;

  /// Opens the connection to [hostPort] ("speedtest.aztelekom.az:8080"), or
  /// returns null when the server doesn't answer.
  static Future<ProviderPinger?> connect(String hostPort, {Duration timeout = const Duration(seconds: 3)}) async {
    final colon = hostPort.lastIndexOf(':');
    final host = colon < 0 ? hostPort : hostPort.substring(0, colon);
    final port = colon < 0 ? 8080 : int.tryParse(hostPort.substring(colon + 1)) ?? 8080;
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      final lines = StreamIterator(utf8.decoder.bind(socket).transform(const LineSplitter()));
      return ProviderPinger._(socket, lines);
    } catch (_) {
      return null;
    }
  }

  /// One round trip in ms, or null when no PONG came within [timeout].
  Future<double?> once({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final sw = Stopwatch()..start();
      _socket.write('PING ${DateTime.now().millisecondsSinceEpoch}\n');
      while (await _lines.moveNext().timeout(timeout)) {
        if (_lines.current.startsWith('PONG')) return sw.elapsedMicroseconds / 1000.0;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void close() {
    unawaited(_lines.cancel());
    _socket.destroy();
  }
}
