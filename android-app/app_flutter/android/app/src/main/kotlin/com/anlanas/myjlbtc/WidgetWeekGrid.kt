package com.anlanas.myjlbtc

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface

/**
 * 「周视图」卡片的位图渲染：整周课表网格（月份 + 星期/日期 + 8 小節轴 + 彩色课块）。
 *
 * 为什么用位图而不是 RemoteViews：AppWidget 的 RemoteViews 既不能动态增删子视图、
 * 也不能按坐标摆放，而周网格要 7 列 × 8 行落格 + 跨行连堂课块，用位图最省事也最准。
 * 位图按卡片实际像素尺寸画、1:1 贴进 ImageView（不缩放，字不糊）。
 *
 * 与课表页同一口径：小節轴标「节号 + 上课时刻 + 下课时刻」，大节 n = 第 2n-1、2n 小節。
 */
object WidgetWeekGrid {

    /** 小節起止时刻（与 Flutter 侧 schedule_tab.dart 的作息表一致；9-12 是晚课） */
    private val SMALL_PERIODS = listOf(
        "08:20" to "09:05",
        "09:15" to "10:00",
        "10:20" to "11:05",
        "11:15" to "12:00",
        "13:20" to "14:05",
        "14:15" to "15:00",
        "15:20" to "16:05",
        "16:15" to "17:00",
        "18:00" to "18:45",
        "18:50" to "19:30",
        "19:40" to "20:20",
        "20:30" to "21:05",
    )

    /** 白天 8 小節；这一周有晚课（第 5-6 大节）时加到 12 小節 */
    private fun rowCountOf(snap: WidgetSnapshot): Int =
        if (snap.coursesOfWeek().any { it.start >= 5 }) 12 else 8

    private const val DAYS = 7
    private val WEEKDAY_CHARS = listOf("一", "二", "三", "四", "五", "六", "日")

