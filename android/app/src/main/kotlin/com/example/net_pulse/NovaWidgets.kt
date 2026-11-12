package com.example.net_pulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.text.format.DateUtils
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Nova's home-screen widgets: "Speed" (the last result and a test button)
 * and "Speed & traffic" (the same, with today's and this month's data).
 * They show what the app last handed over — the same snapshot the Mac
 * widgets get (widget_bridge.dart) — and a tap opens Nova through a
 * nova:// link that MainActivity passes to Dart.
 */
object NovaWidgets {
    private const val PREFS = "nova_widgets"
    private const val KEY = "snapshot"

    /** Keeps [json] for the widgets and redraws every one on the screen. */
    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        refresh(context)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((provider, layout) in listOf(
            SpeedWidget::class.java to R.layout.widget_speed,
            DashWidget::class.java to R.layout.widget_dash,
        )) {
            for (id in manager.getAppWidgetIds(ComponentName(context, provider))) {
                manager.updateAppWidget(id, views(context, layout))
            }
        }
    }

    private fun load(context: Context): JSONObject? = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)?.let(::JSONObject)
    } catch (e: Exception) {
        null
    }

    fun views(context: Context, layout: Int): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        val snapshot = load(context)
        val labels = snapshot?.optJSONObject("labels")
        fun label(key: String, english: String) = labels?.optString(key)?.takeIf { it.isNotEmpty() } ?: english

        val running = snapshot?.optBoolean("running") == true
        views.setTextViewText(R.id.label, label("download", "Download"))
        views.setTextViewText(R.id.test, if (running) label("testing", "Testing…") else label("runTest", "Start test"))

        val test = snapshot?.optJSONObject("test")
        if (test != null) {
            views.setTextViewText(R.id.down, number(test.optDouble("down")))
            views.setViewVisibility(R.id.unit, View.VISIBLE)
            views.setTextViewText(
                R.id.details,
                "${label("upload", "Upload")} ${number(test.optDouble("up"))}   " +
                    "${label("ping", "Ping")} ${number(test.optDouble("ping"))} ms",
            )
            views.setTextViewText(R.id.grade, test.optString("grade"))
            views.setTextColor(R.id.grade, tierColor(test.optString("tierKey")))
            views.setViewVisibility(R.id.grade, View.VISIBLE)
            val at = test.optDouble("t").toLong()
            views.setTextViewText(
                R.id.age,
                DateUtils.getRelativeTimeSpanString(at, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS),
            )
        } else {
            views.setTextViewText(R.id.down, "—")
            views.setViewVisibility(R.id.unit, View.GONE)
            views.setTextViewText(R.id.details, label("noTest", "No test yet"))
            views.setViewVisibility(R.id.grade, View.GONE)
            views.setTextViewText(R.id.age, "")
        }

        if (layout == R.layout.widget_dash) {
            val usage = snapshot?.optJSONObject("usage")
            views.setTextViewText(R.id.traffic_title, label("traffic", "Traffic"))
            views.setTextViewText(R.id.today_label, label("today", "Today"))
            views.setTextViewText(R.id.month_label, label("month", "This month"))
            views.setTextViewText(R.id.hour_label, label("pastHour", "Past hour"))
            views.setTextViewText(R.id.today, usage?.optString("today") ?: "—")
            views.setTextViewText(R.id.month, usage?.optString("month") ?: "—")
            views.setTextViewText(R.id.hour, usage?.optString("hour") ?: "—")
        }

        views.setOnClickPendingIntent(R.id.root, link(context, "nova://open", 0))
        views.setOnClickPendingIntent(R.id.test, link(context, "nova://test", 1))
        return views
    }

    /** Opens Nova on [url]; MainActivity hands the link to Dart. */
    private fun link(context: Context, url: String, code: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** As the Mac widgets: whole numbers from 100 up, one decimal below. */
    private fun number(value: Double): String =
        if (value.isNaN()) "—" else if (value >= 100) "%.0f".format(value) else "%.1f".format(value)

    /** The grade's colour, as in the app (Palette.tier in NovaWidgets.swift). */
    private fun tierColor(key: String): Int = when (key) {
        "blazing" -> Color.parseColor("#4ADE80")
        "fast" -> Color.parseColor("#818CF8")
        "good" -> Color.parseColor("#6366F1")
        "moderate" -> Color.parseColor("#FBBF24")
        else -> Color.parseColor("#FB7185")
    }
}

class SpeedWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, NovaWidgets.views(context, R.layout.widget_speed))
    }
}

class DashWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, NovaWidgets.views(context, R.layout.widget_dash))
    }
}
