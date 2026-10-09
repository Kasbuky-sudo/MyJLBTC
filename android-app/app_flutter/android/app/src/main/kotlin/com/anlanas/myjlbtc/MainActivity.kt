package com.anlanas.myjlbtc

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** 从桌面卡片点进来时带的页签（`schedule` = 课表） */
        const val EXTRA_TAB = "tab"

        /** 通知权限请求码（POST_NOTIFICATIONS） */
        private const val REQUEST_NOTIFICATIONS = 4101
    }

    private var native: NativeBridge? = null

    /** 待消费的起始页签：Dart 启动时通过 `consumeStartTab` 取走（取完清空） */
    private var pendingTab: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingTab = intent?.getStringExtra(EXTRA_TAB)
        revealFlutterViewAfterWindowSettles()
    }

    /**
     * 等窗口尺寸稳定后再让 Flutter 内容淡入。
     *
     * Android 12+ 的启动转场会先把窗口按"启动图标那一小块"布局，几帧之后才放大到全屏。
     * 那几帧里 Flutter 已经按小窗口做了一次布局 —— 居中显示的内容看起来就是"整体偏左"
     * （实测偏差 −325px ≈ 半个屏幕）。修法不是改布局（布局是对的），而是**那几帧不画内容**：
     * 先只留原生启动窗口的底色（`launch_background`，和应用页面底色一致），随后淡入。
     */
    private fun revealFlutterViewAfterWindowSettles() {
        window.decorView.post {
            val content = findViewById<ViewGroup>(android.R.id.content) ?: return@post
            val flutterView: View = findFlutterView(content) ?: return@post
            flutterView.alpha = 0f
            flutterView.postDelayed({
                flutterView.animate().alpha(1f).setDuration(160).start()
            }, 140)
        }
    }

    private fun findFlutterView(parent: ViewGroup): View? {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i)
            if (child.javaClass.name.contains("FlutterView")) return child
            if (child is ViewGroup) findFlutterView(child)?.let { return it }
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 应用已在运行时点卡片：记下来，Dart 下次问的时候取走
        intent.getStringExtra(EXTRA_TAB)?.let { tab ->
            pendingTab = tab
            native?.notifyTabRequested(tab)
        }
    }

    override fun onResume() {
        super.onResume()
        // 回到前台补一次评估：可能已经跨过"课前 15 分钟/上课/下课"节点
        ClassReminder.refresh(this)
    }

    /** 取走起始页签（一次性） */
    fun consumePendingTab(): String? {
        val tab = pendingTab
        pendingTab = null
        return tab
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 与校园网关验证相关的桥接（实现未包含在开源仓库中）

        // 原生小能力（Toast / 桌面卡片数据 / 起始页签）
        val nativeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeBridge.CHANNEL,
        )
        val nativeBridge = NativeBridge(this, nativeChannel)
        native = nativeBridge
        nativeChannel.setMethodCallHandler { call, result -> nativeBridge.handle(call, result) }
    }

    /** Android 13+ 的通知权限运行时申请（设置页打开课程提醒时调用） */
    fun requestNotificationPermission() {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU) return
        val granted = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        if (granted) return
        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 授权结果直接落到提醒上：给了就立刻评估一次（可能在课前窗口内）
        if (requestCode == REQUEST_NOTIFICATIONS) ClassReminder.refresh(this)
    }

    override fun onDestroy() {
        native = null
        super.onDestroy()
    }
}
