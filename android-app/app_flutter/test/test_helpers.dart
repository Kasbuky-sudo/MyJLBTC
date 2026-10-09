import 'dart:io';

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/core/fake_core.dart';
import 'package:myjlbtc/main.dart';

/// 开发快照：直接从磁盘读（不走 rootBundle —— 跨测试的字符串缓存会失效）。
/// 测试用快照：演示数据生成（固定时钟 2026-12-14 周一）——
/// 设备预览用的是真实数据的 dev_snapshot.json，两者分开避免互相影响。
String loadDevJson() => File('assets/test_snapshot.json').readAsStringSync();

/// 启动应用并推进到首帧（核心数据同步注入，无真实 I/O）。
///
/// 视口设成手机比例 430×900：默认的 800×600 太矮，首页"常用功能"会落在屏幕外
/// （点击会 hit-test 失败，长页面的懒加载列表也找不到屏外文本）。
Future<void> bootApp(
  WidgetTester tester, {
  String? json,
  Duration latency = Duration.zero,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyJLBTCApp(
      core: FakeCore(snapshotJson: json ?? loadDevJson(), latency: latency),
    ),
  );
  // bootstrap 的两个 microtask（_load → booted），pump 两帧足够
  await tester.pump();
  await tester.pump();
}

/// 点击一次并推进动画。
/// - 不用 pumpAndSettle：启动/刷新态含无限动画；
/// - 默认取 `.first`（液态玻璃底栏的标签有选中/未选中两份）；
///   页面栈叠加时用 `last: true` 指定最上层路由里的目标。
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, {
  bool last = false,
  int settleMs = 400,
}) async {
  final target = last ? finder.last : finder.first;
  try {
    await tester.ensureVisible(target); // 屏外的先滚进来（不在滚动容器里则忽略）
  } catch (_) {
    // 目标不在可滚动容器内（例如底栏）—— 无需滚动
  }
  await tester.tap(target);
  await tester.pump();
  await tester.pump(Duration(milliseconds: settleMs));
}
