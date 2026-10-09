package com.anlanas.myjlbtc

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * 课程提醒：课前 15 分钟起用**实时通知（Live Updates）**提醒，上课期间显示进度。
 *
 * - Android 16（API 36）+ 且用户允许推广通知时，这条 ongoing 通知会以"上岛"的形式出现
 *   （状态栏芯片 / 锁屏 / AOD），靠 `setRequestPromotedOngoing(true)` + `ProgressStyle` 拿到资格；
 * - 更早的系统（Android 8+）退化成普通常驻通知，同样有进度条；
 * - 数据源与桌面卡片同一份 `filesDir/widget_snapshot.json`，所以**不依赖应用是否在运行**；
 * - **进度条必须自己刷**：`ProgressStyle` 的进度是"发一次画一格"，系统不会按时间推进
 *   （android-36 里 `Segment(int length)` 只有长度、`getProgressMax()` 只由段长决定，
 *   没有任何时间语义），所以提醒挂着的期间每分钟重发一次，进度条才走得动；
 * - 通知只挂"课前 15 分钟 → 下课"这一段：状态一旦翻成 NONE 立刻 cancel，
 *   另外每次发通知都带 `setTimeoutAfter(下课 + 90s)` 兜底 —— 就算闹钟被待机/装包更新吃掉，
 *   通知也不会挂在下课之后；
 * - 时间本身还是交给系统 chronometer 走（倒计时/正计时），节拍只负责推进度与到点收尾。
 */
object ClassReminder {
    private const val TAG = "MyJLBTC-Reminder"
    private const val CHANNEL_ID = "class_reminder"
    private const val NOTIFICATION_ID = 1001

    /** 灵动岛自测用的通知 id（与真实提醒分开，互不干扰） */
    private const val TEST_NOTIFICATION_ID = 1002

    /** 上课前多少分钟开始提醒 */
    const val LEAD_MINUTES = 15

    /** 进度条节拍：每分钟重发一次（系统不会自己推进 ProgressStyle 的进度） */
    private const val TICK_MS = 60_000L

    /** 下课后再宽限这么久才让系统自动收掉（避免正好卡在下课那一刻） */
    private const val END_GRACE_MS = 90_000L

    /**
     * 请求推广常驻通知的 extra（官文 `EXTRA_REQUEST_PROMOTED_ONGOING`）。
     * 它在 stubs 里是隐藏常量，这里用同名字符串；`NotificationCompat.Builder#setRequestPromotedOngoing`
     * 内部写的也是这个键。
     */
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    /** 划掉通知的 action / 附带的那节课开始时刻 */
    const val ACTION_DISMISSED = "com.anlanas.myjlbtc.CLASS_REMINDER_DISMISSED"
    const val EXTRA_SLOT_START = "slotStart"

    /** 上次发出去的通知是否具备「实时通知（上岛）」资格（自测结果回传给设置页） */
    @Volatile
    private var lastPromotable = false

    /** 学校作息兜底（与 Dart 侧 bigPeriodTimes 一致） */
    private val FALLBACK_TIMES = listOf(
        "08:20 - 10:00", "10:20 - 12:00", "13:20 - 15:00",
        "15:20 - 16:50", "18:00 - 19:30", "19:40 - 21:05",
    )

    private data class Slot(
        val name: String,
        val place: String,
        val teacher: String,
        val timeText: String,
        val startMin: Int,
        val endMin: Int,
        val startAt: Long,
        val endAt: Long,
    )

    private enum class State { NONE, SOON, ONGOING }

    private data class Plan(
        val state: State,
        val slot: Slot?,
        val progress: Int,
        val progressMax: Int,
        /** 状态节点（课前 15 分钟 / 上课 / 下课）唤醒时刻 */
        val wakeAt: Long?,
        /** 进度节拍唤醒时刻：提醒挂着时每分钟一次，让进度条动起来 */
        val tickAt: Long?,
    )

    // ---------------- 对外 ----------------

    private fun manager(context: Context): NotificationManager? =
        context.getSystemService(NotificationManager::class.java)

