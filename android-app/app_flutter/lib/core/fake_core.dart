import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/snapshot.dart';
import 'core_client.dart';

/// 开发期假核心：读 `assets/dev_snapshot.json`（由 Rust 核心真实生成，JSON 与真 FFI 同构）。
///
/// 行为约定（模拟真核心的耗时与结果，UI 按真节奏开发）：
/// - `sendSmsCode` / `login` 走 600ms 延迟后成功；
/// - `refreshAll` 走 900ms 延迟后返回成功路数；
/// - Cookie / 网关相关方法返回预置值，便于 F3 前先把流程 UI 搭出来。
class FakeCore implements CoreClient {
  FakeCore({
    this.latency = const Duration(milliseconds: 600),
    this.bootLatency = Duration.zero,
    String? snapshotJson,
    this.startLoggedOut = false,
    this.sessionAlive = false,
    this.refreshOkCount = 5,
    this.refreshError = '',
    this.refreshHangs = false,
  }) : _injectedJson = snapshotJson;

  /// 模拟网络耗时（测试里传 Duration.zero）
  final Duration latency;

  /// 模拟启动时读本地缓存的耗时（默认 0；想看启动页那一帧时给个几百毫秒）
  final Duration bootLatency;

  /// 启动时视为"未登录"（桌面截图登录页用；默认按已同步过处理）
  final bool startLoggedOut;

  /// CAS 会话是否还有效（登录页据此"直接进主界面、不发短信"）
  final bool sessionAlive;

  /// refreshAll 返回的成功路数（0 = 同步失败，用于测"引导重新登录"）
  final int refreshOkCount;

  /// 失败原因（真核心的 lastRefreshError 口径）；含「重新登录」时界面应直接引导重登
  final String refreshError;

  /// 刷新一直不返回（测 60s 超时 → 引导重新登录）
  final bool refreshHangs;

  /// 注入的快照 JSON（测试用；为空时从 assets 读）
  final String? _injectedJson;

  Snapshot? _snapshot;
  bool _loggedIn = false;

  Future<Snapshot> _load() async {
    final raw =
        _injectedJson ??
        await rootBundle.loadString('assets/dev_snapshot.json');
    return Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> init() async {
    // 模拟启动时读本地缓存的耗时（默认 0 = 立即就绪）
    if (bootLatency > Duration.zero) await Future<void>.delayed(bootLatency);
    _snapshot = await _load();
    _loggedIn = !startLoggedOut; // 假数据默认视为"已同步过"
  }

  @override
  bool hasCachedData() => !startLoggedOut && (_snapshot != null || _loggedIn);

  @override
  Future<Snapshot> snapshot() async => _snapshot ??= await _load();

  @override
  Future<bool> isCasSessionAlive() async => sessionAlive;

  @override
  Future<SmsResult> sendSmsCode(String userName, String password) async {
    await Future<void>.delayed(latency);
    if (sessionAlive) {
      return const SmsResult(
        success: true,
        message: '已登录',
        alreadyLoggedIn: true,
      );
    }
    return const SmsResult(success: true, message: '验证码已发送（假数据）');
  }

  @override
  Future<LoginResult> login(
    String userName,
    String password,
    String smsCode,
  ) async {
    await Future<void>.delayed(latency);
    _loggedIn = true;
    return const LoginResult(success: true, message: '登录成功（假数据）');
  }

  @override
  String get lastRefreshError => refreshError;

  @override
  Future<int> refreshAll() async {
    if (refreshHangs) return Completer<int>().future; // 永不返回：等 AppStore 的超时兜底
    await Future<void>.delayed(latency + const Duration(milliseconds: 300));
    return refreshOkCount;
  }

  @override
  Future<String> casCookieHeader() async =>
      'SESSION=fake-session-id';

  @override
  Future<bool> syncWebCookies(List<WebCookieBatch> batches) async {
    await Future<void>.delayed(latency);
    return batches.any((b) => b.$1.contains('campus'));
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
  }

  @override
  String scheduleUpdatedText() {
    final at = _snapshot?.scheduleUpdatedAt ?? 0;
    if (at <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(at);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}月${d.day}日 $hh:$mm 已同步';
  }
}
