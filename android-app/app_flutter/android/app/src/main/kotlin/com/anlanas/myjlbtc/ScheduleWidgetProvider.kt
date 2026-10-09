package com.anlanas.myjlbtc

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews

/** 小组件的四种卡片（对齐小米小组件规范的手机尺寸 2×2 / 4×2 / 4×4） */
enum class WidgetMode {
    /** 4×2：今日课程 4×2（头部 + 2 行课程） */
    FULL,

    /** 2×2：今日课程 2×2（头部 + 1 行课程） */
    SMALL,

    /** 4×4：今日课程 4×4（头部 + 最多 4 行课程） */
    LIST,

    /** 4×4：周视图（整周课表网格，位图渲染） */
    WEEK,
}

/**
 * 课程表桌面小组件（Android AppWidget），对应原版鸿蒙的 formability/ScheduleFormAbility.ets。
 *
 * 版式对齐 WakeUp 课程表的卡片：头部「第 N 周 · 周X」+ 角标，每行课程 = 左侧课程色条 +
 * 课名 / 地点·教师 + 右对齐的起止时刻；另有「周视图」卡片画整周网格。
 *
 * 尺寸与规范按小米小组件文档设计：
 * - 提供 2×2、4×2、4×4（含周视图）四种卡片，各一个 Provider（预览图直角、由系统裁圆角）；
 * - 卡片圆角 20dp、内边距 16dp（小米规范：1080p 圆角 55px≈20dp，安全区 ≥42px≈15dp）；
 * - 深色模式跟 `values-night` 资源走（小米要求必须适配深色）；
 * - 刷新：系统每 30 分钟一次 + App 写入新数据时（`refresh`）+ 加卡片 / 改尺寸时。
 */
class ScheduleWidgetProvider : BaseScheduleWidgetProvider(WidgetMode.FULL) {

    /** 用户确认把小组件钉到桌面后的回调 action（见 NativeBridge.pinWidget） */
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PINNED) {
            Log.i(TAG, "小组件已钉到桌面，立即刷一次内容")
            refresh(context)
        }
    }

    companion object {
        const val TAG = "MyJLBTC-Widget"
        const val ACTION_PINNED = "com.anlanas.myjlbtc.WIDGET_PINNED"

        /** 上一次画的内容指纹（状态没变就不重画：闹钟每分钟醒一次，但卡片只在"真变了"时重画） */
        private const val PREF_KEY = "widget_last_key"

        /**
         * 四种卡片一起刷。
         *
         * `force = false`（闹钟/应用内触点）时会先比对内容指纹：一样就跳过 ——
         * 免得每分钟一次的提醒节拍把四张卡片（含周视图那张位图）反复重画。
         */
        fun refresh(context: Context, force: Boolean = false) {
            val snapshot = WidgetData.read(context)
            val key = WidgetRenderer.contentKey(snapshot)
            if (!force) {
                val last = context.getSharedPreferences("myjlbtc_widget", Context.MODE_PRIVATE)
                    .getString(PREF_KEY, null)
                if (last == key) return
            }
            context.getSharedPreferences("myjlbtc_widget", Context.MODE_PRIVATE)
                .edit().putString(PREF_KEY, key).apply()
            val manager = AppWidgetManager.getInstance(context)
            var rendered = 0
            for ((cls, mode) in PROVIDERS) {
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                for (id in ids) {
                    manager.updateAppWidget(id, WidgetRenderer.build(context, mode, id))
                    rendered++
                }
            }
            Log.i(TAG, "重画卡片 $rendered 张（key=$key force=$force）")
        }

        val PROVIDERS = listOf(
            ScheduleWidgetProvider::class.java to WidgetMode.FULL,
            ScheduleWidgetSmallProvider::class.java to WidgetMode.SMALL,
            ScheduleWidgetListProvider::class.java to WidgetMode.LIST,
            ScheduleWidgetWeekProvider::class.java to WidgetMode.WEEK,
        )
    }
}

/** 各尺寸卡片共用的壳：onUpdate / 尺寸变化都走同一个渲染入口 */
abstract class BaseScheduleWidgetProvider(private val mode: WidgetMode) : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // 系统 30 分钟的周期更新（各 ROM 都可能省电推迟）：强制按当前时间重画一次
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, WidgetRenderer.build(context, mode, id))
        }
    }

    /** 用户拖拽改尺寸：周视图是位图，必须按新尺寸重画 */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, WidgetRenderer.build(context, mode, appWidgetId))
    }
}

/** 2×2 今日课程 */
class ScheduleWidgetSmallProvider : BaseScheduleWidgetProvider(WidgetMode.SMALL)

/** 4×4 今日课程列表 */
class ScheduleWidgetListProvider : BaseScheduleWidgetProvider(WidgetMode.LIST)

/** 4×4 周视图 */
class ScheduleWidgetWeekProvider : BaseScheduleWidgetProvider(WidgetMode.WEEK)

/** 卡片渲染：读快照 → 按当前时间算状态 → 组装 RemoteViews（四种卡片共用） */
object WidgetRenderer {

