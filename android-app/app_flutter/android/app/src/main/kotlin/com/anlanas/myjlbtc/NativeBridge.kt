package com.anlanas.myjlbtc

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 原生小能力通道（目前只有 Toast）。
 *
 * 轻提示走系统 Toast 而不是 Flutter 自绘：不受应用内层叠/玻璃影响、跟随系统深浅色与字号、
 * 也不会挡住页面上的按钮。方法名与参数见 `lib/widgets/app_toast.dart`。
 */
class NativeBridge(
    private val activity: MainActivity,
    private val channel: MethodChannel,
) {

    companion object {
        private const val TAG = "MyJLBTC-Native"
        const val CHANNEL = "com.anlanas.myjlbtc/native"
        const val WIDGET_SNAPSHOT_FILE = "widget_snapshot.json"
    }

    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "toast" -> {
                val message = call.argument<String>("message").orEmpty()
                val long = call.argument<Boolean>("long") == true
                showToast(message, long)
                result.success(null)
            }
            // 桌面卡片：Dart 侧把全周课表快照写过来，再让卡片刷新
            "updateWidget" -> {
                val json = call.argument<String>("json").orEmpty()
                val ok = writeWidgetSnapshot(json)
                if (ok) {
                    ScheduleWidgetProvider.refresh(activity)
                    // 同一份快照也驱动上课提醒（课前 15 分钟 / 进度）
                    ClassReminder.refresh(activity)
                }
                result.success(ok)
            }
            // 卡片点进来时带的页签（见 MainActivity.onNewIntent / onCreate）
            "consumeStartTab" -> result.success(activity.consumePendingTab())
            // 设置读写（外观 / 课程提醒 / 莫奈变色）
            "getSettings" -> result.success(Settings.snapshot(activity))
            "setSetting" -> {
                val key = call.argument<String>("key").orEmpty()
                val value = (call.arguments as? Map<*, *>)?.get("value")
                val ok = Settings.set(activity, key, value)
                // 课程提醒开关一变就重排：开→立刻评估并安排闹钟；关→撤掉通知与闹钟
                if (ok && key == Settings.KEY_CLASS_REMINDER) ClassReminder.refresh(activity)
                result.success(ok)
            }
            // 通知权限：申请（Android 13+ 弹系统对话框）
            "requestNotificationPermission" -> {
                activity.requestNotificationPermission()
                result.success(true)
            }
            // 首次启动时申请一次：上课提醒默认开着，没权限就当场问
            "requestNotificationPermissionOnce" -> {
                val granted = ClassReminder.notificationsAllowed(activity)
                val asked = Settings.permissionAsked(activity)
                if (granted || asked) {
                    Log.i(TAG, "通知权限：granted=$granted asked=$asked，无需再问")
                    result.success(false)
                } else {
                    Settings.setPermissionAsked(activity)
                    Log.i(TAG, "首次启动：申请通知权限")
                    activity.requestNotificationPermission()
                    result.success(true)
                }
            }
            // 通知权限 / 实时通知支持情况 + 本机 ROM 的灵动岛接入情况（设置页展示用）
            "notificationStatus" -> result.success(
                ClassReminder.notificationStatus(activity)
            )
            // 课表数据更新后重排提醒（与桌面卡片同一份快照）
            "refreshClassReminder" -> {
                ClassReminder.refresh(activity)
                result.success(true)
            }
            // 后台运行设置：查当前状态 / 跳到各家的自启动或省电白名单页
            "backgroundStatus" -> result.success(
                mapOf("ignoring" to isIgnoringBatteryOptimizations())
            )
            "openBackgroundSettings" -> result.success(openBackgroundSettings())
            // 一键把小组件钉到桌面（Android 8+；MIUI 还需 INSTALL_SHORTCUT 权限）
            "pinWidget" -> {
                val mode = call.argument<String>("mode").orEmpty()
                result.success(pinWidget(mode))
            }
            // 灵动岛自测：开关测试通知（返回 ok / promotable，promotable = 这条通知是否具备实时通知资格）
            "islandTest" -> {
                val on = call.argument<Boolean>("on") == true
                if (on) {
                    val res = ClassReminder.postTest(activity)
                    if (res["ok"] != true) activity.requestNotificationPermission()
                    result.success(res)
                } else {
                    ClassReminder.cancelTest(activity)
                    result.success(mapOf("ok" to true, "promotable" to false))
                }
            }
            // 实时通知链路自测：往状态机里塞一节课（默认 10 分钟），进度条每分钟走一格、到点自动收掉
            "simulateClass" -> {
                val minutes = call.argument<Int>("minutes") ?: 10
                result.success(ClassReminder.simulateClass(activity, minutes))
            }
            "cancelSimulatedClass" -> {
                ClassReminder.cancelSimulated(activity)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** 本应用是否已在"忽略电池优化"白名单里（省电策略无限制） */
    private fun isIgnoringBatteryOptimizations(): Boolean = try {
        val pm = activity.getSystemService(android.os.PowerManager::class.java)
        pm?.isIgnoringBatteryOptimizations(activity.packageName) ?: false
    } catch (e: Exception) {
        false
    }

    /**
     * 跳到"自启动 / 后台无限制"设置页。
     *
     * 各家页面不一样，按厂商依次尝试（找不到就退到系统的电池优化列表，再退到应用详情页）：
     * 这些页面都不属于公开 API，属于"能跳就跳、跳不过就让用户自己找"的引导。
     */
    private fun openBackgroundSettings(): Boolean {
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        val candidates = buildList {
            when {
                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ->
                    add(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"))
                manufacturer.contains("huawei") || manufacturer.contains("honor") ->
                    add(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
                manufacturer.contains("oppo") || manufacturer.contains("realme") ->
                    add(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"))
                manufacturer.contains("vivo") ->
                    add(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"))
            }
        }
        for (component in candidates) {
            try {
                activity.startActivity(Intent().setComponent(component))
                Log.i(TAG, "打开自启动页：$component")
                return true
            } catch (e: Exception) {
                Log.i(TAG, "自启动页不可用（${component.className}）：${e.message}")
            }
        }
        val pkg = "package:${activity.packageName}"
        for (action in listOf(
            android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        )) {
            try {
                val intent = Intent(action)
                if (action == android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS) {
                    intent.data = android.net.Uri.parse(pkg)
                }
                activity.startActivity(intent)
                Log.i(TAG, "打开后台设置：$action")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "打开 $action 失败：${e.message}")
            }
        }
        return false
    }

    /**
     * 请求把小组件钉到桌面（`AppWidgetManager.requestPinAppWidget`）。
     *
     * 各厂商差异（参考 juejin 那篇实测）：原生/OPPO/华为有系统确认弹窗；
     * 小米需要 `com.android.launcher.permission.INSTALL_SHORTCUT`，MIUI 13 以下直接添加不弹窗；
     * VIVO 上该 API 无效。所以失败时让界面提示"请到桌面长按 → 小组件里手动添加"。
     */
    private fun pinWidget(mode: String): Map<String, Any> {
        val manager = android.appwidget.AppWidgetManager.getInstance(activity)
        val supported = manager.isRequestPinAppWidgetSupported
        if (!supported) {
            Log.i(TAG, "requestPinAppWidget 不被支持（桌面未实现），让用户手动添加")
            return mapOf("ok" to false, "supported" to false)
        }
        val cls = when (mode) {
            "small" -> ScheduleWidgetSmallProvider::class.java
            "list" -> ScheduleWidgetListProvider::class.java
            "week" -> ScheduleWidgetWeekProvider::class.java
            else -> ScheduleWidgetProvider::class.java
        }
        val provider = android.content.ComponentName(activity, cls)
        val success = android.app.PendingIntent.getBroadcast(
            activity,
            10,
            Intent().setComponent(provider).setAction(ScheduleWidgetProvider.ACTION_PINNED),
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
        )
        return try {
            val ok = manager.requestPinAppWidget(provider, null, success)
            Log.i(TAG, "requestPinAppWidget($mode) -> $ok")
            mapOf("ok" to ok, "supported" to true)
        } catch (e: Exception) {
            // 官方要求调用方有前台界面；没 Activity 时会抛 IllegalStateException
            Log.w(TAG, "requestPinAppWidget failed: ${e.message}")
            mapOf("ok" to false, "supported" to true)
        }
    }

    private fun writeWidgetSnapshot(json: String): Boolean = try {
        java.io.File(activity.filesDir, WIDGET_SNAPSHOT_FILE).writeText(json)
        true
    } catch (e: Exception) {
        false
    }

    private fun showToast(message: String, long: Boolean) {
        if (message.isEmpty()) return
        // Toast 必须在主线程 show
        main.post {
            Toast.makeText(
                activity,
                message,
                if (long) Toast.LENGTH_LONG else Toast.LENGTH_SHORT,
            ).show()
        }
    }

    /** 应用已在运行时点桌面卡片：反向通知 Dart 切页签（Dart 侧监听 `openTab`） */
    fun notifyTabRequested(tab: String) {
        main.post { channel.invokeMethod("openTab", tab, null) }
    }
}