    /** 通知权限是否已给（Android 13+ 需要运行时授权，另外用户可能整体关了通知） */
    fun notificationsAllowed(context: Context): Boolean {
        val enabled = manager(context)?.areNotificationsEnabled() ?: false
        if (!enabled) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** 系统是否支持"推广通知"（上岛）——Android 16+ */
    fun supportsLiveUpdates(): Boolean = Build.VERSION.SDK_INT >= 36

    /**
     * 重新评估并（必要时）发出/更新/撤掉提醒，同时安排好下一次唤醒。
     * 调用点：应用同步数据后、开关切换后、闹钟到点时。
     */
    fun refresh(context: Context) {
        try {
            ensureChannel(context)
            // 自测（模拟课程）不看提醒总开关：它是排查工具，用户关掉提醒也该能验
            val simulating = simulatedSlot(context) != null
            if (!Settings.classReminder(context) && !simulating) {
                cancel(context)
                return
            }
            if (!notificationsAllowed(context)) {
                Log.i(TAG, "通知未授权，跳过提醒")
                return
            }
            val payload = readSnapshot(context)
            if (payload == null) {
                Log.i(TAG, "没有课表快照，跳过提醒")
                cancel(context)
                return
            }
            val plan = plan(context, payload)
            Log.i(
                TAG,
                "state=${plan.state} slot=${plan.slot?.name ?: "-"} " +
                    "progress=${plan.progress}/${plan.progressMax} " +
                    "wakeAt=${plan.wakeAt?.let { msToTime(it) } ?: "-"} " +
                    "tickAt=${plan.tickAt?.let { msToTime(it) } ?: "-"}",
            )
            var tick = plan.tickAt
            when (plan.state) {
                State.NONE -> cancel(context)
                // 用户把这节课的实时通知划掉了就别再弹（官文：不要重新发布已被关闭的实时更新）
                State.SOON, State.ONGOING -> {
                    val dismissed = Settings.dismissedSlot(context)
                    if (plan.slot != null && plan.slot.startAt == dismissed) {
                        Log.i(TAG, "这节课的通知被用户划掉了，不再重复弹")
                        tick = null // 划掉之后不必再逐分钟唤醒，只留下课节点收尾
                    } else {
                        post(context, plan)
                    }
                }
            }
            // 节点闹钟与进度节拍取更早的那个（同一颗 PendingIntent，后设的顶掉前一个）
            scheduleWake(context, earliestWake(plan.wakeAt, tick))
        } catch (e: Exception) {
            Log.w(TAG, "refresh failed: ${e.message}")
        }
    }

    /**
     * 关掉**真实**上课提醒（开关关闭 / 当前无课 / 退出时用）。
     * 不动自测通知：那是用户手动发的探针，要留在通知栏里让他去状态栏看，
     * 只能由设置页那个按钮（[cancelTest]）收回。
     */
    fun cancel(context: Context) {
        cancelAlarm(context)
        manager(context)?.cancel(NOTIFICATION_ID)
    }

    /** 设置页要展示的一组状态：通知权限、是否支持实时通知、本机 ROM 的灵动岛接入情况 */
    fun notificationStatus(context: Context): Map<String, Any> = buildMap {
        put("allowed", notificationsAllowed(context))
        put("liveUpdates", supportsLiveUpdates())
        put("testActive", isTestActive(context))
        put("simulated", simulatedSlot(context) != null)
        putAll(RomSupport.snapshot())
    }

    // ---------------- 灵动岛自测 ----------------

    /** 自测通知是否还挂着 */
    fun isTestActive(context: Context): Boolean = try {
        manager(context)?.activeNotifications?.any { it.id == TEST_NOTIFICATION_ID } == true
    } catch (e: Exception) {
        false
    }

    /**
     * 发一条"示例课程"的实时通知（与真实提醒同一条通道、同样的进度 + 计时样式），
     * 让用户自己看状态栏 / 锁屏 / 灵动岛有没有反应。返回是否送出（没通知权限就 false）。
     */
    fun postTest(context: Context): Map<String, Any> {
        if (!notificationsAllowed(context)) {
            Log.i(TAG, "自测：没有通知权限")
            return mapOf("ok" to false, "promotable" to false)
        }
        ensureChannel(context)
        val start = System.currentTimeMillis() - 30 * 60_000L // 假装 30 分钟前开始上课
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_class_reminder)
            .setContentTitle("正在上课 · 灵动岛测试")
            .setContentText("示例课程 · 18:00 - 19:30 · 三教101 · 王老师")
            .setContentIntent(openScheduleIntent(context))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setShowWhen(true)
            .setWhen(start)
            .setUsesChronometer(true)
            .setChronometerCountDown(false)
            .setShortCriticalText("测试中")
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_EVENT)

