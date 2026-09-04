package com.krajtilak.nummo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

data class CategorySlice(
    val name: String,
    val emoji: String,
    val percent: Float,
    val colorHex: String
)

object WidgetChartDrawer {
    /**
     * Renders a modern, proportional Donut Chart bitmap showing analytics breakdown.
     * Features a refined ring stroke, elevated center hole, prominent top-percentage,
     * and a balanced category emoji.
     */
    fun drawDonutChart(
        slices: List<CategorySlice>,
        sizePx: Int = 280,
        strokeWidthPx: Float = 30f,
        bgStyle: String = "opaque"
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val halfStroke = strokeWidthPx / 2f
        val rect = RectF(
            halfStroke + 4f,
            halfStroke + 4f,
            sizePx.toFloat() - halfStroke - 4f,
            sizePx.toFloat() - halfStroke - 4f
        )

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokeWidthPx
            strokeCap = Paint.Cap.BUTT
        }

        val holeFillColor = when (bgStyle) {
            "pure_black" -> Color.parseColor("#000000")
            "transparent" -> Color.parseColor("#26000000")
            else -> Color.parseColor("#16181F")
        }

        val holeBorderColor = when (bgStyle) {
            "pure_black" -> Color.parseColor("#222222")
            "transparent" -> Color.parseColor("#33FFFFFF")
            else -> Color.parseColor("#262A36")
        }

        if (slices.isEmpty()) {
            paint.color = when (bgStyle) {
                "pure_black" -> Color.parseColor("#202020")
                "transparent" -> Color.parseColor("#33FFFFFF")
                else -> Color.parseColor("#262A36")
            }
            canvas.drawArc(rect, 0f, 360f, false, paint)

            val innerRadius = (sizePx / 2f) - strokeWidthPx - 2f
            if (innerRadius > 0) {
                val holePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = holeFillColor
                }
                canvas.drawCircle(sizePx / 2f, sizePx / 2f, innerRadius, holePaint)

                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                    color = holeBorderColor
                }
                canvas.drawCircle(sizePx / 2f, sizePx / 2f, innerRadius, borderPaint)
            }
        } else {
            var startAngle = -90f
            val space = if (slices.size > 1) 3.5f else 0f
            for (slice in slices) {
                val sweep = (slice.percent / 100f) * 360f - space
                paint.color = try {
                    Color.parseColor(slice.colorHex)
                } catch (e: Exception) {
                    Color.parseColor("#10B981")
                }
                canvas.drawArc(rect, startAngle + (space / 2f), sweep.coerceAtLeast(2.0f), false, paint)
                startAngle += (slice.percent / 100f) * 360f
            }

            // Draw elevated center hole
            val innerRadius = (sizePx / 2f) - strokeWidthPx - 2f
            if (innerRadius > 0) {
                val holePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = holeFillColor
                }
                canvas.drawCircle(sizePx / 2f, sizePx / 2f, innerRadius, holePaint)

                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                    color = holeBorderColor
                }
                canvas.drawCircle(sizePx / 2f, sizePx / 2f, innerRadius, borderPaint)

                // Prominent top category emoji only (NO percentage text in center)
                val topSlice = slices[0]
                if (topSlice.emoji.isNotEmpty()) {
                    val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        textSize = sizePx * 0.32f
                        textAlign = Paint.Align.CENTER
                    }
                    val yPos = (sizePx / 2f) - ((emojiPaint.descent() + emojiPaint.ascent()) / 2f)
                    canvas.drawText(topSlice.emoji, sizePx / 2f, yPos, emojiPaint)
                }
            }
        }

        return bitmap
    }

    fun drawColorDot(colorHex: String, sizePx: Int = 24): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val color = try {
            Color.parseColor(colorHex)
        } catch (e: Exception) {
            Color.parseColor("#10B981")
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = color
        }
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, (sizePx / 2f) - 1.0f, paint)
        return bitmap
    }

    fun parseSlices(rawJson: String?): List<CategorySlice> {
        if (rawJson.isNullOrEmpty()) return emptyList()
        val list = mutableListOf<CategorySlice>()
        try {
            val array = JSONArray(rawJson)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(
                    CategorySlice(
                        name = obj.optString("name", "Category"),
                        emoji = obj.optString("emoji", "🏷️"),
                        percent = obj.optDouble("percent", 0.0).toFloat(),
                        colorHex = obj.optString("color", "#10B981")
                    )
                )
            }
        } catch (e: Exception) {
            // Safe fallback
        }
        return list
    }

    fun toJsonString(slices: List<CategorySlice>): String {
        val array = JSONArray()
        for (s in slices) {
            val obj = JSONObject()
            obj.put("name", s.name)
            obj.put("emoji", s.emoji)
            obj.put("percent", s.percent.toDouble())
            obj.put("color", s.colorHex)
            array.put(obj)
        }
        return array.toString()
    }
}

