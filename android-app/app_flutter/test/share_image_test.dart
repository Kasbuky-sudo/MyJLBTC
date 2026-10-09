import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/widgets/share_image.dart';

/// 分享长图的离线验证：`RepaintBoundary` → PNG 落盘（原版 `componentSnapshot` 的对应物）。
/// 真机（Android）上再走一遍系统分享面板；这里只保证截图与写文件这段逻辑是对的。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('分享长图：把内容截成 PNG 落到临时目录', (tester) async {
    final dir = Directory.systemTemp.createTempSync('myjlbtc_share_test');
    // path_provider 在测试里没有平台实现，直接桩掉取临时目录的通道
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 300,
              height: 220,
              color: const Color(0xFF7C3AED),
              alignment: Alignment.center,
              child: const Text('成绩查询', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    String? path;
    await tester.runAsync(() async {
      path = await captureBoundaryPng(key, 'grade_2024-2025_1.png');
    });

    expect(path, isNotNull, reason: '应截出图片并返回路径');
    final file = File(path!);
    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('grade_2024-2025_1.png'));
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(500), reason: 'PNG 不该是空文件');
    // PNG magic：\x89 P N G
    expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
  });

  testWidgets('分享长图：key 未挂到 RepaintBoundary 时返回 null（不抛异常）', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(key: key, width: 10, height: 10),
      ),
    );
    await tester.pump();

    String? path;
    await tester.runAsync(() async {
      path = await captureBoundaryPng(key, 'x.png');
    });
    expect(path, isNull);
  });
}
