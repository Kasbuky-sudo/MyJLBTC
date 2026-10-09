import '../models/snapshot.dart';

/// 发码结果
class SmsResult {
  const SmsResult({
    required this.success,
    required this.message,
    this.alreadyLoggedIn = false,
  });

  final bool success;
  final String message;

  /// true = 本机 CAS 会话还有效，压根没发短信（界面直接进主界面）
  final bool alreadyLoggedIn;
}

/// 登录结果
class LoginResult {
  const LoginResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// 核心能力接口：Rust 后端的 Dart 门面。
///
/// - 开发期由 [FakeCore]（assets/dev_snapshot.json）实现，UI 完全不依赖真机；
/// - 上真机时换 `RealCore`（dart:ffi 调 Rust cdylib），接口不变。
abstract class CoreClient {
  /// 恢复本机会话与缓存（启动时调一次）。
  Future<void> init();

  /// 本机有没有同步过数据（决定进主界面还是登录页）。
  bool hasCachedData();

  /// 一次读出全部 UI 数据（纯本地、不联网）。
  Future<Snapshot> snapshot();

  /// 第一步：学号 + 密码换短信验证码。
  Future<SmsResult> sendSmsCode(String userName, String password);

  /// 本机 CAS 会话是否还有效（发码前先问它 —— 会话还活着就不该再走发码/短信那一路）。
  Future<bool> isCasSessionAlive();

  /// 第二步：学号 + 密码 + 短信验证码登录。
  Future<LoginResult> login(String userName, String password, String smsCode);

  /// 手动刷新：课表 + 五路同步（成绩/考试/通知/学籍/学分）。
  /// 返回成功路数（0-5 之外，课表成功也计入；失败返回 0）。
  Future<int> refreshAll();

  /// 最近一次 [refreshAll] 失败的具体原因（成功时清空）。
  /// 界面据此说清是「没登录」「网关没过」还是「教务没响应」，而不是笼统一句失败。
  String get lastRefreshError;

  // 与校园网关验证相关的两个方法（会话 Cookie 交给 Web 视图、把 Web 侧会话灌回核心）
  // 实现未包含在开源仓库中，内部版本里保留。


  /// 退出登录（清会话 Cookie，保留数据缓存）。
  Future<void> logout();

  /// 课表缓存时间文案：`9月28日 10:30 已同步`；没同步过返回空串。
  String scheduleUpdatedText();
}