    /** 周视图位图的像素上限（约 400 万像素 / 16MB ARGB，正常 4×4 手机上不会被触发） */
    private const val MAX_BITMAP_PIXELS = 4_000_000.0

    /**
     * 卡片内容指纹：只跟"现在该显示什么"有关，跟具体版式无关。
     * 指纹没变说明四张卡片重画也不会变 —— 让提醒的每分钟节拍可以放心调用刷新。
     */
    fun contentKey(snapshot: WidgetSnapshot?): String {
        val weekday = WidgetData.todayWeekday()
        if (snapshot == null || !snapshot.hasData) return "nosync|$weekday"
        val courses = snapshot.coursesOn(weekday)
        if (courses.isEmpty()) return "empty|${snapshot.week}|$weekday"
        val now = WidgetData.nowMinutes()
        val timed = courses.map { it to it.minutes(snapshot.periodTimes) }
        val ongoing = timed.firstOrNull { (_, span) -> span != null && now >= span.first && now <= span.second }?.first
        val upcoming = timed.firstOrNull { (_, span) -> span != null && now < span.first }?.first
        val state = when {
            ongoing != null -> "ongoing:${ongoing.name}:${ongoing.start}"
            upcoming != null -> "upcoming:${upcoming.name}:${upcoming.start}"
            else -> "done" // 今天的课上完了：卡片清空，只有周次/星期/门数变化才需要重画
        }
        return "${snapshot.week}|$weekday|${courses.size}|$state"
    }

    /** 一行课程的控件句柄（各行尾号 0-3；2×2 卡片只有第 0 行） */
    private class RowIds(val row: Int, val bar: Int, val name: Int, val meta: Int, val start: Int, val end: Int)

    private val ROWS = listOf(
        RowIds(R.id.widget_row0, R.id.widget_bar0, R.id.widget_name0, R.id.widget_meta0, R.id.widget_start0, R.id.widget_end0),
        RowIds(R.id.widget_row1, R.id.widget_bar1, R.id.widget_name1, R.id.widget_meta1, R.id.widget_start1, R.id.widget_end1),
        RowIds(R.id.widget_row2, R.id.widget_bar2, R.id.widget_name2, R.id.widget_meta2, R.id.widget_start2, R.id.widget_end2),
        RowIds(R.id.widget_row3, R.id.widget_bar3, R.id.widget_name3, R.id.widget_meta3, R.id.widget_start3, R.id.widget_end3),
    )

    /** 各尺寸能显示几行（2×2 / 4×2 都是单课卡，4×4 是今日列表） */
    private val ROW_COUNT = mapOf(
        WidgetMode.SMALL to 1,
        WidgetMode.FULL to 1,
        WidgetMode.LIST to 4,
    )

    private val BAR_RES = intArrayOf(
        R.drawable.widget_bar_1,
        R.drawable.widget_bar_2,
        R.drawable.widget_bar_3,
        R.drawable.widget_bar_4,
    )

