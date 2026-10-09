import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/pages/about_page.dart';
import 'package:myjlbtc/pages/grade_page.dart';
import 'package:myjlbtc/pages/notice_page.dart';
import 'package:myjlbtc/pages/settings_page.dart';
import 'package:myjlbtc/state/app_store.dart';
import 'package:myjlbtc/theme/app_theme.dart';

import 'test_helpers.dart';

/// F1 二级页：成绩 / 考试 / 通知 / 学籍 / 关于 / 更新日志 / AI 公示。
///
/// 注意两个测试坑（都会导致"点了没反应"）：
/// 1. 页面叠在 Navigator 栈上时，被压在下面的页面仍在 widget 树里 ——
///    同名文本/图标会匹配到多个，必须用作用域（`find.descendant`）或 `.last` 指定最上层路由；
/// 2. 视口外的控件 hits-test 会落空，需要先把视口设成手机尺寸（见 test_helpers）。
void main() {
  testWidgets('成绩页：统计 + 学期筛选', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('成绩查询'));

    // 统计四格（原版口径：课程数 / 学分 / 绩点 / 平均分）
    expect(find.text('课程数'), findsOneWidget);
    expect(find.text('平均分'), findsOneWidget);
    expect(find.text('8 门'), findsOneWidget, reason: '卡内标题行给出门数');
    expect(
      find.text('2025-2026 学年 · 第 1 学期'),
      findsNWidgets(2),
      reason: '导航栏副标题 + 卡内标题行',
    );
    expect(
      find.descendant(
        of: find.byType(GradePage),
        matching: find.text('Java程序设计基础'),
      ),
      findsOneWidget,
    );

    // 胶囊下拉切到第 2 学期
    await tapAndSettle(tester, find.text('第 1 学期'));
    await tapAndSettle(tester, find.text('第 2 学期'));
    expect(
      find.descendant(
        of: find.byType(GradePage),
        matching: find.text('数据库原理与应用'),
      ),
      findsOneWidget,
    );
    expect(find.text('90'), findsOneWidget);
    expect(
      find.text('2025-2026 学年 · 第 2 学期'),
      findsNWidgets(2),
      reason: '导航栏副标题 + 卡内标题行',
    );
  });

  testWidgets('成绩配色：≥85 绿 / ≥75 紫 / ≥60 橙 / 等级制按档', (tester) async {
    await bootApp(tester);
    await tapAndSettle(tester, find.text('成绩查询'));

    // 切到第 2 学期（90 / 88 / 79 / 优秀 / 及格 都在这学期）
    await tapAndSettle(tester, find.text('第 1 学期'));
    await tapAndSettle(tester, find.text('第 2 学期'));

    final colors = AppColor.of(tester.element(find.byType(GradePage)));
    expect(tester.widget<Text>(find.text('90')).style?.color, colors.brandGreen);
    expect(tester.widget<Text>(find.text('88')).style?.color, colors.brandGreen);
    expect(tester.widget<Text>(find.text('79')).style?.color, colors.accent);
    expect(tester.widget<Text>(find.text('优秀')).style?.color, colors.brandGreen);
    expect(tester.widget<Text>(find.text('及格')).style?.color, colors.warning);
  });

  testWidgets('考试页：倒计时与考场信息', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('考试安排'));

    expect(find.text('操作系统原理'), findsOneWidget);
    expect(find.text('考场座位号：'), findsWidgets);
    expect(find.text('12'), findsWidgets);
    expect(find.text('第三教学楼 三教205'), findsWidgets);
    expect(find.text('3 场'), findsOneWidget);
    // dev 快照的考试在 2027-01，相对现在一定是"还有 N 天"
    expect(find.textContaining('还有'), findsWidgets);
  });

  testWidgets('通知：首页公告条进列表，列表行进详情', (tester) async {
    await bootApp(tester);

    // 首页公告条 → **列表**（原版 MainShell 口径：首页只显示最新一条，其余在列表里看）
    await tapAndSettle(tester, find.textContaining('关于 2026-2027 学年第一学期'));
    expect(find.text('通知公告'), findsOneWidget, reason: '先进列表页');
    expect(find.text('通知详情'), findsNothing);

    // 列表行 → 详情（首页那条还压在栈下，所以按页面作用域点，避免点到被遮住的那个）
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(NoticeListPage),
        matching: find.textContaining('关于 2026-2027 学年第一学期'),
      ),
    );
    expect(find.text('通知详情'), findsOneWidget);
    expect(find.textContaining('各二级学院'), findsOneWidget);
    expect(find.textContaining('教务处'), findsWidgets);
    expect(find.text('示例学院'), findsOneWidget);
  });

  testWidgets('个人信息：学籍字段与身份证打码', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('我的'));
    // 资料卡（点整张卡进学籍页）
    await tapAndSettle(tester, find.text('李明'));

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('学业信息'), findsOneWidget);
    expect(find.text('联系方式'), findsOneWidget);
    expect(find.text('家庭与来源'), findsOneWidget);
    expect(find.text('示例学院 · 学籍信息'), findsOneWidget, reason: '导航栏副标题');
    expect(find.text('110101********0000'), findsOneWidget, reason: '身份证应打码');
    expect(find.text('110101200501010000'), findsNothing, reason: '不应出现完整身份证');
    expect(find.text('42 人'), findsOneWidget);
  });

  testWidgets('设置页：外观三选一 + Android 独占开关', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('我的'));
    await tapAndSettle(tester, find.text('设置'));

    // 外观（按页面作用域断言，避免和栈下页面撞词）
    Finder onPage(String text) => find.descendant(
      of: find.byType(SettingsPage),
      matching: find.text(text),
    );
    expect(onPage('外观'), findsOneWidget);
    expect(onPage('跟随系统'), findsOneWidget);
    expect(onPage('浅色'), findsOneWidget);
    expect(onPage('深色'), findsOneWidget);

    // 切深色 → store 跟着变（主题由根节点重建）
    await tapAndSettle(tester, onPage('深色'));
    final store = AppScope.of(tester.element(find.byType(SettingsPage)));
    expect(store.appearanceMode, 2);

    // 桌面（测试环境）不是 Android：两个独占开关不出现
    expect(find.text('Android 独占'), findsNothing);
    expect(find.text('MD3 莫奈变色'), findsNothing);
    expect(find.text('Android 实时通知'), findsNothing);
  });

  testWidgets('关于 → 更新日志 / AI 公示', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('我的'));
    await tapAndSettle(tester, find.text('关于 MyJLBTC'));

    expect(find.text('版本 2.2.2.Android.flutter.261009'), findsOneWidget);
    expect(find.text('应用市场托管'), findsOneWidget);
    expect(find.text('© 2026 MyJLBTC'), findsOneWidget);

    // 更新日志：最新版展开、历史版本在列表
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(AboutPage),
        matching: find.text('更新日志'),
      ),
    );
    // 最新版默认展开，历史版本是收起的标题行
    expect(find.text('v2.2.2'), findsOneWidget);
    // 最新版默认展开：正文里能看到它自己的条目（跟着最新一条换）
    expect(find.textContaining('流体云'), findsOneWidget);
    expect(find.text('v2.1.3'), findsOneWidget);
    expect(find.text('v2.1.2'), findsOneWidget);
    expect(find.text('v2.1.1'), findsOneWidget);
    expect(find.text('v2.1.0'), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('v1.0.8'), findsOneWidget);

    // 返回（.last = 栈顶路由的返回键）；pop 转场走完再点下一页
    await tapAndSettle(
      tester,
      find.byIcon(Icons.arrow_back_ios_new_rounded),
      last: true,
      settleMs: 800,
    );
    await tapAndSettle(tester, find.text('AI 辅助编程公示'));
    // 用公示页独有的文案判断页面确实打开了
    expect(find.text('开发透明度声明'), findsOneWidget, reason: '导航栏副标题');
    expect(
      find.text('本应用在开发过程中使用了下列 AI 模型辅助编程。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('组件写法与调用方式指引'),
      findsOneWidget,
      reason: 'AI 公示页应打开',
    );
    // 五个模型（与原版 AI_MODELS 一一对应）
    expect(find.text('HUAWEI PANGU'), findsOneWidget);
    expect(find.text('DeepSeek V4.1 Flash'), findsOneWidget);
    expect(find.text('GLM-5.3'), findsOneWidget);
    expect(find.text('GLM-5.3 Flash'), findsOneWidget);
    expect(find.text('Kimi K3'), findsOneWidget);
    expect(find.text('模型名称与商标归各自所有者所有'), findsOneWidget);
  });

  testWidgets('关于 → 开源相关：仓库地址与开源软件清单', (tester) async {
    await bootApp(tester);

    await tapAndSettle(tester, find.text('我的'));
    await tapAndSettle(tester, find.text('关于 MyJLBTC'));
    await tapAndSettle(tester, find.text('开源相关'));

    expect(find.text('用了什么 · 在哪儿开源'), findsOneWidget, reason: '导航栏副标题');
    expect(find.text('github.com/Kasbuky-sudo/MyJLBTC'), findsOneWidget);
    // 清单里几个关键项
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('liquid_glass_widgets'), findsOneWidget);
    expect(find.text('rustls'), findsOneWidget);
    expect(
      find.textContaining('不包含与学校系统对接的部分实现细节'),
      findsOneWidget,
      reason: '要说明仓库里哪些内容没公开',
    );
  });
}