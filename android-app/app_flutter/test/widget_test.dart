import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/core/fake_core.dart';
import 'package:myjlbtc/core/widget_bridge.dart';
import 'package:myjlbtc/main.dart';
import 'package:myjlbtc/models/snapshot.dart';

/// dev 快照直接从磁盘读（不经过 rootBundle）：
/// 测试注入数据后启动路径完全确定，跨测试也稳定。
late final String devJson;

/// 启动应用并推进到首帧（核心数据同步注入，无真实 I/O）。
Future<void> bootApp(
  WidgetTester tester, {
  Duration latency = Duration.zero,
}) async {
  await tester.pumpWidget(
    MyJLBTCApp(core: FakeCore(snapshotJson: devJson, latency: latency)),
  );
  // bootstrap 的两个 microtask（_load → booted），pump 两帧足够
  await tester.pump();
  await tester.pump();
}

/// 点击一次并推进动画（不用 pumpAndSettle：启动/刷新态含无限动画）。
/// 用 `.first`：液态玻璃底栏的标签有选中/未选中两份（交叉淡入）。
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(() {
    devJson = File('assets/test_snapshot.json').readAsStringSync();
  });

  // ---------------- 纯逻辑（对齐 Rust 核心的口径） ----------------

  test('成绩统计：学分合计 / 加权绩点 / 平均分 / 等级制计数', () {
    const records = [
      GradeRecord(
        term: '2025-2026-1',
        code: 'A1',
        name: '课程一',
        grade: '90',
        credit: '2',
        gradePoint: '4.0',
        tag: '',
      ),
      GradeRecord(
        term: '2025-2026-1',
        code: 'A2',
        name: '课程二',
        grade: '良好',
        credit: '1',
        gradePoint: '3.0',
        tag: '补考',
      ),
    ];
    expect(creditSumOf(records), 3.0);
    expect(gpaOf(records), closeTo((4.0 * 2 + 3.0 * 1) / 3, 0.01));
    expect(averageOf(records), 90.0);
    expect(levelCountOf(records), 1);
    expect(records[0].isLevel, isFalse);
    expect(records[1].isLevel, isTrue);
  });

  test('考试倒计时与学期串解析', () {
    final now = DateTime(2026, 10, 8);
    expect(daysUntilOf('2026-10-08 08:30~10:30', now: now), 0);
    expect(daysUntilOf('2026-10-11 08:30~10:30', now: now), 3);
    expect(daysUntilOf('2026-10-01 08:30', now: now), -7);
    expect(daysUntilOf('bad', now: now), null);
    expect(countdownText(0), '今天');
    expect(countdownText(3), '还有 3 天');
    expect(countdownText(-1), '已结束');
    expect(countdownText(null), '');

    expect(termYear('2025-2026-2'), '2025-2026');
    expect(termSemester('2025-2026-2'), '2');
    expect(termLabel('2025-2026', '2'), '2025-2026 学年 · 第 2 学期');
  });

  test('身份证打码', () {
    const p = ProfileView(idCard: '110101200501010000');
    expect(p.maskedIdCard, '110101********0000');
    expect(const ProfileView(idCard: '123').maskedIdCard, '123');
    expect(const ProfileView().maskedIdCard, null);
  });

  test('dev 快照解析：数量与关键字段', () {
    final snap = Snapshot.fromJson(jsonDecode(devJson) as Map<String, dynamic>);
    // 今日课程随生成日期变化（生成器默认系统时钟），只断言形态
    for (final c in snap.todayCourses) {
      expect(c.name, isNotEmpty);
      expect(c.timeText, isNotEmpty);
    }
    expect(snap.weekCourses.length, 10);
    expect(snap.grades.length, 16);
    expect(snap.exams.length, 3);
    expect(snap.notices.length, 3);
    expect(snap.profile?.name, '李明');
    expect(snap.stats.credits, '87.25');
    expect(snap.stats.requiredCredits, '134.00');
    expect(snap.scheduleMeta?.week, 16);
  });

  // ---------------- 界面 ----------------

  testWidgets('启动后进首页：今日课程 / 统计 / 快捷功能都在', (tester) async {
    await bootApp(tester);
    // 今日课程随快照生成日期变化：按 JSON 内容断言，不写死课名
    final snap = Snapshot.fromJson(jsonDecode(devJson) as Map<String, dynamic>);

    expect(find.text('MyJLBTC'), findsOneWidget);
    expect(find.text('今日课程'), findsOneWidget);
    for (final c in snap.todayCourses) {
      expect(find.text(c.name), findsOneWidget, reason: '今日课程应渲染：${c.name}');
    }
    expect(find.text('常用功能'), findsOneWidget);
    expect(find.text('成绩查询'), findsOneWidget);
    expect(find.text('已修学分'), findsOneWidget);
    expect(find.text('87.25'), findsOneWidget);
    expect(find.text('134.00'), findsOneWidget);
  });

  testWidgets('底栏切到课表：周网格渲染课块', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('课表'));

    expect(find.text('第 16 周'), findsOneWidget);
    expect(find.text('切换周次'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget, reason: '节次轴按小節下课时刻');
    expect(find.text('Java程序设计基础'), findsWidgets);
    expect(find.textContaining('调课'), findsOneWidget);
  });

  testWidgets('底栏切到我的：资料与退出登录', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('我的'));

    expect(find.text('李明'), findsOneWidget);
    // 外观挪进了「设置」二级页（Android 独占的莫奈变色 / 实时通知也在那儿）；
    // 设置是入口，右侧不再挂当前外观值
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('跟随系统'), findsNothing);
    expect(find.text('关于 MyJLBTC'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);

    await tapAndSettle(tester, find.text('退出登录'));
    expect(find.textContaining('退出后需要重新登录'), findsOneWidget);
    await tapAndSettle(tester, find.text('取消'));
    expect(find.text('李明'), findsOneWidget);
  });

  testWidgets('首页刷新按钮：加载态 → 完成态', (tester) async {
    await bootApp(tester, latency: const Duration(milliseconds: 500));

    await tester.tap(find.text('刷新'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 等模拟网络耗时（500ms + 300ms）走完
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.text('刷新'), findsOneWidget);
  });

  test('桌面卡片快照：字段口径与原版 FormScheduleData 对齐', () {
    final snap = Snapshot.fromJson(jsonDecode(devJson) as Map<String, dynamic>);
    final payload = WidgetBridge.buildPayload(snap);

    expect(payload['week'], snap.scheduleMeta?.week);
    expect(payload['updatedAt'], snap.scheduleUpdatedAt);
    expect(payload['periodTimes'], bigPeriodTimes, reason: '大节作息要带给卡片');
    final courses = payload['courses'] as List;
    expect(courses.length, snap.weekCourses.length);
    final first = courses.first as Map<String, dynamic>;
    // 卡片按「星期 + 大节 + 周次」自己算今天上什么
    expect(
      first.keys,
      containsAll(['weekday', 'start', 'end', 'name', 'weeks']),
    );
    expect(first['weekday'], snap.weekCourses.first.weekday);
    expect(first['start'], snap.weekCourses.first.startPeriod);
  });

  testWidgets('启动页：就绪前显示品牌 logo 与「正在启动」', (tester) async {
    await tester.pumpWidget(
      MyJLBTCApp(
        core: FakeCore(
          snapshotJson: devJson,
          // 让启动检查真的花点时间，才能看到启动页这一帧
          bootLatency: const Duration(milliseconds: 300),
        ),
      ),
    );
    // 首帧：核心还没就绪 → 启动页（原版 Splash 口径：logo + 应用名 + 底部状态文字）
    await tester.pump();
    expect(find.text('MyJLBTC'), findsOneWidget);
    expect(find.text('正在启动'), findsOneWidget);
    expect(find.text('首页'), findsNothing);

    // 就绪后进主界面，启动页消失
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('正在启动'), findsNothing);
    expect(find.text('首页'), findsWidgets);
  });

  testWidgets('登录页：本机会话还有效 → 不发短信，直接进主界面', (tester) async {
    // 真实场景：上次登录的 TGC 还没过期。带 TGC 再请求 CAS 登录页会 302 进单点登录、
    // 拿不到登录表单，所以必须在发码前先看会话（原版 LoginPage.sendCode 口径）。
    await tester.pumpWidget(
      MyJLBTCApp(
        core: FakeCore(
          snapshotJson: devJson,
          latency: Duration.zero,
          startLoggedOut: true,
          sessionAlive: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('获取验证码'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '202411000000');
    await tester.enterText(find.byType(TextField).at(1), 'Test123456');
    await tester.pump();
    await tester.tap(find.textContaining('我已阅读并同意'));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('验证码'), findsNothing, reason: '会话有效就不该出现验证码行');
    expect(find.text('首页'), findsWidgets, reason: '应直接进主界面');

    // 进主界面会连带同步一次（FakeCore 900ms），等它跑完别留定时器
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('登录页：发码后卡片长出验证码行、主按钮变「登录」', (tester) async {
    // 未登录态：先进登录页
    await tester.pumpWidget(
      MyJLBTCApp(
        core: FakeCore(
          snapshotJson: devJson,
          latency: Duration.zero,
          startLoggedOut: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('MyJLBTC'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.text('验证码'), findsNothing, reason: '发码前没有验证码行');

    await tester.enterText(find.byType(TextField).at(0), '202411000000');
    await tester.enterText(find.byType(TextField).at(1), 'Test123456');
    await tester.pump();

    // 没勾协议 → 不发码（提示 toast 在底部，会压住协议行，等它消失再点）
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('请先阅读并同意'), findsWidgets);
    expect(find.text('验证码'), findsNothing);
    await tester.pump(const Duration(seconds: 3)); // 等 toast 自动消失
    await tester.pump(const Duration(milliseconds: 400));

    // 勾上协议再发码
    await tester.tap(find.textContaining('我已阅读并同意'));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('验证码'), findsOneWidget, reason: '发码后长出验证码行');
    expect(find.text('登录'), findsOneWidget, reason: '主按钮变成登录');
    expect(find.text('60 s 后重发'), findsOneWidget);

    // 填码登录 → 进主界面
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.pump();
    await tester.tap(find.text('登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('首页'), findsWidgets, reason: '登录成功后进主界面');

    // 登录会连带触发一次同步（原版 postLoginSync 口径）；等它跑完，别把定时器留到测试结束
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });
}
