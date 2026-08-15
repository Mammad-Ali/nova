import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Details about the current Wi-Fi connection.
class WifiInfo {
  const WifiInfo({
    this.ssid,
    this.rssi,
    this.txRateMbps,
    this.channel,
    this.interfaceName,
  });

  /// Network name. May be null: both macOS and Android only reveal the SSID
  /// when location access is granted, and we deliberately don't ask for it.
  final String? ssid;

  /// Signal strength in dBm (around −50 is excellent, −80 is poor).
  final int? rssi;

  /// Link rate to the access point, in Mbps.
  final int? txRateMbps;

  final int? channel;
  final String? interfaceName;

  /// Signal quality 0..1, mapped from the −90…−40 dBm range.
  double? get quality {
    final r = rssi;
    if (r == null) return null;
    return ((r + 90) / 50).clamp(0.0, 1.0);
  }

  bool get hasData => rssi != null || txRateMbps != null || ssid != null;
}

const _channel = MethodChannel('net_pulse/wifi');

/// Reads Wi-Fi details. Returns null when Wi-Fi is off, the link is wired, or
/// the platform isn't supported (Windows, for instance).
Future<WifiInfo?> fetchWifiInfo() async {
  try {
    final raw = await _channel.invokeMapMethod<String, dynamic>('getInfo');
    if (raw == null) return null;
    final info = WifiInfo(
      ssid: raw['ssid'] as String?,
      rssi: (raw['rssi'] as num?)?.toInt(),
      txRateMbps: (raw['txRate'] as num?)?.toInt(),
      channel: (raw['channel'] as num?)?.toInt(),
      interfaceName: raw['interface'] as String?,
    );
    return info.hasData ? info : null;
  } on MissingPluginException {
    return null; // the channel isn't implemented on this platform
  } catch (_) {
    return null;
  }
}

/// Refreshed every 10 seconds — signal strength changes as you move around.
final wifiInfoProvider = StreamProvider<WifiInfo?>((ref) async* {
  yield await fetchWifiInfo();
  yield* Stream.periodic(const Duration(seconds: 10))
      .asyncMap((_) => fetchWifiInfo());
});
