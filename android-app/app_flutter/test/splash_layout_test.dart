import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/core/fake_core.dart';
import 'package:myjlbtc/main.dart';

/// 启动页 / 登录页的**水平居中**要用数据说话：
/// 之前真机上看到"整体偏左"，先在多种宽度下量一遍内容中心，确认是不是布局的问题。
void main() {
  late final String json;
  setUpAll(() {
    json = File('assets/test_snapshot.json').readAsStringSync();
  });

  for (final width in <double>[320, 360, 393, 430, 480, 800]) {
    testWidgets('启动页在 ${width.toInt()}dp 宽下水平居中', (tester) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MyJLBTCApp(
          core: FakeCore(
            snapshotJson: json,
            bootLatency: const Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.pump(); // 首帧：启动页

      final center = width / 2;
      final title = tester.getCenter(find.text('MyJLBTC'));
      final logo = tester.getCenter(find.byType(OverflowBox));
      final status = tester.getCenter(find.text('正在启动'));

      expect(
        (title.dx - center).abs(),
        lessThan(0.5),
        reason: '标题中心 ${title.dx} 应等于 $center',
      );
      expect(
        (logo.dx - center).abs(),
        lessThan(0.5),
        reason: 'logo 中心 ${logo.dx} 应等于 $center',
      );
      expect(
        (status.dx - center).abs(),
        lessThan(0.5),
        reason: '状态文字中心 ${status.dx} 应等于 $center',
      );

      // 收尾：让 bootstrap 走完，别留定时器
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    });
  }

  testWidgets('登录页在 320dp 窄屏下也不越界/不偏移', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MyJLBTCApp(
        core: FakeCore(
          snapshotJson: json,
          startLoggedOut: true,
          latency: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 主按钮 / 协议行都应铺满可用宽度并居中
    final button = find.widgetWithText(FilledButton, '获取验证码');
    final rect = tester.getRect(button);
    expect(rect.left, greaterThanOrEqualTo(0), reason: '按钮不该越出左边界');
    expect(rect.right, lessThanOrEqualTo(320), reason: '按钮不该越出右边界');
    final center = tester.getCenter(button);
    expect((center.dx - 160).abs(), lessThan(0.5), reason: '按钮应水平居中');
  });
}
