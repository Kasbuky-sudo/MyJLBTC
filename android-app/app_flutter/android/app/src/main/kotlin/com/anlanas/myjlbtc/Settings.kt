package com.anlanas.myjlbtc

import android.content.Context
import android.content.SharedPreferences

/**
 * 应用设置（原生侧存储）。
 *
 * 为什么放在原生：课程提醒要在**应用没运行时**（闹钟触发）判断开关状态，
 * 而莫奈变色/外观是纯界面选项。统一放 SharedPreferences，Dart 侧通过
 * `NativeBridge` 的 `getSettings` / `setSetting` 读写。
 */
object Settings {
    private const val FILE = "myjlbtc_settings"
    private const val KEY_SIMULATED_SLOT = "simulatedSlot"

    /** 外观：0 跟随系统 / 1 浅色 / 2 深色 */
    const val KEY_APPEARANCE = "appearance"

    /** 课程提醒（Android 实时通知 / Live Updates）开关 */
    const val KEY_CLASS_REMINDER = "classReminder"

    /** MD3 莫奈变色（Material You 动态取色）开关 */
    const val KEY_DYNAMIC_COLOR = "dynamicColor"

    /** 用户划掉实时通知的那节课（存该节课的开始时刻），同一节课不再重复弹 */
    const val KEY_DISMISSED_SLOT = "dismissedSlot"

    /** 通知权限是否已经请求过一次（申请只在首次启动做一次，之后由设置页手动开） */
    const val KEY_PERMISSION_ASKED = "notificationPermissionAsked"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun appearance(context: Context): Int = prefs(context).getInt(KEY_APPEARANCE, 0)

    /** 上课提醒默认**开启**（安装后第一次打开就能收到提醒；用户可在设置里关掉） */
    fun classReminder(context: Context): Boolean =
        prefs(context).getBoolean(KEY_CLASS_REMINDER, true)

    fun dynamicColor(context: Context): Boolean =
        prefs(context).getBoolean(KEY_DYNAMIC_COLOR, false)

    /** 被划掉的那节课的开始时刻（0 = 没有） */
    fun dismissedSlot(context: Context): Long = prefs(context).getLong(KEY_DISMISSED_SLOT, 0L)

    /** 自测用的「模拟课程」（JSON：名称/地点/教师/起止时刻）；为空表示没有模拟 */
    fun simulatedSlot(context: Context): String? =
        prefs(context).getString(KEY_SIMULATED_SLOT, null)?.takeIf { it.isNotEmpty() }

    fun setSimulatedSlot(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SIMULATED_SLOT, json).apply()
    }

    fun clearSimulatedSlot(context: Context) {
        prefs(context).edit().remove(KEY_SIMULATED_SLOT).apply()
    }

    fun setDismissedSlot(context: Context, startAt: Long) {
        prefs(context).edit().putLong(KEY_DISMISSED_SLOT, startAt).apply()
    }

    fun permissionAsked(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PERMISSION_ASKED, false)

    fun setPermissionAsked(context: Context) {
        prefs(context).edit().putBoolean(KEY_PERMISSION_ASKED, true).apply()
    }

    fun snapshot(context: Context): Map<String, Any> = mapOf(
        KEY_APPEARANCE to appearance(context),
        KEY_CLASS_REMINDER to classReminder(context),
        KEY_DYNAMIC_COLOR to dynamicColor(context),
    )

    /** 写一项设置；返回是否写入成功 */
    fun set(context: Context, key: String, value: Any?): Boolean = try {
        val editor = prefs(context).edit()
        when (key) {
            KEY_APPEARANCE -> editor.putInt(KEY_APPEARANCE, (value as? Number)?.toInt() ?: 0)
            KEY_CLASS_REMINDER -> editor.putBoolean(KEY_CLASS_REMINDER, value == true)
            KEY_DYNAMIC_COLOR -> editor.putBoolean(KEY_DYNAMIC_COLOR, value == true)
            else -> return false
        }
        editor.apply()
        true
    } catch (e: Exception) {
        false
    }
}
