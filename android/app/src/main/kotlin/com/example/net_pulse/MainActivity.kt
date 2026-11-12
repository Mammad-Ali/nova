package com.example.net_pulse

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val trafficChannelName = "net_pulse/traffic"
    private val wifiChannelName = "net_pulse/wifi"
    private val networkChannelName = "net_pulse/network"

    // nova:// links from the widgets. One can start the app before Dart
    // listens, so links wait until Dart asks for them ("take") and go
    // straight through ("open") after that — as on the Mac (NovaLinks).
    private var links: MethodChannel? = null
    private val pendingLinks = mutableListOf<String>()
    private var dartListening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net_pulse/links").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    dartListening = true
                    result.success(pendingLinks.toList())
                    pendingLinks.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
        intent?.let(::takeLink)

        // What the home-screen widgets show (widget_bridge.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net_pulse/widgets")
            .setMethodCallHandler { call, result ->
                val json = call.arguments as? String
                if (call.method == "update" && json != null) {
                    NovaWidgets.save(applicationContext, json)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

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

        // The automatic test skips metered connections: mobile data, hotspots.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannelName)
            .setMethodCallHandler { call, result ->
                val connectivity = applicationContext
                    .getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                when (call.method) {
                    "isMetered" -> result.success(connectivity?.isActiveNetworkMetered ?: false)
                    // The DNS test compares the network's own DNS servers
                    // with public ones.
                    "dnsServers" -> {
                        val servers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            connectivity?.getLinkProperties(connectivity.activeNetwork)
                                ?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList()
                        } else {
                            emptyList()
                        }
                        result.success(servers)
                    }
                    else -> result.notImplemented()
                }
            }

        // Which apps used the network today (Monitor tab).
        AppTraffic(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInfo") {
                    result.success(wifiInfo())
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeLink(intent)
    }

    private fun takeLink(intent: Intent) {
        val data = intent.data ?: return
        if (data.scheme != "nova") return
        // Handled once: the activity keeps its intent across rotations.
        intent.data = null
        val link = data.toString()
        if (dartListening) links?.invokeMethod("open", link) else pendingLinks.add(link)
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
