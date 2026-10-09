import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/core_client.dart';
import '../core/widget_bridge.dart';
import '../models/snapshot.dart';

/// 刷新状态（对应原 `dataRefreshState`：idle/busy/ok/fail）
enum RefreshState { idle, busy, ok, fail }

/// 全局状态：唯一数据源是核心产出的 [Snapshot]，UI 通过 `AppScope.of(context)` 订阅。
class AppStore extends ChangeNotifier {
  AppStore(this.core);

  final CoreClient core;

  Snapshot snapshot = Snapshot.empty;
  RefreshState refreshState = RefreshState.idle;
  bool loggedIn = false;
  bool booted = false;

  /// 刷新失败时的提示（一次性，UI 消费后清空）
  String? toast;

  /// 需要重新登录（会话失效 / 长时间取不到数据）：界面弹一次确认，清掉标记
  bool needRelogin = false;

  /// 外观模式：0 跟随系统 / 1 浅色 / 2 深色（对应原版 appearanceMode）
  /// 桌面开发可用 `MYJLBTC_APPEARANCE=dark` 直接起在深色下截图核对
  int appearanceMode = _initialAppearance();

  /// 桌面开发用环境变量兜底；Android 上会被 loadSettings() 里存过的值覆盖
  static int _initialAppearance() {
    try {
      final value = Platform.environment['MYJLBTC_APPEARANCE']?.trim() ?? '';
      if (value == 'dark') return 2;
      if (value == 'light') return 1;
    } catch (_) {
      // 平台不支持环境变量（Android）时走默认
    }
    return 0;
  }


  /// 课程提醒（Android 实时通知 / Live Updates）
  bool classReminder = false;

  /// MD3 莫奈变色（动态取色）
  bool dynamicColor = false;

  /// 系统是否支持动态取色（Android 12+；桌面 false）
  bool dynamicColorAvailable = false;

  /// 系统是否支持实时通知"上岛"（Android 16+）
  bool liveUpdatesAvailable = false;

  /// 通知权限是否已给
  bool notificationsAllowed = false;

  /// 本机 ROM 的灵动岛接入情况：`{brand, rom, version, required, verdict}`
  /// verdict: supported / low / untested
  Map<String, String> islandStatus = const {};

  /// 灵动岛自测通知是否还挂着
  bool islandTesting = false;

  /// 是否正在「模拟上课」（设置页自测；原生 side 的状态机里塞了一节课）
  bool simulatedRunning = false;

