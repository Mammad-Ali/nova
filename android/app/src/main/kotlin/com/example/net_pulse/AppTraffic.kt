package com.example.net_pulse

import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Which apps used the network, today or over the past week, for the Monitor tab
 * (app_traffic_source.dart). Android keeps this in NetworkStatsManager and
 * shows it only to apps the user lets in under Settings → Usage access.
 */
class AppTraffic(private val context: Context) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "net_pulse/apps").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "openAccess" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                }
                "range" -> {
                    val from = (call.argument<Number>("from") ?: 0).toLong()
                    val to = (call.argument<Number>("to") ?: System.currentTimeMillis()).toLong()
                    // A query walks every app's buckets: off the main thread.
                    Thread {
                        val apps = try {
                            range(from, to)
                        } catch (e: Exception) {
                            null
                        }
                        Handler(Looper.getMainLooper()).post { result.success(apps) }
                    }.start()
                }
                "icon" -> {
                    val pkg = call.arguments as? String
                    result.success(if (pkg == null) null else icon(pkg))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Bytes per app from [from] to [to], over Wi-Fi and mobile data together. */
    private fun range(from: Long, to: Long): List<Map<String, Any>>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || !hasAccess()) return null
        val stats = context.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager

        val byUid = HashMap<Int, LongArray>()
        @Suppress("DEPRECATION")
        for (type in intArrayOf(ConnectivityManager.TYPE_WIFI, ConnectivityManager.TYPE_MOBILE)) {
            val summary = try {
                // Mobile data before Android 10 wants the SIM's subscriber
                // ID, which needs a phone permission Nova doesn't ask for:
                // then only Wi-Fi is counted.
                stats.querySummary(type, null, from, to)
            } catch (e: Exception) {
                continue
            }
            val bucket = NetworkStats.Bucket()
            while (summary.hasNextBucket()) {
                summary.getNextBucket(bucket)
                val total = byUid.getOrPut(bucket.uid) { LongArray(2) }
                total[0] += bucket.rxBytes
                total[1] += bucket.txBytes
            }
            summary.close()
        }

        return byUid.mapNotNull { (uid, bytes) ->
            if (bytes[0] + bytes[1] == 0L) return@mapNotNull null
            val (name, kind, pkg) = describe(uid)
            mapOf("name" to name, "kind" to kind, "package" to pkg, "rx" to bytes[0], "tx" to bytes[1])
        }
    }

    /** The app's launcher icon as a PNG, [side] pixels square. */
    private fun icon(pkg: String, side: Int = 96): ByteArray? = try {
        val drawable = context.packageManager.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, side, side)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (e: Exception) {
        null
    }

    /** An app's name, what it is, and its package (for the icon). */
    private fun describe(uid: Int): Triple<String, String, String> {
        when (uid) {
            NetworkStats.Bucket.UID_REMOVED -> return Triple("", "removed", "")
            NetworkStats.Bucket.UID_TETHERING -> return Triple("", "hotspot", "")
            Process.SYSTEM_UID, 0 -> return Triple("", "system", "")
        }
        val pm = context.packageManager
        val packages = pm.getPackagesForUid(uid)
        if (packages.isNullOrEmpty()) return Triple("", "system", "")
        // Apps sharing a UID are named after the first one.
        val name = try {
            pm.getApplicationLabel(pm.getApplicationInfo(packages[0], 0)).toString()
        } catch (e: Exception) {
            packages[0]
        }
        return Triple(name, "app", packages[0])
    }
}