    private val WEEKDAY_CHARS = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    fun build(context: Context, mode: WidgetMode, widgetId: Int = 0): RemoteViews {
        if (mode == WidgetMode.WEEK) return buildWeek(context, widgetId)

        val views = RemoteViews(context.packageName, if (mode == WidgetMode.SMALL) {
            R.layout.schedule_widget_small
        } else {
            R.layout.schedule_widget
        })

        // 点卡片打开应用并落在「课表」页签
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_TAB, "schedule")
        }
        val pending = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        val snap = WidgetData.read(context)
        val weekday = WidgetData.todayWeekday()
        val courses = snap?.coursesOn(weekday) ?: emptyList()
        val now = WidgetData.nowMinutes()

        if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_body, View.GONE)
            views.setTextViewText(
                R.id.widget_empty_title,
                if (snap?.hasData == true) "今日无课" else "课表未同步",
            )
            views.setTextViewText(
                R.id.widget_empty_tip,
                if (snap?.hasData == true) "课程都结束啦，休息一下" else "打开应用同步课表",
            )
            return views
        }

        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.widget_body, View.VISIBLE)
        val data = snap ?: return views
        // 头部：第 N 周 · 周X（教学周未知时只写周X；2×2 窄卡用短写法，否则会跟角标打架）
        val week = data.week
        val head = buildString {
            when {
                week <= 0 -> Unit
                mode == WidgetMode.SMALL -> append("${week}周·")
                else -> append("第 $week 周 · ")
            }
            append(WEEKDAY_CHARS[weekday - 1])
        }
        views.setTextViewText(R.id.widget_head, head)

        val visible = ROW_COUNT[mode] ?: 2
        // 起止时刻（作息表解析不出来就是 null，那节课不参与"正在上/下节"判断）
        val timed = courses.map { it to it.minutes(data.periodTimes) }
        val ongoing = timed.firstOrNull { (_, span) -> span != null && now >= span.first && now <= span.second }?.first
        val upcoming = timed.firstOrNull { (_, span) -> span != null && now < span.first }?.first

        // 今天的课都上完了：卡片清空（用户口径：课都上完了就让它"消失"，别留着最后一节）
        if (ongoing == null && upcoming == null) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_body, View.GONE)
            views.setTextViewText(R.id.widget_empty_title, "今日已下课")
            views.setTextViewText(R.id.widget_empty_tip, "课程都上完啦，休息一下")
            return views
        }
        // 4×4 列表放不下时，从"正在上 / 下节课"那节开始往后显示（不然重要信息被挤掉）
        val shown = if (courses.size > visible && ongoing != null) {
            courses.dropWhile { it !== ongoing }.take(visible)
        } else {
            courses.take(visible)
        }

        if (mode == WidgetMode.SMALL || mode == WidgetMode.FULL) {
            // 单课卡：正在上课 → 下节课（都上完的情况上面已经清空返回了）
            val focus = ongoing ?: upcoming ?: return views
            // 角标 = 第几大节（WakeUp 卡片同款，就是一个数字）
            val badge = if (focus.start >= 1) "${focus.start}" else "—"
            views.setTextViewText(R.id.widget_badge, badge)
            val isOngoing = focus === ongoing
            fillRow(context, views, ROWS[0], focus, data, highlight = isOngoing, showTeacher = mode == WidgetMode.FULL)
            // 2×2 版式里只有第 0 行（碰不存在的 id 会让 RemoteViews 应用失败）
            if (mode == WidgetMode.FULL) {
                for (i in 1 until 4) views.setViewVisibility(ROWS[i].row, View.GONE)
            }
            return views
        }

        // 4×4 列表：门数角标 + 每行一门课（正在上的高亮）
        views.setTextViewText(R.id.widget_badge, "${courses.size} 门")
        for ((index, ids) in ROWS.withIndex()) {
            val course = shown.getOrNull(index)
            if (course == null) {
                views.setViewVisibility(ids.row, View.GONE)
                continue
            }
            views.setViewVisibility(ids.row, View.VISIBLE)
            val isNow = course === ongoing || (ongoing == null && course === upcoming)
            fillRow(context, views, ids, course, data, highlight = isNow, showTeacher = true)
        }
        return views
    }

    /** 一行课程：色条 + 课名 / 地点·教师 + 起止时刻（正在上的那行整行浅色底） */
    private fun fillRow(
        context: Context,
        views: RemoteViews,
        ids: RowIds,
        course: WidgetCourse,
        snap: WidgetSnapshot,
        highlight: Boolean,
        showTeacher: Boolean,
    ) {
        views.setInt(ids.bar, "setBackgroundResource", BAR_RES[WidgetData.courseColorIndex(course.name)])
        views.setTextViewText(ids.name, course.name)
        val meta = buildString {
            if (course.place.isNotEmpty()) append(course.place)
            if (showTeacher && course.teacher.isNotEmpty()) {
                if (isNotEmpty()) append(" · ")
                append(course.teacher)
            }
        }
        views.setTextViewText(ids.meta, meta)
        val (from, to) = snap.clockOf(course)
        views.setTextViewText(ids.start, from)
        views.setTextViewText(ids.end, to)
        views.setTextColor(
            ids.start,
            context.getColor(
                if (highlight) R.color.widget_accent_green else R.color.widget_accent,
            ),
        )
        views.setViewVisibility(ids.meta, if (meta.isEmpty()) View.GONE else View.VISIBLE)
        views.setInt(
            ids.row,
            "setBackgroundResource",
            if (highlight) R.drawable.widget_row_active else R.drawable.widget_row_plain,
        )
    }

    /** 周视图：整周网格画成位图（尺寸取卡片实际像素，1:1 贴上去） */
    private fun buildWeek(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_week)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_TAB, "schedule")
        }
        val pending = PendingIntent.getActivity(
            context,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        val density = context.resources.displayMetrics.density
        var widthDp = 250
        var heightDp = 250
        try {
            val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            if (maxW > 0) widthDp = maxW else if (minW > 0) widthDp = minW
            if (maxH > 0) heightDp = maxH else if (minH > 0) heightDp = minH
        } catch (e: Exception) {
            // 取不到就用 4×4 的标称尺寸（250dp）
        }
        widthDp = widthDp.coerceIn(200, 480)
        heightDp = heightDp.coerceIn(200, 480)

        // 位图要经 Binder 传给桌面进程：给个像素上限兜底（正常 4×4 手机上远达不到），
        // 超了就把渲染密度降下来（fitXY 会等比放大，只是略软，不会糊成一片或传输失败）
        var renderDensity = density
        val pixels = widthDp * heightDp * density * density
        if (pixels > MAX_BITMAP_PIXELS) {
            renderDensity = (density * kotlin.math.sqrt(MAX_BITMAP_PIXELS / pixels)).toFloat()
        }
        val bitmap = WidgetWeekGrid.render(
            context,
            WidgetData.read(context),
            (widthDp * renderDensity).toInt().coerceAtLeast(1),
            (heightDp * renderDensity).toInt().coerceAtLeast(1),
        )
        views.setImageViewBitmap(R.id.widget_week_image, bitmap)
        return views
    }
}