/**
 * Autonomous Native Transaction Parser.
 * Allows the Android Home Screen Widget to parse transactions directly from Flutter's SharedPreferences,
 * ensuring immediate data availability upon widget configuration without requiring the Flutter app to be open.
 */
object NativeTransactionParser {
    data class CatMeta(val name: String, val emoji: String, val colorHex: String)

    private val defaultCategories = mapOf(
        "FOOD" to CatMeta("Food", "🍔", "#F59E0B"),
        "SHOPPING" to CatMeta("Shopping", "🛍️", "#EC4899"),
        "FUEL" to CatMeta("Fuel", "⛽", "#3B82F6"),
        "HOUSING" to CatMeta("Housing", "🏠", "#F97316"),
        "RENT" to CatMeta("Rent", "🏠", "#F97316"),
        "UTILITIES" to CatMeta("Utilities", "💡", "#EAB308"),
        "ENTERTAINMENT" to CatMeta("Entertainment", "🍿", "#8B5CF6"),
        "GROCERIES" to CatMeta("Groceries", "🛒", "#10B981"),
        "TRAVEL" to CatMeta("Travel", "✈️", "#06B6D4"),
        "HEALTH" to CatMeta("Health", "💊", "#EF4444"),
        "EDUCATION" to CatMeta("Education", "📚", "#3B82F6"),
        "SALARY" to CatMeta("Salary", "💰", "#10B981"),
        "INVESTMENT" to CatMeta("Investment", "📈", "#F59E0B"),
        "OTHER" to CatMeta("Other", "🏷️", "#64748B")
    )