    fun render(context: Context, snap: WidgetSnapshot?, wPx: Int, hPx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(wPx.coerceAtLeast(1), hPx.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val dm = context.resources.displayMetrics
        // 用 lambda 而不是局部函数：局部函数不能当值传给 helper（drawHeader / drawCenterText）
        val dp: (Float) -> Float = { it * dm.density }
        val sp: (Float) -> Float = { it * dm.scaledDensity }

        val dark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val card = context.getColor(R.color.widget_card)
        val primary = context.getColor(R.color.widget_text_primary)
        val secondary = context.getColor(R.color.widget_text_secondary)
        val accent = context.getColor(R.color.widget_accent)
        val divider = context.getColor(R.color.widget_grid_line)

        canvas.drawRoundRect(
            RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()),
            dp(20f),
            dp(20f),
            paint(card),
        )

        // 空态：没同步过 / 这一周没有课
        if (snap == null || !snap.hasData) {
            drawCenterText(canvas, "打开应用同步课表", sp(12f), secondary, wPx, hPx, dp)
            drawCenterText(canvas, "周视图", sp(15f), primary, wPx, hPx, dp, yOffset = -dp(20f), bold = true)
            return bitmap
        }

        val pad = dp(10f)
        val headerH = dp(34f)
        val axisW = dp(32f)
        val left = pad + axisW
        val top = pad + headerH
        val gridW = wPx - pad - left
        val gridH = hPx - pad - top
        // 有晚课的周用 12 行，否则 8 行（行多时轴与课块自动精简）
        val rows = rowCountOf(snap)
        val crowded = rows > 8
        val rowH = gridH / rows
        val colW = gridW / DAYS

        drawHeader(context, canvas, dp, sp, left, pad, axisW, headerH, colW, secondary, primary, accent)

        // 节次轴：节号 + 上课时刻 + 下课时刻
        val numPaint = textPaint(sp(7.5f), primary, Paint.Align.CENTER).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val timePaint = textPaint(sp(6f), secondary, Paint.Align.CENTER)
        for (row in 0 until rows) {
            val rowTop = top + row * rowH
            val cx = pad + axisW / 2f
            val (from, to) = SMALL_PERIODS[row]
            if (crowded) {
                // 12 行时轴只留「节号 + 上课时刻」，不然挤成一团
                canvas.drawText("${row + 1}", cx, rowTop + rowH * 0.52f, numPaint)
                canvas.drawText(from, cx, rowTop + rowH * 0.92f, timePaint)
            } else {
                canvas.drawText("${row + 1}", cx, rowTop + rowH * 0.42f, numPaint)
                canvas.drawText(from, cx, rowTop + rowH * 0.74f, timePaint)
                canvas.drawText(to, cx, rowTop + rowH * 0.99f, timePaint)
            }
        }

        // 网格线：横线 8 行、竖线 7 列（含边界）
        val line = Paint().apply {
            color = divider
            strokeWidth = Math.max(1f, dp(0.6f))
        }
        for (row in 0..rows) {
            val y = top + row * rowH
            canvas.drawLine(left, y, left + gridW, y, line)
        }
        for (col in 0..DAYS) {
            val x = left + col * colW
            canvas.drawLine(x, top, x, top + gridH, line)
        }

        // 课块：一天一列，大节 n → 第 2n-1、2n 小節
        val namePaint = textPaint(sp(7f), primary, Paint.Align.LEFT).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val metaPaint = textPaint(sp(6.2f), secondary, Paint.Align.LEFT)
        var drawn = 0
        for (day in 1..DAYS) {
            for (course in snap.coursesOn(day)) {
                val colorIndex = WidgetData.courseColorIndex(course.name)
                val hue = context.getColor(COURSE_COLORS[colorIndex])
                val first = course.firstSmall.coerceIn(1, rows)
                val last = course.lastSmall.coerceIn(first, rows)
                val blockTop = top + (first - 1) * rowH + dp(1.2f)
                val blockBottom = top + last * rowH - dp(1.2f)
                val blockLeft = left + (day - 1) * colW + dp(1.2f)
                val blockRight = left + day * colW - dp(1.2f)
                val rect = RectF(blockLeft, blockTop, blockRight, blockBottom)
                // 底色用课程色的淡色（深色模式加重一点），左侧一条实色竖条 + 实色文字
                canvas.drawRoundRect(
                    rect,
                    dp(4f),
                    dp(4f),
                    paint(withAlpha(hue, if (dark) 0x59 else 0x2E)),
                )
                canvas.drawRoundRect(
                    RectF(blockLeft, blockTop, blockLeft + dp(2.4f), blockBottom),
                    dp(1.5f),
                    dp(1.5f),
                    paint(hue),
                )
                val textLeft = blockLeft + dp(4f)
                val textWidth = blockRight - textLeft - dp(1.5f)
                if (textWidth < dp(8f)) continue
                namePaint.color = if (dark) hue else hue
                metaPaint.color = hue
                var y = blockTop + dp(9f)
                y = drawWrapped(
                    canvas, course.name, namePaint, textLeft, y, textWidth,
                    if (crowded) 3 else 4, dp(8.6f), blockBottom,
                )
                if (!crowded && course.place.isNotEmpty() && y + dp(7f) < blockBottom) {
                    y = drawWrapped(
                        canvas, "@${course.place}", metaPaint, textLeft, y + dp(1f),
                        textWidth, 2, dp(7.6f), blockBottom,
                    )
                }
                if (!crowded && course.teacher.isNotEmpty() && y + dp(7f) < blockBottom) {
                    drawWrapped(
                        canvas, course.teacher, metaPaint, textLeft, y + dp(1f),
                        textWidth, 2, dp(7.6f), blockBottom,
                    )
                }
                drawn++
            }
        }
        if (drawn == 0) {
            drawCenterText(canvas, "本周无课", sp(12f), secondary, wPx, hPx, dp)
        }
        return bitmap
    }

