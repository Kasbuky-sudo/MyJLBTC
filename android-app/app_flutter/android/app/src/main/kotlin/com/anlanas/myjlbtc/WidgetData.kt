package com.anlanas.myjlbtc

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * 桌面卡片的数据层：读 Dart 侧写下的 `widget_snapshot.json`（见 lib/core/widget_bridge.dart）。
 *
 * 卡片**不依赖 App 是否运行**：快照里带全周课表 + 当前教学周，卡片每次刷新时自己按
 * 「今天星期几 + 当前教学周 + 当前时间」算状态（跨天、隔夜也不会显示错）。
 */
data class WidgetCourse(
    val weekday: Int,
    val start: Int,
    val end: Int,
    val name: String,
    val teacher: String,
    val place: String,
    val weeks: List<Int>,
    /** 直接给时刻（分钟）—— 自测的"模拟课程"不在作息表上，用它覆盖大节换算 */
    val minutesOverride: Pair<Int, Int>? = null,
    /** 直接给时间文案（`12:48 - 12:58`），同上 */
    val timeTextOverride: String? = null,
) {
    /** 大节号 → 该课的 [开始分钟, 结束分钟]；解析不出来返回 null */
    fun minutes(periodTimes: List<String>): Pair<Int, Int>? {
        minutesOverride?.let { return it }
        if (start < 1 || start > periodTimes.size) return null
        val text = periodTimes[start - 1]
        val parts = text.split(" - ")
        if (parts.size != 2) return null
        val from = toMinutes(parts[0])
        val to = toMinutes(parts[1])
        if (from < 0 || to < 0) return null
        return from to to
    }

    /** 该课占的小節行区间（大节 = 2 小節）：第 1 大节 → 第 1、2 小節 */
    val firstSmall: Int get() = (start - 1) * 2 + 1
    val lastSmall: Int get() = end * 2
}

data class WidgetSnapshot(
    val updatedAt: Long,
    val term: String,
    val week: Int,
    val periodTimes: List<String>,
    val courses: List<WidgetCourse>,
) {

    val hasData: Boolean get() = updatedAt > 0L

    /** 某天该上的课（按当前教学周过滤 + 按大节排序） */
    fun coursesOn(weekday: Int): List<WidgetCourse> {
        val out = courses.filter { it.weekday == weekday && inWeek(it) }
        return out.sortedBy { it.start }
    }

    /** 整周（一~日）该上的课 */
    fun coursesOfWeek(): List<WidgetCourse> = courses.filter { inWeek(it) }

    /** 周次过滤：教学周未知（0）或该课周次为空时不过滤（与原版口径一致） */
    private fun inWeek(course: WidgetCourse): Boolean =
        week <= 0 || course.weeks.isEmpty() || course.weeks.contains(week)

    /** 该课的上课时间段文案（大节口径，如 `08:20 - 10:00`）；取不到返回空串 */
    fun timeText(course: WidgetCourse): String {
        course.timeTextOverride?.let { return it }
        return if (course.start >= 1 && course.start <= periodTimes.size) {
            periodTimes[course.start - 1]
        } else {
            ""
        }
    }

    /** 该课的起 / 止时刻（`08:20` / `10:00`）；取不到返回空串 */
    fun clockOf(course: WidgetCourse): Pair<String, String> {
        val text = timeText(course)
        val parts = text.split(" - ")
        return if (parts.size == 2) parts[0] to parts[1] else "" to ""
    }
}

/** 某个绝对时刻的"当天第几分钟" */
private fun minutesOfDay(at: Long): Int {
    val cal = java.util.Calendar.getInstance().apply { timeInMillis = at }
    return cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
}

/** `08:20` → 500（分钟）；解析不出来返回 -1 */
private fun toMinutes(hhmm: String): Int {
    val parts = hhmm.trim().split(":")
    if (parts.size != 2) return -1
    val h = parts[0].toIntOrNull() ?: return -1
    val m = parts[1].toIntOrNull() ?: return -1
    return h * 60 + m
}

object WidgetData {

    private const val SNAPSHOT_FILE = "widget_snapshot.json"

    /** 学校作息（快照里也带一份，这里只做兜底） */
    private val FALLBACK_TIMES = listOf(
        "08:20 - 10:00", "10:20 - 12:00", "13:20 - 15:00",
        "15:20 - 16:50", "18:00 - 19:30", "19:40 - 21:05",
    )