    fun calculateSlicesFromStorage(context: Context, periodKey: String): List<CategorySlice> {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val txnsRaw = flutterPrefs.getString("flutter.nummo_secure_transactions_v3", null)
                ?: flutterPrefs.getString("flutter.nummo_transactions_v2", null)
                ?: flutterPrefs.getString("flutter.nummo_transactions", null)
                ?: flutterPrefs.getString("nummo_secure_transactions_v3", null)
                ?: return emptyList()

            val txnsArray = JSONArray(txnsRaw)
            if (txnsArray.length() == 0) return emptyList()

            // Load custom categories if available
            val catMap = HashMap(defaultCategories)
            val catsRaw = flutterPrefs.getString("flutter.nummo_secure_categories_v3", null)
            if (!catsRaw.isNullOrEmpty()) {
                try {
                    val catsArray = JSONArray(catsRaw)
                    for (i in 0 until catsArray.length()) {
                        val cObj = catsArray.getJSONObject(i)
                        val id = cObj.optString("id", "").uppercase()
                        val name = cObj.optString("name", "Category")
                        val emoji = cObj.optString("emoji", "🏷️")
                        val colorVal = cObj.optLong("colorValue", 0xFF64748BL)
                        val hex = String.format("#%06X", 0xFFFFFFL and colorVal)
                        if (id.isNotEmpty()) {
                            catMap[id] = CatMeta(name, emoji, hex)
                            catMap[name.uppercase()] = CatMeta(name, emoji, hex)
                        }
                    }
                } catch (_: Exception) {}
            }

            // Determine date bounds
            val calNow = java.util.Calendar.getInstance()
            val nowYear = calNow.get(java.util.Calendar.YEAR)
            val nowMonth = calNow.get(java.util.Calendar.MONTH) // 0-based
            val nowDay = calNow.get(java.util.Calendar.DAY_OF_MONTH)
            val nowWeek = calNow.get(java.util.Calendar.WEEK_OF_YEAR)

            val spendMap = HashMap<String, Double>()
            var totalExpense = 0.0

            for (i in 0 until txnsArray.length()) {
                val tObj = txnsArray.getJSONObject(i)
                val isCredit = tObj.optBoolean("isCredit", false)
                if (isCredit) continue // Debit / expense only

                val amount = tObj.optDouble("amount", 0.0)
                if (amount <= 0) continue

                // Parse date
                val dateCal = parseTxnDate(tObj.opt("timestamp")) ?: continue
                val tYear = dateCal.get(java.util.Calendar.YEAR)
                val tMonth = dateCal.get(java.util.Calendar.MONTH)
                val tDay = dateCal.get(java.util.Calendar.DAY_OF_MONTH)
                val tWeek = dateCal.get(java.util.Calendar.WEEK_OF_YEAR)

                val inRange = when (periodKey) {
                    "today" -> tYear == nowYear && tMonth == nowMonth && tDay == nowDay
                    "thisWeek" -> tYear == nowYear && tWeek == nowWeek
                    "thisMonth" -> tYear == nowYear && tMonth == nowMonth
                    "thisYear" -> tYear == nowYear
                    "allTime" -> true
                    else -> tYear == nowYear && tMonth == nowMonth
                }

                if (!inRange) continue

                val rawTag = tObj.optString("tag", "OTHER").trim().uppercase()
                val tagKey = if (rawTag.isEmpty()) "OTHER" else rawTag
                val currentSum = spendMap[tagKey] ?: 0.0
                spendMap[tagKey] = currentSum + amount
                totalExpense += amount
            }

            if (totalExpense <= 0 || spendMap.isEmpty()) return emptyList()

            // Sort descending by amount
            val sortedEntries = spendMap.entries.sortedByDescending { it.value }
            val slices = mutableListOf<CategorySlice>()
            for (entry in sortedEntries) {
                val meta = catMap[entry.key]
                    ?: catMap[entry.key.replace("_", "")]
                    ?: CatMeta(entry.key, "🏷️", "#10B981")

                val pct = ((entry.value / totalExpense) * 100.0).toFloat()
                slices.add(
                    CategorySlice(
                        name = meta.name,
                        emoji = meta.emoji,
                        percent = (pct * 10f).roundToInt() / 10f,
                        colorHex = meta.colorHex
                    )
                )
            }
            return slices
        } catch (e: Exception) {
            return emptyList()
        }
    }

    private fun parseTxnDate(raw: Any?): java.util.Calendar? {
        if (raw == null) return null
        val cal = java.util.Calendar.getInstance()
        if (raw is Number) {
            val millis = if (raw.toLong() > 100000000000L) raw.toLong() else raw.toLong() * 1000L
            cal.timeInMillis = millis
            return cal
        }
        val str = raw.toString().trim()
        val num = str.toLongOrNull()
        if (num != null && num > 100000000L) {
            val millis = if (num > 100000000000L) num else num * 1000L
            cal.timeInMillis = millis
            return cal
        }
        try {
            val format = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            val date = format.parse(str)
            if (date != null) {
                cal.time = date
                return cal
            }
        } catch (_: Exception) {}
        try {
            val formatShort = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            val date = formatShort.parse(str)
            if (date != null) {
                cal.time = date
                return cal
            }
        } catch (_: Exception) {}
        return null
    }
}

/**
 * Uber-grade, professional Android Home Screen Widget Provider for Nummo.
 * Adapts across horizontal rectangles with a clean two-column grid, customizable backgrounds,
 * per-widget frequency settings, and pure analytics without money amounts.
 */
