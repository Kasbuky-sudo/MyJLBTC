import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/core/fake_core.dart';
import 'package:myjlbtc/main.dart';
import 'package:myjlbtc/state/app_store.dart';

import 'test_helpers.dart';

/// 「点刷新长时间取不到数据 → 引导重新登录」的行为测试。
///
/// 触发口径（见 AppStore.refresh）：
/// - 会话失效（失败原因里带「重新登录」）→ 立刻弹；
/// - 60s 还没返回（网关/教务没反应）→ 超时弹。
/// 两个路径都只在"手动刷新"时生效，且弹过一次后清标记（点「稍后」才会再弹）。
void main() {
  Future<void> boot(WidgetTester tester, FakeCore core) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyJLBTCApp(core: core));
    await tester.pump();
    await tester.pump();
  }

  /// 首页数据卡右上角的「刷新」按钮
  Future<void> tapRefresh(WidgetTester tester) async {
    await tapAndSettle(tester, find.text('刷新'));
  }

  testWidgets('会话失效（同步失败 + 需要重新登录）→ 弹确认框，可一键回登录页', (tester) async {
    final core = FakeCore(
      snapshotJson: loadDevJson(),
      latency: Duration.zero,
      refreshOkCount: 0,
      refreshError: '登录状态已失效，请重新登录',
    );
    await boot(tester, core);

    await tapRefresh(tester);
    // refresh() 是异步的：把 300ms 假延迟和后续两帧推完
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('需要重新登录'), findsOneWidget);
    expect(find.textContaining('重新登录一次通常就能恢复'), findsOneWidget);

    await tapAndSettle(tester, find.text('重新登录'), last: true);
    // 退出登录 → 回到登录页（学号 / 密码输入框在）
    expect(find.text('学号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('刷新一直不返回（60s 超时）→ 同样引导重新登录', (tester) async {
    final core = FakeCore(
      snapshotJson: loadDevJson(),
      latency: Duration.zero,
      refreshHangs: true,
    );
    await boot(tester, core);

    await tapRefresh(tester);
    // 超时前不弹
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('需要重新登录'), findsNothing);

    await tester.pump(AppStore.refreshTimeout + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('需要重新登录'), findsOneWidget);

    // 点「稍后」：留在主界面，标记清掉（不再重复弹）
    await tapAndSettle(tester, find.text('稍后'), last: true);
    expect(find.text('需要重新登录'), findsNothing);
    expect(find.text('今日课程'), findsOneWidget);
  });

  testWidgets('普通同步失败（网络类原因）不弹重新登录，只提示失败', (tester) async {
    final core = FakeCore(
      snapshotJson: loadDevJson(),
      latency: Duration.zero,
      refreshOkCount: 0,
      refreshError: '校园网关验证未通过',
    );
    await boot(tester, core);

    await tapRefresh(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('需要重新登录'), findsNothing);
    expect(find.text('今日课程'), findsOneWidget);
  });
}