        if (Build.VERSION.SDK_INT >= 36) {
            val segment = Notification.ProgressStyle.Segment(90)
            builder.style = Notification.ProgressStyle()
                .setProgress(30)
                .setProgressSegments(listOf(segment))
                .setStyledByProgress(false)
                .setProgressTrackerIcon(
                    android.graphics.drawable.Icon.createWithResource(
                        context,
                        R.drawable.ic_class_reminder,
                    )
                )
            if (manager(context)?.canPostPromotedNotifications() == true) {
                builder.extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                builder.setFlag(Notification.FLAG_PROMOTED_ONGOING, true)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.style = Notification.BigTextStyle()
                .bigText(
                    "正在上课 · 灵动岛测试" + String.format("%n") +
                        "示例课程 · 18:00 - 19:30 · 三教101 · 王老师"
                )
        }
        try {
            val notification = builder.build()
            if (Build.VERSION.SDK_INT >= 36) {
                lastPromotable = notification.hasPromotableCharacteristics()
            }
            manager(context)?.notify(TEST_NOTIFICATION_ID, notification)
            Log.i(
                TAG,
                "自测通知已发送（Android ${Build.VERSION.SDK_INT}，" +
                    "推广权限=${manager(context)?.canPostPromotedNotifications() ?: false}，" +
                    "promotable=$lastPromotable）",
            )
            return mapOf("ok" to true, "promotable" to lastPromotable)
        } catch (e: Exception) {
            Log.w(TAG, "自测通知发送失败: ${e.message}")
            return mapOf("ok" to false, "promotable" to false)
        }
    }

    /** 收掉自测通知 */
    fun cancelTest(context: Context) {
        manager(context)?.cancel(TEST_NOTIFICATION_ID)
    }