open class CategoryBreakdownWidget2x1Provider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            renderWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = HomeWidgetPlugin.getData(context)
        renderWidget(context, appWidgetManager, appWidgetId, widgetData)
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            CategoryBreakdownWidget2x1Provider().renderWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ) {
        try {
            val periodKey = widgetData.getString("widget_${appWidgetId}_period", null)
                ?: widgetData.getString("widget_period_name", "thisMonth")
                ?: "thisMonth"
            val bgStyle = widgetData.getString("widget_${appWidgetId}_bg", "opaque") ?: "opaque"

            // 1. Try loading cached slice JSON for this specific period
            var chartJson = widgetData.getString("widget_data_$periodKey", null)
            var slices = WidgetChartDrawer.parseSlices(chartJson)

            // 2. If empty, fall back to general chart JSON
            if (slices.isEmpty()) {
                chartJson = widgetData.getString("widget_chart_json", null)
                    ?: widgetData.getString("widget_2x1_chart_json", null)
                slices = WidgetChartDrawer.parseSlices(chartJson)
            }

            // 3. If STILL empty, dynamically calculate directly from stored transactions!
            if (slices.isEmpty()) {
                slices = NativeTransactionParser.calculateSlicesFromStorage(context, periodKey)
                if (slices.isNotEmpty()) {
                    val computedJson = WidgetChartDrawer.toJsonString(slices)
                    widgetData.edit()
                        .putString("widget_data_$periodKey", computedJson)
                        .putBoolean("widget_has_data_$periodKey", true)
                        .putString("widget_chart_json", computedJson)
                        .putBoolean("widget_has_data", true)
                        .apply()
                }
            }

            val hasData = slices.isNotEmpty()

            // Dynamic launcher dimension detection
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0

            // Square / Donut-Only mode detection:
            // - Default when uninitialized (minWidth <= 0)
            // - 2-cell minimum width on standard grids (minWidth <= 180dp)
            // - Aspect ratio is roughly square (minWidth <= minHeight * 1.35)
            val isSquare = if (minWidth <= 0) {
                true
            } else {
                minWidth <= 180 || (minHeight > 0 && (minWidth.toFloat() / minHeight.toFloat()) <= 1.35f)
            }

            // Inflate dedicated layout: perfectly centered FrameLayout for square, horizontal grid for rectangle
            val views = if (isSquare) {
                RemoteViews(context.packageName, R.layout.category_breakdown_widget_square)
            } else {
                RemoteViews(context.packageName, R.layout.category_breakdown_widget_2x1)
            }

            // Apply Background Styling
            val rootBgRes: Int
            val chipBgRes: Int
            when (bgStyle) {
                "pure_black" -> {
                    rootBgRes = R.drawable.widget_background_black
                    chipBgRes = R.drawable.widget_chip_background_black
                }
                "transparent" -> {
                    rootBgRes = R.drawable.widget_background_transparent
                    chipBgRes = R.drawable.widget_chip_background_transparent
                }
                else -> {
                    rootBgRes = R.drawable.widget_background
                    chipBgRes = R.drawable.widget_chip_background
                }
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", rootBgRes)

            // Render Donut Chart with clean center hole styling
            val chartBitmap = WidgetChartDrawer.drawDonutChart(slices, 280, 30f, bgStyle)
            views.setImageViewBitmap(R.id.widget_donut_chart, chartBitmap)

            // Tapping the widget launches Nummo MainActivity
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("widget_source", "category_breakdown")
            }
            val mainPendingIntent = PendingIntent.getActivity(
                context,
                200 + appWidgetId,
                mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_donut_chart, mainPendingIntent)

            if (!isSquare) {
                // Horizontal Rectangle Mode: populate breakdown grid
                views.setOnClickPendingIntent(R.id.widget_chart_container, mainPendingIntent)
                views.setOnClickPendingIntent(R.id.widget_content_container, mainPendingIntent)

                if (hasData && slices.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_empty_container, View.GONE)
                    views.setViewVisibility(R.id.widget_grid_container, View.VISIBLE)

                    // Define all 12 item slots across 3 columns (4 rows):
                    // Row 1: Item 1 (Col 1), Item 2 (Col 2), Item 3 (Col 3)
                    // Row 2: Item 4 (Col 1), Item 5 (Col 2), Item 6 (Col 3)
                    // Row 3: Item 7 (Col 1), Item 8 (Col 2), Item 9 (Col 3)
                    // Row 4: Item 10 (Col 1), Item 11 (Col 2), Item 12 (Col 3)
                    data class SlotViews(val layoutId: Int, val dotId: Int, val emojiId: Int, val percentId: Int)

                    val allSlots = arrayOf(
                        SlotViews(R.id.widget_item_1, R.id.widget_item1_dot, R.id.widget_item1_emoji, R.id.widget_item1_percent),
                        SlotViews(R.id.widget_item_2, R.id.widget_item2_dot, R.id.widget_item2_emoji, R.id.widget_item2_percent),
                        SlotViews(R.id.widget_item_3, R.id.widget_item3_dot, R.id.widget_item3_emoji, R.id.widget_item3_percent),
                        SlotViews(R.id.widget_item_4, R.id.widget_item4_dot, R.id.widget_item4_emoji, R.id.widget_item4_percent),
                        SlotViews(R.id.widget_item_5, R.id.widget_item5_dot, R.id.widget_item5_emoji, R.id.widget_item5_percent),
                        SlotViews(R.id.widget_item_6, R.id.widget_item6_dot, R.id.widget_item6_emoji, R.id.widget_item6_percent),
                        SlotViews(R.id.widget_item_7, R.id.widget_item7_dot, R.id.widget_item7_emoji, R.id.widget_item7_percent),
                        SlotViews(R.id.widget_item_8, R.id.widget_item8_dot, R.id.widget_item8_emoji, R.id.widget_item8_percent),
                        SlotViews(R.id.widget_item_9, R.id.widget_item9_dot, R.id.widget_item9_emoji, R.id.widget_item9_percent),
                        SlotViews(R.id.widget_item_10, R.id.widget_item10_dot, R.id.widget_item10_emoji, R.id.widget_item10_percent),
                        SlotViews(R.id.widget_item_11, R.id.widget_item11_dot, R.id.widget_item11_emoji, R.id.widget_item11_percent),
                        SlotViews(R.id.widget_item_12, R.id.widget_item12_dot, R.id.widget_item12_emoji, R.id.widget_item12_percent)
                    )

                    // Initially hide all 12 slots
                    for (slot in allSlots) {
                        views.setViewVisibility(slot.layoutId, View.GONE)
                    }

                    // Max rows based on height:
                    // Small rectangle (>= 36dp) fits 3 rows cleanly with 16dp compact pills.
                    // Tall mode (>= 85dp) fits all 4 rows.
                    val maxRows = when {
                        minHeight >= 85 -> 4
                        minHeight >= 36 -> 3
                        else -> 2
                    }

                    // Column adaptation:
                    // At intermediate width (< 295dp): 2-column grid ensures no '%' truncation!
                    // At full width (>= 295dp): 3-column grid cleanly fills wide displays!
                    val isFullWidth = minWidth >= 295
                    val useThreeCols = isFullWidth && slices.size != 4 && slices.size > 2

                    views.setViewVisibility(R.id.widget_grid_col2, if (slices.size > 1) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.widget_grid_col3, if (useThreeCols) View.VISIBLE else View.GONE)

                    val slotSequence = if (useThreeCols) {
                        val list = mutableListOf<Int>()
                        for (r in 0 until maxRows) {
                            list.add(r * 3 + 0)
                            list.add(r * 3 + 1)
                            list.add(r * 3 + 2)
                        }
                        list
                    } else {
                        val list = mutableListOf<Int>()
                        for (r in 0 until maxRows) {
                            list.add(r * 3 + 0)
                            list.add(r * 3 + 1)
                        }
                        list
                    }

                    val visibleCount = minOf(slices.size, slotSequence.size)
                    for (i in 0 until visibleCount) {
                        val slotIndex = slotSequence[i]
                        val slot = allSlots[slotIndex]
                        val slice = slices[i]
                        views.setViewVisibility(slot.layoutId, View.VISIBLE)
                        views.setInt(slot.layoutId, "setBackgroundResource", chipBgRes)
                        views.setImageViewBitmap(slot.dotId, WidgetChartDrawer.drawColorDot(slice.colorHex, 18))
                        views.setTextViewText(slot.emojiId, slice.emoji)
                        views.setTextViewText(slot.percentId, "${slice.percent.roundToInt()}%")
                    }
                } else {
                    // Empty State View for rectangle mode
                    views.setViewVisibility(R.id.widget_grid_container, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_container, View.VISIBLE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            // Guard against unexpected runtime exceptions
        }
    }
}
