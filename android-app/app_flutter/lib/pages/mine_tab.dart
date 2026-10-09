import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/page_scaffold.dart';

/// 「我的」页：资料卡（→ 个人信息）+「外观 / 关于」卡 + 「退出登录」卡。
///
/// 版式对齐原版：资料卡带箭头；外观与关于在同一张卡内；
/// 退出登录是独立一张卡、红字居中、不带图标。
class MineTab extends StatelessWidget {
  const MineTab({super.key});

  static const List<String> appearanceLabels = ['跟随系统', '浅色', '深色'];

  Future<void> _confirmLogout(BuildContext context, AppStore store) async {
    final ok = await GlassDialog.show<bool>(
      context: context,
      title: '退出登录',
      message: '退出后需要重新登录才能同步数据；本机缓存会保留，仍可离线查看。',
      barrierDismissible: true,
      actions: [
        GlassDialogAction(
          label: '取消',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        ),
        GlassDialogAction(
          label: '退出',
          isPrimary: true,
          isDestructive: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (ok == true) {
      await store.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final colors = AppColor.of(context);
    final profile = store.snapshot.profile;
    final name = profile?.name ?? '';
    final subtitle = [
      profile?.major ?? '',
      profile?.className ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return PageScaffold(
      title: '我的',
      slivers: [
        // 资料卡（带箭头 → 个人信息二级页）
        SectionCard(
          padding: const EdgeInsets.all(18),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pushNamed('/profile');
          },
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.profileFrom, colors.profileTo],
                  ),
                ),
                child: Text(
                  name.isEmpty ? '学' : name.substring(0, 1),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '待同步' : name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? '登录后刷新即可同步学籍' : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 外观 + 关于：同一张卡
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 设置是个入口（里面还有莫奈变色 / 实时通知），右侧不显示任何当前值
              _MineRow(
                label: '设置',
                onTap: () => Navigator.of(context).pushNamed('/settings'),
              ),
              const IndentedDivider(),
              _MineRow(
                label: '关于 MyJLBTC',
                onTap: () => Navigator.of(context).pushNamed('/about'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 退出登录：独立一张卡，红字居中
        SectionCard(
          padding: EdgeInsets.zero,
          onTap: () => _confirmLogout(context, store),
          child: SizedBox(
            height: AppSize.buttonHeight,
            child: Center(
              child: Text(
                '退出登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.danger,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 设置行：文字 + 右箭头
class _MineRow extends StatelessWidget {
  const _MineRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: colors.textPrimary),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
