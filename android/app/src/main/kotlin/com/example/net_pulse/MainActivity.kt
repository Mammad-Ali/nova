package com.example.net_pulse

import android.net.TrafficStats
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val trafficChannelName = "net_pulse/traffic"

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
    }
}