    /** 点通知统一打开应用并落在课表页 */
    private fun openScheduleIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_TAB, "schedule")
        }
        return PendingIntent.getActivity(
            context,
            3,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ---------------- 计算 ----------------

    /** 节点与节拍里更早的未来时刻（都为空 = 不用唤醒） */
    private fun earliestWake(vararg at: Long?): Long? {
        val now = System.currentTimeMillis()
        return at.filterNotNull().filter { it > now }.minOrNull()
    }

    /** 下一个整分钟（节拍对齐到分钟边界，重发的进度值才好看） */
    private fun nextTick(now: Long): Long = now - now % TICK_MS + TICK_MS

    private fun plan(context: Context, payload: JSONObject): Plan {
        // 自测用的「模拟课程」：有它在就只按它算（走的是和真实课程完全一样的状态机）
        simulatedSlot(context)?.let { slot ->
            return planFor(listOf(slot), payload)
        }
        val week = payload.optInt("week", 0)
        val times = payload.optJSONArray("periodTimes")?.toStringList()
            ?.takeIf { it.isNotEmpty() } ?: FALLBACK_TIMES
        val cal = Calendar.getInstance()
        val today = todayWeekday(cal)
        val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val nowMs = System.currentTimeMillis()

        val slots = mutableListOf<Slot>()
        val courses = payload.optJSONArray("courses") ?: JSONArray()
        for (i in 0 until courses.length()) {
            val item = courses.optJSONObject(i) ?: continue
            if (item.optInt("weekday", 0) != today) continue
            val weeks = item.optJSONArray("weeks")?.toIntList() ?: emptyList()
            if (week > 0 && weeks.isNotEmpty() && !weeks.contains(week)) continue
            val startPeriod = item.optInt("start", 0)
            if (startPeriod < 1 || startPeriod > times.size) continue
            val span = parseSpan(times[startPeriod - 1]) ?: continue
            slots.add(
                Slot(
                    name = item.optString("name"),
                    place = item.optString("place"),
                    teacher = item.optString("teacher"),
                    timeText = times[startPeriod - 1],
                    startMin = span.first,
                    endMin = span.second,
                    startAt = atMinutesToday(cal, span.first),
                    endAt = atMinutesToday(cal, span.second),
                )
            )
        }
        slots.sortBy { it.startMin }

        return planFor(slots, payload)
    }

    /**
     * 状态机：正在上课 / 马上上课（15 分钟内）/ 无。
     * 前两个状态还要给「每分钟的进度节拍」—— 没有它进度条就是钉死的一格。
     */
    private fun planFor(
        slots: List<Slot>,
        payload: JSONObject,
        week: Int = payload.optInt("week", 0),
        times: List<String> = payload.optJSONArray("periodTimes")?.toStringList()
            ?.takeIf { it.isNotEmpty() } ?: FALLBACK_TIMES,
    ): Plan {
        val cal = Calendar.getInstance()
        val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val tick = nextTick(System.currentTimeMillis())

        val ongoing = slots.firstOrNull { nowMin >= it.startMin && nowMin <= it.endMin }
        if (ongoing != null) {
            val total = (ongoing.endMin - ongoing.startMin).coerceAtLeast(1)
            val done = (nowMin - ongoing.startMin).coerceIn(0, total)
            return Plan(State.ONGOING, ongoing, done, total, ongoing.endAt, tick)
        }

        val upcoming = slots.firstOrNull { nowMin < it.startMin }
        if (upcoming != null && upcoming.startMin - nowMin <= LEAD_MINUTES) {
            val total = LEAD_MINUTES
            val left = (upcoming.startMin - nowMin).coerceIn(0, LEAD_MINUTES)
            return Plan(State.SOON, upcoming, total - left, total, upcoming.startAt, tick)
        }

        // 还没到提醒窗口：在「下一节课前 15 分钟」醒来（今天没有课就安排在明天第一节前）；
        // 没通知挂着就不需要节拍
        val soonAtToday = upcoming?.let { it.startAt - LEAD_MINUTES * 60_000L }
        val wake = soonAtToday ?: firstSlotTomorrowAt(payload, week, times)
        return Plan(State.NONE, null, 0, 0, wake, null)
    }

    // ---------------- 自测用「模拟课程」 ----------------

    /** 模拟课程还在有效期内（结束后 5 分钟内）就返回它，过期自动清掉 */
    private fun simulatedSlot(context: Context): Slot? {
        val raw = Settings.simulatedSlot(context) ?: return null
        return try {
            val json = JSONObject(raw)
            val startAt = json.optLong("startAt", 0L)
            val endAt = json.optLong("endAt", 0L)
            if (endAt <= 0L || System.currentTimeMillis() > endAt + 5 * 60_000L) {
                Settings.clearSimulatedSlot(context)
                null
            } else {
                Slot(
                    name = json.optString("name"),
                    place = json.optString("place"),
                    teacher = json.optString("teacher"),
                    timeText = json.optString("timeText"),
                    startMin = minutesOfDay(startAt),
                    endMin = minutesOfDay(endAt),
                    startAt = startAt,
                    endAt = endAt,
                )
            }
        } catch (e: Exception) {
            Settings.clearSimulatedSlot(context)
            null
        }
    }

    private fun minutesOfDay(at: Long): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = at }
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    /**
     * 设置页自测：往状态机里塞「一节课」（默认 10 分钟，1 分钟前开始），
     * 走的是真实提醒那条完整链路 —— 进度条每分钟走一格、到点自动收掉。
     */
    fun simulateClass(context: Context, minutes: Int): Map<String, Any> {
        if (!notificationsAllowed(context)) return mapOf("ok" to false, "promotable" to false)
        val span = minutes.coerceIn(2, 60)
        val now = System.currentTimeMillis()
        val start = now - TICK_MS
        val end = now + span * TICK_MS
        Settings.setSimulatedSlot(
            context,
            JSONObject().apply {
                put("name", "模拟课程（自测）")
                put("place", "三教101")
                put("teacher", "自测")
                put("timeText", "${msToTime(start)} - ${msToTime(end)}")
                put("startAt", start)
                put("endAt", end)
            }.toString(),
        )
        Log.i(TAG, "开始模拟上课：$span 分钟（${msToTime(start)} - ${msToTime(end)}）")
        refresh(context)
        return mapOf("ok" to true, "promotable" to lastPromotable)
    }

    /** 结束模拟（收通知 + 清掉模拟数据） */
    fun cancelSimulated(context: Context) {
        Settings.clearSimulatedSlot(context)
        cancel(context)
    }

    /** 明天第一节大节的绝对时刻 - 15 分钟（今天没课了也要安排下一天） */
    private fun firstSlotTomorrowAt(payload: JSONObject, week: Int, times: List<String>): Long? {
        val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, 1) }
        val weekday = todayWeekday(cal)
        var earliest: Int? = null
        val courses = payload.optJSONArray("courses") ?: return null
        for (i in 0 until courses.length()) {
            val item = courses.optJSONObject(i) ?: continue
            if (item.optInt("weekday", 0) != weekday) continue
            val weeks = item.optJSONArray("weeks")?.toIntList() ?: emptyList()
            if (week > 0 && weeks.isNotEmpty() && !weeks.contains(week)) continue
            val startPeriod = item.optInt("start", 0)
            if (startPeriod < 1 || startPeriod > times.size) continue
            val span = parseSpan(times[startPeriod - 1]) ?: continue
            earliest = minOf(earliest ?: span.first, span.first)
        }
        val start = earliest ?: return null
        return atMinutesToday(cal, start) - LEAD_MINUTES * 60_000L
    }

    /** 某个"当天第几分钟"的绝对毫秒数 */
    private fun atMinutesToday(cal: Calendar, minutes: Int): Long {
        val copy = cal.clone() as Calendar
        copy.set(Calendar.HOUR_OF_DAY, minutes / 60)
        copy.set(Calendar.MINUTE, minutes % 60)
        copy.set(Calendar.SECOND, 0)
        copy.set(Calendar.MILLISECOND, 0)
        return copy.timeInMillis
    }

    private fun parseSpan(timeText: String): Pair<Int, Int>? {
        val parts = timeText.split(" - ")
        if (parts.size != 2) return null
        val a = toMinutes(parts[0]) ?: return null
        val b = toMinutes(parts[1]) ?: return null
        return a to b
    }

    private fun toMinutes(hhmm: String): Int? {
        val parts = hhmm.trim().split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return h * 60 + m
    }

    private fun todayWeekday(cal: Calendar): Int {
        val day = cal.get(Calendar.DAY_OF_WEEK)
        return if (day == Calendar.SUNDAY) 7 else day - 1
    }

    // ---------------- 通知 ----------------

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(context) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "上课提醒",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "上课前 15 分钟提醒（支持 Android 16 实时通知）"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun post(context: Context, plan: Plan) {
        val slot = plan.slot ?: return
        val soon = plan.state == State.SOON
        val title = if (soon) "即将上课" else "正在上课"
        val detail = buildString {
            append(slot.timeText)
            if (slot.place.isNotEmpty()) append(" · ").append(slot.place)
            if (slot.teacher.isNotEmpty()) append(" · ").append(slot.teacher)
        }

        val pending = openScheduleIntent(context)

        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_class_reminder)
            .setContentTitle("$title · ${slot.name}")
            .setContentText(detail)
            .setContentIntent(pending)
            // 状态栏芯片上的短文本（官文：状态用 setShortCriticalText 或 setWhen 表达）
            .setShortCriticalText(if (soon) "即将上课" else "上课中")
            // 锁屏 / 息屏（AOD）上要能读到内容：默认是 PRIVATE，安全锁屏会把正文涂掉，
            // 只有 PUBLIC 才允许在这些界面展开显示（课名 / 地点 / 教师本身不敏感）
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            // 用户划掉就记下来，同一节课不再弹
            .setDeleteIntent(dismissIntent(context, slot.startAt))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setShowWhen(true)
            .setWhen(slot.startAt)
            .setUsesChronometer(true)
            .setChronometerCountDown(soon) // 课前倒计时、上课正计时 —— 系统自己走，进度条靠节拍重发
            .setCategory(Notification.CATEGORY_EVENT)
            // 兜底：下课（+90s 宽限）后由系统自动收掉这条通知。
            // 光靠"下课那一刻的闹钟"不够稳：闹钟可能因待机被推后、或被装包更新清掉，
            // 那条通知就会一直挂在通知栏（用户实测就是这个现象）。
            .setTimeoutAfter(
                (slot.endAt + END_GRACE_MS - System.currentTimeMillis()).coerceAtLeast(TICK_MS),
            )

        if (Build.VERSION.SDK_INT >= 36) {
            // Android 16 实时通知（Live Updates）：进度样式 + 推广标志 = 有资格"上岛"
            //（状态栏芯片 / 锁屏 / AOD；最终是否推广由系统与用户设置决定）
            val segment = Notification.ProgressStyle.Segment(plan.progressMax.coerceAtLeast(1))
            builder.style = Notification.ProgressStyle()
                .setProgress(plan.progress.coerceIn(0, plan.progressMax.coerceAtLeast(1)))
                .setProgressSegments(listOf(segment))
                .setStyledByProgress(false)
                .setProgressTrackerIcon(
                    android.graphics.drawable.Icon.createWithResource(
                        context,
                        R.drawable.ic_class_reminder,
                    )
                )
            val canPromote = manager(context)?.canPostPromotedNotifications() ?: false
            if (canPromote) {
                // 官文口径：用 EXTRA_REQUEST_PROMOTED_ONGOING 请求推广
                //（FLAG_PROMOTED_ONGOING 是系统标记"已推广"用的，光设 flag 不起作用 —— 真机上验过）
                builder.extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                builder.setFlag(Notification.FLAG_PROMOTED_ONGOING, true)
            } else {
                Log.i(TAG, "没有推广通知权限（POST_PROMOTED_NOTIFICATIONS），按普通常驻通知发")
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.style = Notification.BigTextStyle().bigText("$title · ${slot.name}\n$detail")
        }

        try {
            val notification = builder.build()
            if (Build.VERSION.SDK_INT >= 36) {
                // 是否具备实时通知资格（官文口径的资格条件），排查"上不了岛"时看这一行
                lastPromotable = notification.hasPromotableCharacteristics()
                Log.i(
                    TAG,
                    "发通知：promotable=$lastPromotable timeoutAfter=${notification.getTimeoutAfter()}ms",
                )
            }
            manager(context)?.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "notify denied: ${e.message}")
        }
    }

    // ---------------- 闹钟 ----------------

    fun scheduleWake(context: Context, atMillis: Long?) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = wakeIntent(context)
        if (atMillis == null || atMillis <= System.currentTimeMillis()) {
            manager.cancel(pending)
            return
        }
        // 精确闹钟要 SCHEDULE_EXACT_ALARM 授权；没授权就退化成允许待机的近似闹钟
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        try {
            if (canExact) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
            }
        } catch (e: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        }
    }

    private fun cancelAlarm(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        manager.cancel(wakeIntent(context))
    }

    /** 划掉通知的 PendingIntent：带着那节课的开始时刻，供 refresh 判断"这节课别再弹" */
    private fun dismissIntent(context: Context, slotStartAt: Long): PendingIntent {
        val intent = Intent(context, ClassReminderReceiver::class.java).apply {
            action = ACTION_DISMISSED
            putExtra(EXTRA_SLOT_START, slotStartAt)
        }
        return PendingIntent.getBroadcast(
            context,
            4,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun wakeIntent(context: Context): PendingIntent {
        val intent = Intent(context, ClassReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ---------------- 工具 ----------------

    private fun readSnapshot(context: Context): JSONObject? = try {
        val file = File(context.filesDir, NativeBridge.WIDGET_SNAPSHOT_FILE)
        if (!file.exists()) null else JSONObject(file.readText())
    } catch (e: Exception) {
        null
    }

    private fun msToTime(ms: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = ms }
        return "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    }

    private fun JSONArray.toStringList(): List<String> =
        (0 until length()).mapNotNull { optString(it, "").takeIf { s -> s.isNotEmpty() } }

    private fun JSONArray.toIntList(): List<Int> = (0 until length()).map { optInt(it, 0) }
}

/** 闹钟到点 / 用户划掉通知：都走这里 */
class ClassReminderReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ClassReminder.ACTION_DISMISSED) {
            // 用户划掉了：记住这节课，别再重复弹（换下一节课不受影响）
            val slotStart = intent.getLongExtra(ClassReminder.EXTRA_SLOT_START, 0L)
            if (slotStart > 0) Settings.setDismissedSlot(context, slotStart)
            Log.i("MyJLBTC-Reminder", "实时通知被划掉，slotStart=$slotStart")
            return
        }
        ClassReminder.refresh(context)
    }
}
