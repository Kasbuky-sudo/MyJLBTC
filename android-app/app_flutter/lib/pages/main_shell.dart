import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../state/app_store.dart';

import '../widgets/floating_nav_bar.dart';
import 'home_tab.dart';
import 'mine_tab.dart';
import 'schedule_tab.dart';

/// 主界面：三个页签（首页 / 课表 / 我的）+ 悬浮胶囊底栏。
/// 二级页走根 Navigator push（卡片直达等由 F4 接）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// 原生侧反向通知切页签的通道（桌面卡片点进来时用）
  static const MethodChannel tabChannel = MethodChannel(
    'com.anlanas.myjlbtc/native',
  );

  /// 开发/截图辅助：`MYJLBTC_START_TAB=schedule ./myjlbtc.exe` 直接落在某个页签
  /// （Android 上没有这个环境变量，行为不变）
  static int initialTab() {
    const names = ['home', 'schedule', 'mine'];
    try {
      final value = Platform.environment['MYJLBTC_START_TAB']?.trim() ?? '';
      final index = names.indexOf(value);
      return index >= 0 ? index : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = MainShell.initialTab();

  bool _tabResolved = false;

  bool _reloginDialogShown = false;

  AppStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注意不能用 initState：InheritedWidget 依赖在 initState 里取会断言失败
    final store = AppScope.of(context);
    // 1) 桌面卡片点进来：落在课表页签（原版「卡片直达 openTab」口径）
    if (!_tabResolved) {
      _tabResolved = true;
      if (store.pendingTab == 'schedule') {
        store.pendingTab = '';
        _tab = 1;
      }
    }
    // 2) 监听"需要重新登录"标记（刷新超时 / 会话失效）
    if (!identical(store, _store)) {
      _store?.removeListener(_onStoreForRelogin);
      _store = store;
      store.addListener(_onStoreForRelogin);
    }
  }

  @override
  void initState() {
    super.initState();
    // 应用已在运行、再点卡片：Kotlin 反向通知切页签
    MainShell.tabChannel.setMethodCallHandler((call) async {
      if (call.method == 'openTab' && call.arguments == 'schedule') {
        if (mounted) setState(() => _tab = 1);
      }
    });
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreForRelogin);
    MainShell.tabChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// 刷新长时间取不到数据 / 会话失效 → 弹一次"重新登录"确认
  void _onStoreForRelogin() {
    final store = _store;
    if (store == null) return;
    if (!store.needRelogin || _reloginDialogShown || !mounted) return;
    _reloginDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await GlassDialog.show<bool>(
        context: context,
        title: '需要重新登录',
        message: '很长时间没能取到教务数据（或登录已失效）。'
            '重新登录一次通常就能恢复；也可以稍后再试。',
        barrierDismissible: true,
        actions: [
          GlassDialogAction(
            label: '稍后',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
          ),
          GlassDialogAction(
            label: '重新登录',
            isPrimary: true,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          ),
        ],
      );
      store.needRelogin = false;
      if (ok == true) {
        await store.logout();
      } else {
        _reloginDialogShown = false;
      }
      if (mounted) setState(() {});
    });
  }

  static const List<NavItem> _items = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: '课表',
    ),
    NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [HomeTab(), ScheduleTab(), MineTab()],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: FloatingNavBar(
              items: _items,
              currentIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}
