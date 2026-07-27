import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сведения о текущем Wi-Fi-подключении.
class WifiInfo {
  const WifiInfo({
    this.ssid,
    this.rssi,
    this.txRateMbps,
    this.channel,
    this.interfaceName,
  });

  /// Имя сети. Может быть null: и macOS, и Android отдают SSID только при
  /// выданном доступе к геопозиции — мы его специально не запрашиваем.
  final String? ssid;

  /// Уровень сигнала в dBm (около −50 отлично, −80 плохо).
  final int? rssi;

  /// Скорость линка с точкой доступа, Мбит/с.
  final int? txRateMbps;

  final int? channel;
  final String? interfaceName;

  /// Качество сигнала 0..1 по шкале −90…−40 dBm.
  double? get quality {
    final r = rssi;
    if (r == null) return null;
    return ((r + 90) / 50).clamp(0.0, 1.0);
  }

  bool get hasData => rssi != null || txRateMbps != null || ssid != null;
}

const _channel = MethodChannel('net_pulse/wifi');

/// Читает данные Wi-Fi. Возвращает null, если Wi-Fi выключен, соединение
/// проводное или платформа не поддерживается (например, Windows).
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
    return null; // канал не реализован на этой платформе
  } catch (_) {
    return null;
  }
}

/// Обновляется раз в 10 секунд — сигнал меняется, когда ходишь по квартире.
final wifiInfoProvider = StreamProvider<WifiInfo?>((ref) async* {
  yield await fetchWifiInfo();
  yield* Stream.periodic(const Duration(seconds: 10))
      .asyncMap((_) => fetchWifiInfo());
});
