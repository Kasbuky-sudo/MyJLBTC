import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';

/// 一个页签项
class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 悬浮胶囊底栏 —— 液态玻璃版（`liquid_glass_widgets` 的 iOS 26 风格 UITabBar）。
///
/// 渲染路径由包自适应：Android/iOS（Impeller/Vulkan）走 premium 全特效，
/// Windows/Linux/Web（Skia）自动降级到轻量 shader（依旧是真玻璃，不是 BackdropFilter）。
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return GlassTabBar.bottom(
      tabs: [
        for (final item in items)
          GlassTab(
            icon: Icon(item.icon),
            activeIcon: Icon(item.activeIcon),
            label: item.label,
          ),
      ],
      selectedIndex: currentIndex,
      onTabSelected: onChanged,
      selectedIconColor: colors.accent,
      unselectedIconColor: colors.textSecondary,
      selectedLabelColor: colors.accent,
      unselectedLabelColor: colors.textSecondary,
      indicatorColor: colors.accentSoft,
      interactionGlowColor: colors.accent,
      barHeight: 60,
      iconSize: 22,
      labelFontSize: 11,
    );
  }
}
