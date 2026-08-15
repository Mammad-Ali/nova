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
                    // System-wide counters since the device booted.
                    // TrafficStats needs no dedicated permission to read.
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
     * Details about the current Wi-Fi link. Signal strength and link rate need
     * no permission; Android only reveals the SSID when location access has
     * been granted, otherwise returning a placeholder that we discard.
     */
    private fun wifiInfo(): Map<String, Any>? {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        if (!wifi.isWifiEnabled) return null

        @Suppress("DEPRECATION")
        val info = wifi.connectionInfo ?: return null
        if (info.networkId == -1 && info.bssid == null) return null // not connected

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
        map["txRate"] = info.linkSpeed // Mbps
        return map
    }
}
