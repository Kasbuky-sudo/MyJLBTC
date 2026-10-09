import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/core/fake_core.dart';
import 'package:myjlbtc/main.dart';

Future<void> bootApp(WidgetTester tester, String devJson) async {
  await tester.pumpWidget(
    MyJLBTCApp(core: FakeCore(snapshotJson: devJson, latency: Duration.zero)),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late final String devJson;
  setUpAll(() {
    devJson = File('assets/test_snapshot.json').readAsStringSync();
  });

  testWidgets('课块点开液态玻璃详情弹层', (tester) async {
    await bootApp(tester, devJson);
    await tapAndSettle(tester, find.text('课表'));

    await tapAndSettle(tester, find.text('Java程序设计基础'));
    expect(find.text('教师'), findsOneWidget, reason: '详情弹层应打开');
    expect(find.text('周次'), findsOneWidget);
  });

  testWidgets('周次选择弹层：玻璃 chip 可选周', (tester) async {
    await bootApp(tester, devJson);
    await tapAndSettle(tester, find.text('课表'));
    expect(find.text('第 16 周'), findsOneWidget);

    await tapAndSettle(tester, find.text('切换周次'));
    expect(find.text('选择教学周'), findsOneWidget);
    expect(find.text('第 22 周'), findsOneWidget);

    await tapAndSettle(tester, find.text('第 3 周'));
    expect(find.text('选择教学周'), findsNothing, reason: '选择后弹层应关闭');
    expect(find.text('第 3 周'), findsOneWidget, reason: '周次行应切到第 3 周');
    expect(find.text('回到本周'), findsOneWidget, reason: '非本周显示回到本周');
  });
}
