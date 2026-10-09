import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/core_client.dart';
import 'core/fake_core.dart';
import 'core/real_core.dart';
import 'pages/about_page.dart';
import 'pages/ai_credits_page.dart';
import 'pages/changelog_page.dart';
import 'pages/exam_page.dart';
import 'pages/grade_page.dart';
import 'pages/legal_page.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'pages/notice_page.dart';
import 'pages/open_source_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预加载液态玻璃 shader（避免首帧白闪；Windows/Skia 走轻量 shader 路径）
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  runApp(const MyJLBTCApp());
}

/// MyJLBTC（Flutter 版）
///
/// F0 阶段用 [FakeCore] + `assets/dev_snapshot.json` 跑通全部界面；
/// F2 换 RealCore（dart:ffi → Rust cdylib）后即接真实数据，界面代码不变。
/// 测试可注入 `core`（如 `FakeCore(snapshotJson: …)`）。
class MyJLBTCApp extends StatefulWidget {
  const MyJLBTCApp({super.key, this.core});

  /// 核心实现（默认 FakeCore；测试与后续里程碑从这里替换）
  final CoreClient? core;

  @override
  State<MyJLBTCApp> createState() => _MyJLBTCAppState();
}

class _MyJLBTCAppState extends State<MyJLBTCApp> {
  late final AppStore _store = AppStore(widget.core ?? _defaultCore());

  /// Android 真机走 Rust 核心（dart:ffi）；桌面开发仍用假数据快照。
  ///
  /// 两个开发开关（正式包都不带）：
  /// - `--dart-define=MYJLBTC_DEV_DATA=true`：真机也读开发快照（截图/走查用，不联网）；
  /// - `MYJLBTC_LOGGED_OUT=1`（桌面环境变量）：停在登录页，方便截图核对。
  static const bool _devData = bool.fromEnvironment('MYJLBTC_DEV_DATA');

  static CoreClient _defaultCore() {
    final loggedOut = _env('MYJLBTC_LOGGED_OUT') == '1';
    if (_devData) return FakeCore(startLoggedOut: loggedOut);
    if (Platform.isAndroid) return RealCore();
    return FakeCore(startLoggedOut: loggedOut);
  }

  /// 开发/截图辅助：启动后直接打开某个二级页
  /// （`MYJLBTC_START_ROUTE=grade ./myjlbtc.exe`；Android 上没有这个环境变量，行为不变）
  ///
  /// 注意：值写成不带斜杠的路由名（`grade` 而不是 `/grade`）——
  /// Git Bash / MSYS 会把以 `/` 开头的值当成 Unix 路径改写成 `C:/Program Files/...`。
  static final String _startRoute = _normalizeRoute(
    _env('MYJLBTC_START_ROUTE'),
  );

  static String _normalizeRoute(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    return value.startsWith('/') ? value : '/$value';
  }

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  bool _startRoutePushed = false;

  static String _env(String key) {
    try {
      return Platform.environment[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 主题相关设置的快照（外观 + 莫奈变色）：变了才重建整树，
  /// 否则刷新数据时也会跟着重建（费性能）
  int _themeSeen = -1;


  @override
  void initState() {
    super.initState();
    _store.addListener(_pushStartRouteOnce);
    _store.addListener(_onStoreChanged);
    _store.bootstrap().then((_) {
    });
  }


  /// 外观 / 莫奈变色变化时才重建（不做全量监听，避免刷新时整树重建）
  void _onStoreChanged() {
    final next = _store.appearanceMode * 2 + (_store.dynamicColor ? 1 : 0);
    if (!mounted || next == _themeSeen) return;
    _themeSeen = next;
    setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_pushStartRouteOnce);
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _pushStartRouteOnce() {
    if (_startRoutePushed || _startRoute.isEmpty) return;
    if (!_store.booted || !_store.loggedIn) return;
    _startRoutePushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKey.currentState?.pushNamed(_startRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      // 莫奈变色：系统给一套动态配色（Android 12+），没开或系统不支持时传 null 走静态配色
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final useDynamic = _store.dynamicColor;
          return MaterialApp(
            title: 'MyJLBTC',
            navigatorKey: _navKey,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              Brightness.light,
              dynamicScheme: useDynamic ? lightDynamic : null,
            ),
            darkTheme: buildAppTheme(
              Brightness.dark,
              dynamicScheme: useDynamic ? darkDynamic : null,
            ),
            themeMode: switch (_store.appearanceMode) {
              1 => ThemeMode.light,
              2 => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            home: const _Root(),
            routes: {
              '/grade': (_) => const GradePage(),
              '/exam': (_) => const ExamPage(),
              '/notices': (_) => const NoticeListPage(),
              '/notice': (context) {
                final id = ModalRoute.of(context)?.settings.arguments;
                return NoticePage(id: id is String ? id : '');
              },
              '/profile': (_) => const ProfilePage(),
              '/settings': (_) => const SettingsPage(),
              '/about': (_) => const AboutPage(),
              '/legal': (_) => const LegalPage(),
              '/changelog': (_) => const ChangelogPage(),
              '/ai-credits': (_) => const AiCreditsPage(),
              '/open-source': (_) => const OpenSourcePage(),
            },
          );
        },
      ),
    );
  }
}

/// 根节点：启动页（booted 前）→ 登录页 / 主界面
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!store.booted) return const _Splash();
    return store.loggedIn ? const MainShell() : const LoginPage();
  }
}

/// 启动页：纯本地检查（不联网），版式对齐原版 `Splash.ets` ——
/// 中上部品牌紫圆角 logo + 应用名，底部状态文字。
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Scaffold(
      backgroundColor: colors.pageBg,
      // 注意：Column 的横向尺寸会收缩到"最宽的子控件"，Scaffold 又把它靠左摆 ——
      // 少了这层「占满宽度」，内容就只在一条窄条里居中，看起来整体偏左（真机偏了 325px，踩过）。
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const Spacer(flex: 5),
            Container(
              width: 160,
              height: 160,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.profileFrom, colors.profileTo],
                ),
              ),
              // 前景层按 220 画（和原版同比例）溢出裁切，让字形贴满色块；
              // 白色字形在深色模式（渐变变浅）里要染色，否则看不见
              child: OverflowBox(
                maxWidth: 220,
                maxHeight: 220,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    colors.onAccent,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/app_foreground.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MyJLBTC',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(flex: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Text(
                '正在启动',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
