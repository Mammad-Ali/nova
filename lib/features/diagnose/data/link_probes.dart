import 'dart:io';

import '../../call_check/data/rtt_probe.dart';
import '../../lan_scan/data/lan_scan_engine.dart';
import '../../wifi/wifi_info.dart';

/// The measurements behind "Find the cause". They need the device's own
/// network stack — a web page can reach neither the router nor the system's
/// name lookups — so the feature lives in the apps only.
class LinkProbes {
  /// Signal strength in dBm, or null when this device isn't on Wi-Fi (or the
  /// platform doesn't say).
  static Future<int?> wifiSignal() async => (await fetchWifiInfo())?.rssi;

  /// The router's address and [count] round trips to it (null = lost).
  ///
  /// Dart can't read the routing table, so the router is taken to be the
  /// first of the usual addresses (.1, then .254) that answers. A refused
  /// connection is an answer too: the timing of the refusal is the round
  /// trip.
  static Future<(String?, List<double?>)> router({int count = 10}) async {
    final self = await localNetworkAddress();
    if (self == null) return (null, const <double?>[]);
    final prefix = self.substring(0, self.lastIndexOf('.') + 1);

    for (final candidate in ['${prefix}1', '${prefix}254']) {
      if (candidate == self) continue;
      for (final port in const [80, 443, 53]) {
        final first = await _connectTime(candidate, port);
        if (first == null) continue;
        final samples = <double?>[first];
        while (samples.length < count) {
          samples.add(await _connectTime(candidate, port));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        return (candidate, samples);
      }
    }
    return (null, const <double?>[]);
  }

  /// How long the slowest of a few name lookups took, and how many failed.
  static Future<(double?, int, int)> dns() async {
    const names = ['www.google.com', 'www.wikipedia.org', 'www.cloudflare.com', 'github.com'];
    double? slowest;
    var failed = 0;
    for (final name in names) {
      final sw = Stopwatch()..start();
      try {
        final found = await InternetAddress.lookup(name).timeout(const Duration(seconds: 3));
        sw.stop();
        if (found.isEmpty) {
          failed++;
          continue;
        }
        final ms = sw.elapsedMicroseconds / 1000.0;
        if (slowest == null || ms > slowest) slowest = ms;
      } catch (_) {
        failed++;
      }
    }
    return (slowest, failed, names.length);
  }

  /// [count] round trips to Cloudflare's edge, a quarter second apart.
  static Future<List<double?>> internet({int count = 12}) async {
    final probe = RttProbe();
    final samples = <double?>[];
    try {
      await probe.once(); // warm-up: DNS and TLS, not counted
      while (samples.length < count) {
        samples.add(await probe.once());
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      probe.close();
    }
    return samples;
  }

  /// Time to a TCP answer from [ip]:[port] in ms — accepted or refused —
  /// or null when nothing came back.
  static Future<double?> _connectTime(String ip, int port) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 800));
      sw.stop();
      socket.destroy();
      return sw.elapsedMicroseconds / 1000.0;
    } on SocketException catch (e) {
      sw.stop();
      final code = e.osError?.errorCode;
      return code != null && kConnectionRefusedCodes.contains(code)
          ? sw.elapsedMicroseconds / 1000.0
          : null;
    }
  }
}