  /// 读设置：Android 从原生 SharedPreferences 取（课程提醒要在应用没运行时也能判断），
  /// 其余平台留在内存（桌面只是开发画板）。
  Future<void> loadSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final res = await _nativeChannel.invokeMethod<Map<Object?, Object?>>(
        'getSettings',
      );
      if (res != null) {
        appearanceMode = (res['appearance'] as num?)?.toInt() ?? 0;
        classReminder = res['classReminder'] == true;
        dynamicColor = res['dynamicColor'] == true;
      }
      final status = await _nativeChannel
          .invokeMethod<Map<Object?, Object?>>('notificationStatus');
      notificationsAllowed = status?['allowed'] == true;
      liveUpdatesAvailable = status?['liveUpdates'] == true;
      islandTesting = status?['testActive'] == true;
      simulatedRunning = status?['simulated'] == true;
      // 上课提醒默认开着：装完第一次打开就申请一次通知权限（只问一次，之后交给设置页）
      if (classReminder && !notificationsAllowed) {
        await _nativeChannel.invokeMethod<bool>(
          'requestNotificationPermissionOnce',
        );
      }
      islandStatus = {
        'brand': '${status?['brand'] ?? ''}',
        'rom': '${status?['rom'] ?? ''}',
        'version': '${status?['version'] ?? ''}',
        'required': '${status?['required'] ?? ''}',
        'verdict': '${status?['verdict'] ?? 'untested'}',
      };
    } catch (e) {
      debugPrint('[MyJLBTC] loadSettings failed: $e');
    }
    notifyListeners();
  }

  Future<void> setAppearanceMode(int mode) async {
    if (appearanceMode == mode) return;
    appearanceMode = mode;
    notifyListeners();
    await _writeSetting('appearance', mode);
  }

  /// 课程提醒开关：打开时先要通知权限，再让原生重排提醒
  Future<void> setClassReminder(bool on) async {
    if (classReminder == on) return;
    classReminder = on;
    if (on && Platform.isAndroid && !notificationsAllowed) {
      try {
        await _nativeChannel.invokeMethod<void>('requestNotificationPermission');
      } catch (_) {
        // 申请失败也不阻塞开关本身
      }
    }
    notifyListeners();
    await _writeSetting('classReminder', on);
    if (Platform.isAndroid) {
      // 授权对话框是异步的，稍后再问一次状态
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        final status = await _nativeChannel
            .invokeMethod<Map<Object?, Object?>>('notificationStatus');
        notificationsAllowed = status?['allowed'] == true;
        islandTesting = status?['testActive'] == true;
        simulatedRunning = status?['simulated'] == true;
        islandStatus = {
          'brand': '${status?['brand'] ?? ''}',
          'rom': '${status?['rom'] ?? ''}',
          'version': '${status?['version'] ?? ''}',
          'required': '${status?['required'] ?? ''}',
          'verdict': '${status?['verdict'] ?? 'untested'}',
        };
        notifyListeners();
      } catch (_) {
        // 忽略
      }
    }
  }

  /// 上次发出的实时通知是否具备「上岛」资格（系统按官文条件判定；设置页自测时显示）
  bool lastPromotable = false;

  /// 灵动岛自测：开一条"示例课程"实时通知 / 收掉它。
  /// 没通知权限时先申请（用户允许后由原生侧直接重发）。
  /// 返回 (是否送出, 这条通知是否具备实时通知资格)。
  Future<(bool, bool)> islandTest(bool on) async {
    if (!Platform.isAndroid) return (false, false);
    if (on && !notificationsAllowed) {
      try {
        await _nativeChannel.invokeMethod<void>('requestNotificationPermission');
      } catch (_) {
        // 忽略
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final status = await _nativeChannel
            .invokeMethod<Map<Object?, Object?>>('notificationStatus');
        notificationsAllowed = status?['allowed'] == true;
      } catch (_) {
        // 忽略
      }
      if (!notificationsAllowed) {
        notifyListeners();
        return (false, false);
      }
    }
    var ok = false;
    var promotable = false;
    try {
      final res = await _nativeChannel
          .invokeMethod<Map<Object?, Object?>>('islandTest', {'on': on});
      ok = res?['ok'] == true;
      promotable = res?['promotable'] == true;
    } catch (e) {
      debugPrint('[MyJLBTC] islandTest failed: $e');
    }
    if (on && ok) {
      islandTesting = true;
      lastPromotable = promotable;
    }
    if (!on) islandTesting = false;
    notifyListeners();
    return (ok, promotable);
  }

  /// 实时通知链路自测：往原生状态机里塞一节课（默认 10 分钟）。
  /// 走的是真实提醒那条链路 —— 进度条每分钟走一格、到点自动收掉。
  /// 返回 (是否送出, 是否具备实时通知资格)。
  Future<(bool, bool)> simulateClass({int minutes = 10}) async {
    if (!Platform.isAndroid) return (false, false);
    if (!notificationsAllowed) {
      try {
        await _nativeChannel.invokeMethod<void>('requestNotificationPermission');
      } catch (_) {
        // 忽略
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final status = await _nativeChannel
            .invokeMethod<Map<Object?, Object?>>('notificationStatus');
        notificationsAllowed = status?['allowed'] == true;
      } catch (_) {
        // 忽略
      }
      if (!notificationsAllowed) {
        notifyListeners();
        return (false, false);
      }
    }
    var ok = false;
    var promotable = false;
    try {
      final res = await _nativeChannel.invokeMethod<Map<Object?, Object?>>(
        'simulateClass',
        {'minutes': minutes},
      );
      ok = res?['ok'] == true;
      promotable = res?['promotable'] == true;
    } catch (e) {
      debugPrint('[MyJLBTC] simulateClass failed: $e');
    }
    if (ok) {
      simulatedRunning = true;
      lastPromotable = promotable;
    }
    notifyListeners();
    return (ok, promotable);
  }

  /// 结束模拟上课（收通知 + 清掉模拟数据）
  Future<void> cancelSimulatedClass() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<bool>('cancelSimulatedClass');
    } catch (e) {
      debugPrint('[MyJLBTC] cancelSimulatedClass failed: $e');
    }
    simulatedRunning = false;
    notifyListeners();
  }

  /// 是否已在"忽略电池优化"白名单（省电策略无限制）
  bool ignoringBatteryOptimizations = false;

  /// 读一次后台运行状态（进设置页时调）
  Future<void> loadBackgroundStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final res = await _nativeChannel
          .invokeMethod<Map<Object?, Object?>>('backgroundStatus');
      ignoringBatteryOptimizations = res?['ignoring'] == true;
      notifyListeners();
    } catch (e) {
      debugPrint('[MyJLBTC] backgroundStatus failed: $e');
    }
  }

  /// 跳到自启动 / 后台无限制设置页（各家页面不同，原生侧依次尝试）
  Future<bool> openBackgroundSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _nativeChannel.invokeMethod<bool>('openBackgroundSettings') ??
          false;
    } catch (e) {
      debugPrint('[MyJLBTC] openBackgroundSettings failed: $e');
      return false;
    }
  }

  /// 请求把小组件钉到桌面（`requestPinAppWidget`）。
  /// 返回 `(ok, supported)`：ok=系统已受理（一般会弹确认框）；
  /// supported=false 表示这个桌面没实现该 API（比如部分 vivo），要提示手动添加。
  Future<(bool, bool)> pinWidget(String mode) async {
    if (!Platform.isAndroid) return (false, false);
    try {
      final res = await _nativeChannel.invokeMethod<Map<Object?, Object?>>(
        'pinWidget',
        {'mode': mode},
      );
      return (res?['ok'] == true, res?['supported'] == true);
    } catch (e) {
      debugPrint('[MyJLBTC] pinWidget failed: $e');
      return (false, false);
    }
  }

  Future<void> setDynamicColor(bool on) async {
    if (dynamicColor == on) return;
    dynamicColor = on;
    notifyListeners();
    await _writeSetting('dynamicColor', on);
  }

  Future<void> _writeSetting(String key, Object value) async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<bool>('setSetting', {
        'key': key,
        'value': value,
      });
    } catch (e) {
      debugPrint('[MyJLBTC] setSetting($key) failed: $e');
    }
  }

  /// 起始页签：桌面卡片点进来时带的（`schedule` → 课表），启动时取一次
  String pendingTab = '';

  static const MethodChannel _nativeChannel = MethodChannel(
    'com.anlanas.myjlbtc/native',
  );

  Future<void> bootstrap() async {
    try {
      if (Platform.isAndroid) {
        pendingTab = await _nativeChannel.invokeMethod<String>('consumeStartTab') ?? '';
      }
      await loadSettings();
      await core.init();
      loggedIn = core.hasCachedData();
      if (loggedIn) {
        snapshot = await core.snapshot();
        unawaited(WidgetBridge.sync(snapshot));
      }
    } catch (e, st) {
      // 核心初始化失败也要进登录页，绝不把用户挂在启动页
      debugPrint('[MyJLBTC] bootstrap failed: $e');
      debugPrint('$st');
      loggedIn = false;
    }
    booted = true;
    notifyListeners();
  }

  /// 首页「刷新」：课表 + 五路同步。
  /// Android 上真核心会先完成校园网关验证，再拉数据。
  /// 手动刷新的总超时：网关验证最多 30s，再加上拉数据 —— 超过这个时间就认为"长时间取不到数据"
  static const Duration refreshTimeout = Duration(seconds: 60);

  Future<void> refresh() async {
    if (refreshState == RefreshState.busy) return;
    refreshState = RefreshState.busy;
    notifyListeners();
    try {
      final okCount = await core.refreshAll().timeout(refreshTimeout);
      snapshot = await core.snapshot();
      unawaited(WidgetBridge.sync(snapshot));
      refreshState = okCount > 0 ? RefreshState.ok : RefreshState.fail;
      final reason = core.lastRefreshError;
      toast = okCount > 0
          ? null
          : '同步失败：${reason.isEmpty ? '请稍后重试' : reason}';
      // 会话已经失效（比如学校侧把会话踢了）→ 直接引导重新登录
      if (okCount == 0 && reason.contains('重新登录')) {
        needRelogin = true;
        toast = null;
      }
    } on TimeoutException {
      refreshState = RefreshState.fail;
      toast = null;
      // 长时间取不到数据（网关/教务都没反应）→ 让用户重新登录一次最省事
      needRelogin = true;
    } catch (e) {
      refreshState = RefreshState.fail;
      toast = '同步失败：$e';
    }
    notifyListeners();
  }

  Future<SmsResult> sendSmsCode(String user, String password) =>
      core.sendSmsCode(user, password);

  /// 本机 CAS 会话是否还有效
  Future<bool> isCasSessionAlive() => core.isCasSessionAlive();

  Future<LoginResult> login(String user, String password, String smsCode) async {
    final result = await core.login(user, password, smsCode);
    if (result.success) {
      loggedIn = true;
      snapshot = await core.snapshot();
      notifyListeners();
      // 登录账号是两大联网时机之一：连带同步一次（原版 postLoginSync 口径），
      // 不阻塞进主界面，后台跑；下次打开只走本地缓存。
      unawaited(refresh());
    }
    return result;
  }

  /// 本机 CAS 会话仍然有效：不走发码/短信，直接进主界面（原版 LoginPage.sendCode 口径）
  Future<void> adoptExistingSession() async {
    loggedIn = true;
    snapshot = await core.snapshot();
    notifyListeners();
    unawaited(WidgetBridge.sync(snapshot));
    unawaited(refresh());
  }

  Future<void> logout() async {
    await core.logout();
    loggedIn = false;
    snapshot = Snapshot.empty;
    refreshState = RefreshState.idle;
    notifyListeners();
  }

  /// 课表缓存时间文案（如「9月28日 10:30 已同步」）
  String get scheduleUpdatedText => core.scheduleUpdatedText();

  void consumeToast() {
    toast = null;
  }
}

/// 把 [AppStore] 挂到 widget 树上：`AppScope.of(context)`
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载：请在 MaterialApp 上方包一层 AppScope');
    return scope!.notifier!;
  }
}
