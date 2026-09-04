package com.krajtilak.nummo

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.Button
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Modern, Minimal Android OS Widget Configuration Activity.
 * Dynamically inherits the user's active Nummo app accent preset and theme mode.
 */
class WidgetConfigurationActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedPeriod = "thisMonth"
    private var selectedBg = "opaque"
    private var accentColor = Color.parseColor("#4F46E5")
    private var isAmoled = false

    private fun dpToPx(dp: Float): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun createPillDrawable(
        fillColor: Int,
        strokeColor: Int,
        strokeWidthPx: Int,
        radiusDp: Float = 100f
    ): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(radiusDp).toFloat()
            setColor(fillColor)
            if (strokeWidthPx > 0) {
                setStroke(strokeWidthPx, strokeColor)
            }
        }
    }

    private fun resolveAccentColor(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.nummo_secure_accent_preset", null)
            ?: prefs.getString("nummo_secure_accent_preset", null)
            ?: "Indigo Slate"

        val swatchMap = mapOf(
            "Indigo Slate" to "#4F46E5",
            "Sky Platinum" to "#0284C7",
            "Emerald Mint" to "#10B981",
            "Electric Cyan" to "#06B6D4",
            "Gold Amber" to "#D97706",
            "Royal Violet" to "#7C3AED",
            "Crimson Rose" to "#E11D48",
            "Teal Lagoon" to "#0D9488",
            "Sunset Orange" to "#EA580C",
            "Amethyst Glow" to "#9333EA",
            "Magenta Pink" to "#DB2777",
            "Forest Moss" to "#16A34A",
            "Cobalt Sapphire" to "#2563EB",
            "Obsidian Slate" to "#475569"
        )

        val hex = swatchMap[raw] ?: raw
        return try {
            Color.parseColor(if (hex.startsWith("#")) hex else "#$hex")
        } catch (_: Exception) {
            Color.parseColor("#4F46E5")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_configuration)

        accentColor = resolveAccentColor(this)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val themeMode = flutterPrefs.getString("flutter.nummo_secure_theme_mode", null)
            ?: flutterPrefs.getString("nummo_secure_theme_mode", null)
        isAmoled = themeMode == "amoled"

        // Apply theme colors to window and root background
        val windowBg = if (isAmoled) Color.parseColor("#000000") else Color.parseColor("#0F1117")
        window.statusBarColor = windowBg
        window.navigationBarColor = windowBg
        findViewById<View>(R.id.config_root).setBackgroundColor(windowBg)

        // Style center card
        val cardBg = if (isAmoled) Color.parseColor("#08090C") else Color.parseColor("#181A22")
        val cardBorder = if (isAmoled) Color.parseColor("#14161F") else Color.parseColor("#262A36")
        findViewById<View>(R.id.config_card).background = createPillDrawable(cardBg, cardBorder, dpToPx(1f), 20f)

        // Style header badge
        val badge = findViewById<TextView>(R.id.config_badge_app)
        badge.background = createPillDrawable(withAlpha(accentColor, 35), 0, 0, 100f)
        badge.setTextColor(accentColor)

        // Read existing settings
        val widgetData = HomeWidgetPlugin.getData(this)
        selectedPeriod = widgetData.getString("widget_${appWidgetId}_period", "thisMonth") ?: "thisMonth"
        selectedBg = widgetData.getString("widget_${appWidgetId}_bg", "opaque") ?: "opaque"

        val periodTabs = mapOf(
            "today" to findViewById<TextView>(R.id.tab_period_today),
            "thisWeek" to findViewById<TextView>(R.id.tab_period_this_week),
            "thisMonth" to findViewById<TextView>(R.id.tab_period_this_month),
            "thisYear" to findViewById<TextView>(R.id.tab_period_this_year),
            "allTime" to findViewById<TextView>(R.id.tab_period_all_time)
        )

        val bgTabs = mapOf(
            "opaque" to findViewById<TextView>(R.id.tab_bg_opaque),
            "pure_black" to findViewById<TextView>(R.id.tab_bg_pure_black),
            "transparent" to findViewById<TextView>(R.id.tab_bg_transparent)
        )

        val btnApply = findViewById<Button>(R.id.config_btn_apply)
        btnApply.background = createPillDrawable(accentColor, 0, 0, 14f)
        btnApply.setTextColor(Color.WHITE)

        fun updateUi() {
            val unselectedBg = if (isAmoled) Color.parseColor("#111218") else Color.parseColor("#1E222D")
            val unselectedBorder = if (isAmoled) Color.parseColor("#1A1D27") else Color.parseColor("#2A2F3D")
            val unselectedText = Color.parseColor("#94A3B8")

            val selectedBgFill = withAlpha(accentColor, 38)
            val selectedBorder = accentColor
            val selectedText = accentColor

            // Update Period Tabs
            for ((key, tab) in periodTabs) {
                val isSel = key == selectedPeriod
                val bg = if (isSel) {
                    createPillDrawable(selectedBgFill, selectedBorder, dpToPx(1.5f), 100f)
                } else {
                    createPillDrawable(unselectedBg, unselectedBorder, dpToPx(1f), 100f)
                }
                tab.background = bg
                tab.setTextColor(if (isSel) selectedText else unselectedText)
            }

            // Update Background Tabs
            for ((key, tab) in bgTabs) {
                val isSel = key == selectedBg
                val bg = if (isSel) {
                    createPillDrawable(selectedBgFill, selectedBorder, dpToPx(1.5f), 100f)
                } else {
                    createPillDrawable(unselectedBg, unselectedBorder, dpToPx(1f), 100f)
                }
                tab.background = bg
                tab.setTextColor(if (isSel) selectedText else unselectedText)
            }
        }

        // Attach Click Listeners
        for ((key, tab) in periodTabs) {
            tab.setOnClickListener {
                selectedPeriod = key
                it.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                updateUi()
            }
        }

        for ((key, tab) in bgTabs) {
            tab.setOnClickListener {
                selectedBg = key
                it.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                updateUi()
            }
        }

        updateUi()

        btnApply.setOnClickListener {
            it.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)

            val editor = widgetData.edit()
            editor.putString("widget_${appWidgetId}_period", selectedPeriod)
            editor.putString("widget_${appWidgetId}_bg", selectedBg)

            // Immediately parse and cache slices for this timeframe if missing
            val existingJson = widgetData.getString("widget_data_$selectedPeriod", null)
            if (existingJson.isNullOrEmpty() || existingJson == "[]") {
                val calculated = NativeTransactionParser.calculateSlicesFromStorage(this, selectedPeriod)
                if (calculated.isNotEmpty()) {
                    val jsonStr = WidgetChartDrawer.toJsonString(calculated)
                    editor.putString("widget_data_$selectedPeriod", jsonStr)
                    editor.putBoolean("widget_has_data_$selectedPeriod", true)
                    editor.putString("widget_chart_json", jsonStr)
                    editor.putBoolean("widget_has_data", true)
                }
            }
            editor.commit()

            // Trigger immediate native widget render
            val appWidgetManager = AppWidgetManager.getInstance(this)
            CategoryBreakdownWidget2x1Provider.updateAppWidget(
                this,
                appWidgetManager,
                appWidgetId,
                widgetData
            )

            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }
}

