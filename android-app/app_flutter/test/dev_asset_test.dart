import 'package:flutter_test/flutter_test.dart';

import 'package:myjlbtc/main.dart';

/// 单独一个文件：验证「真机的 assets 装载路径」（默认 FakeCore 走 rootBundle）。
///
/// 注意：这是本文件里唯一的 widget 测试，保证它是该 isolate 的首个 widget 测试
/// （flutter_test 的 rootBundle 字符串缓存在跨测试后会失效，不适合放在多测试文件里）。
void main() {
  testWidgets('assets/dev_snapshot.json 可加载并渲染首页', (tester) async {
    await tester.pumpWidget(const MyJLBTCApp());
    // bootstrap 是真实异步 I/O：给一点真实时间再推进帧
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('今日课程'), findsOneWidget);
    // 首页标题与统计卡（与生成日期无关的稳定断言）
    expect(find.text('已修学分'), findsOneWidget);
    expect(find.text('常用功能'), findsOneWidget);
  });
}
