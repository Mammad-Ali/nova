package com.example.net_pulse

import android.content.Context
import android.net.TrafficStats
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val trafficChannelName = "net_pulse/traffic"
    private val wifiChannelName = "net_pulse/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, trafficChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCounters") {
                    // Системные счётчики с момента загрузки устройства.
                    // TrafficStats не требует отдельного разрешения на чтение.
                    result.success(
                        listOf(
                            TrafficStats.getTotalRxBytes(),
                            TrafficStats.getTotalTxBytes(),
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInfo") {
                    result.success(wifiInfo())
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Данные о текущем Wi-Fi. Уровень сигнала и скорость линка доступны без
     * разрешений; имя сети (SSID) Android отдаёт только при выданном доступе
     * к геопозиции — иначе возвращает заглушку, которую мы отбрасываем.
     */
    private fun wifiInfo(): Map<String, Any>? {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        if (!wifi.isWifiEnabled) return null

        @Suppress("DEPRECATION")
        val info = wifi.connectionInfo ?: return null
        if (info.networkId == -1 && info.bssid == null) return null // не подключены

        val map = mutableMapOf<String, Any>()
        @Suppress("DEPRECATION")
        val ssid = info.ssid?.trim('"')
        if (!ssid.isNullOrEmpty() &&
            ssid != "<unknown ssid>" &&
            ssid != "0x"
        ) {
            map["ssid"] = ssid
        }
        @Suppress("DEPRECATION")
        map["rssi"] = info.rssi
        @Suppress("DEPRECATION")
        map["txRate"] = info.linkSpeed // Мбит/с
        return map
    }
}