    fun read(context: Context): WidgetSnapshot? = try {
        val file = File(context.filesDir, SNAPSHOT_FILE)
        if (!file.exists()) {
            null
        } else {
            withSimulation(context, parse(JSONObject(file.readText())))
        }
    } catch (e: Exception) {
        null
    }

    /**
     * 把设置页「模拟上课」塞进来的那节课也当成今天的一门课。
     *
     * 卡片和提醒读的是两份数据（卡片读快照、提醒读状态机），自测时两边都该看得见这节"课"，
     * 用户按一下按钮就能同时验证通知和卡片（卡片的到点重画也是靠它才验得出来）。
     */
    private fun withSimulation(context: Context, snap: WidgetSnapshot): WidgetSnapshot {
        val raw = Settings.simulatedSlot(context) ?: return snap
        val sim = try {
            JSONObject(raw)
        } catch (e: Exception) {
            return snap
        }
        val startAt = sim.optLong("startAt", 0L)
        val endAt = sim.optLong("endAt", 0L)
        val now = System.currentTimeMillis()
        if (endAt <= 0L || now > endAt + 5 * 60_000L) return snap
        // 落在哪个大节：先看"现在"处在作息表的哪一段，取不到就按第 1 大节
        val nowMinutes = nowMinutes()
        val period = snap.periodTimes.indexOfFirst { text ->
            val parts = text.split(" - ")
            if (parts.size != 2) return@indexOfFirst false
            val from = toMinutes(parts[0])
            val to = toMinutes(parts[1])
            from >= 0 && to >= 0 && nowMinutes >= from && nowMinutes <= to
        }.let { if (it >= 0) it + 1 else 1 }
        val course = WidgetCourse(
            weekday = todayWeekday(),
            start = period,
            end = period,
            name = sim.optString("name").ifEmpty { "模拟课程（自测）" },
            teacher = sim.optString("teacher"),
            place = sim.optString("place"),
            weeks = emptyList(), // 不过滤周次
            minutesOverride = minutesOfDay(startAt) to minutesOfDay(endAt),
            timeTextOverride = sim.optString("timeText"),
        )
        return snap.copy(courses = snap.courses + course)
    }

    private fun parse(json: JSONObject): WidgetSnapshot {
        val array = json.optJSONArray("courses") ?: JSONArray()
        val courses = (0 until array.length()).mapNotNull { i ->
            val item = array.optJSONObject(i) ?: return@mapNotNull null
            val start = item.optInt("start", 0)
            WidgetCourse(
                weekday = item.optInt("weekday", 0),
                start = start,
                end = item.optInt("end", start),
                name = item.optString("name"),
                teacher = item.optString("teacher"),
                place = item.optString("place"),
                weeks = item.optJSONArray("weeks")?.toIntList() ?: emptyList(),
            )
        }
        val times = json.optJSONArray("periodTimes")?.toStringList()
        return WidgetSnapshot(
            updatedAt = json.optLong("updatedAt", 0L),
            term = json.optString("term"),
            week = json.optInt("week", 0),
            periodTimes = if (times.isNullOrEmpty()) FALLBACK_TIMES else times,
            courses = courses,
        )
    }

    /** 今天星期几（1-7，周一开始；与教务口径一致） */
    fun todayWeekday(): Int {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        return if (day == Calendar.SUNDAY) 7 else day - 1
    }

    fun nowMinutes(): Int {
        val now = Calendar.getInstance()
        return now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
    }

    /** 本周一到周日（含今天那一周，用于周视图表头的日期） */
    fun weekDates(): List<Calendar> {
        val today = Calendar.getInstance()
        val monday = (today.clone() as Calendar).apply {
            add(Calendar.DAY_OF_MONTH, -(todayWeekday() - 1))
        }
        return (0 until 7).map { offset ->
            (monday.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, offset) }
        }
    }

    /** 课程名 → 稳定配色下标（与 Flutter 侧 `_courseColorIndex` 同一算法，同一门课同色） */
    fun courseColorIndex(name: String): Int {
        var hash = 0
        for (ch in name) hash = (hash * 31 + ch.code) % 997
        return hash % 4
    }

    private fun JSONArray.toStringList(): List<String> =
        (0 until length()).mapNotNull { optString(it, "").takeIf { s -> s.isNotEmpty() } }

    private fun JSONArray.toIntList(): List<Int> = (0 until length()).map { optInt(it, 0) }
}