    /** 表头：轴上方写月份，其余 7 格写星期 + 日期（今天高亮） */
    private fun drawHeader(
        context: Context,
        canvas: Canvas,
        dp: (Float) -> Float,
        sp: (Float) -> Float,
        left: Float,
        pad: Float,
        axisW: Float,
        headerH: Float,
        colW: Float,
        secondary: Int,
        primary: Int,
        accent: Int,
    ) {
        val dates = WidgetData.weekDates()
        val today = WidgetData.todayWeekday()
        val monthPaint = textPaint(sp(8f), secondary, Paint.Align.CENTER)
        val dayPaint = textPaint(sp(8f), secondary, Paint.Align.CENTER)
        val datePaint = textPaint(sp(9f), primary, Paint.Align.CENTER).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val todayPaint = textPaint(sp(9f), accent, Paint.Align.CENTER).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val todayDayPaint = textPaint(sp(8f), accent, Paint.Align.CENTER)
        val todayColor = accent

        val baseY = pad + headerH
        canvas.drawText("${dates.first().get(java.util.Calendar.MONTH) + 1}月", pad + axisW / 2f, baseY - dp(13f), monthPaint)
        for (day in 1..DAYS) {
            val cx = left + (day - 0.5f) * colW
            val isToday = day == today
            canvas.drawText(
                WEEKDAY_CHARS[day - 1],
                cx,
                baseY - dp(19f),
                if (isToday) todayDayPaint else dayPaint,
            )
            canvas.drawText(
                "${dates[day - 1].get(java.util.Calendar.DAY_OF_MONTH)}",
                cx,
                baseY - dp(6f),
                if (isToday) todayPaint else datePaint,
            )
        }
        // 今天那一列底部一条短强调线
        val cx = left + (today - 0.5f) * colW
        canvas.drawRoundRect(
            RectF(cx - colW * 0.28f, baseY - dp(3.4f), cx + colW * 0.28f, baseY - dp(2f)),
            dp(1f),
            dp(1f),
            paint(todayColor),
        )
    }

    /** 逐字换行画中文（Canvas 没有自动换行），返回画完的下一个基线 y */
    private fun drawWrapped(
        canvas: Canvas,
        text: String,
        paint: Paint,
        x: Float,
        startY: Float,
        maxWidth: Float,
        maxLines: Int,
        lineHeight: Float,
        bottom: Float,
    ): Float {
        if (text.isEmpty()) return startY
        var line = StringBuilder()
        var y = startY
        var lines = 0
        var index = 0
        while (index < text.length) {
            val ch = text[index]
            val next = line.toString() + ch
            if (paint.measureText(next) > maxWidth && line.isNotEmpty()) {
                if (lines == maxLines - 1) {
                    canvas.drawText("${line}…", x, y, paint)
                    return y + lineHeight
                }
                canvas.drawText(line.toString(), x, y, paint)
                lines++
                y += lineHeight
                if (y > bottom) return y
                line = StringBuilder()
                continue
            }
            line.append(ch)
            index++
        }
        if (line.isNotEmpty() && y <= bottom) {
            canvas.drawText(line.toString(), x, y, paint)
            y += lineHeight
        }
        return y
    }

    private fun drawCenterText(
        canvas: Canvas,
        text: String,
        size: Float,
        color: Int,
        wPx: Int,
        hPx: Int,
        dp: (Float) -> Float,
        yOffset: Float = 0f,
        bold: Boolean = false,
    ) {
        val paint = textPaint(size, color, Paint.Align.CENTER).apply {
            if (bold) typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        }
        canvas.drawText(text, wPx / 2f, hPx / 2f + yOffset, paint)
    }

    private fun paint(color: Int) = Paint().apply {
        this.color = color
        isAntiAlias = true
    }

    private fun textPaint(size: Float, color: Int, align: Paint.Align) = Paint().apply {
        this.color = color
        this.textSize = size
        this.textAlign = align
        isAntiAlias = true
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha shl 24)

    private val COURSE_COLORS = intArrayOf(
        R.color.widget_course_1,
        R.color.widget_course_2,
        R.color.widget_course_3,
        R.color.widget_course_4,
    )
}
