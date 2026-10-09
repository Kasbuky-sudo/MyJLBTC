import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';

/// 二级页外壳：液态玻璃导航栏 + 可滚动内容区。
///
/// 七个二级页（成绩/考试/通知列表/通知详情/学籍/关于/更新日志）统一用这套壳，
/// 与首页/课表/我的保持同一设计语言。
class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
  });

  final String title;

  /// 标题下的副标题（原版是「成绩查询 / 2024-2025 学年 · 第 1 学期」这种主副标题形式）
  final String? subtitle;

  /// 内容卡片；渲染时自动补 12 间距
  final List<Widget> children;

  /// 导航栏右侧操作
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sub = subtitle ?? '';

    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 12));
      spaced.add(children[i]);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        centerTitle: false,
        toolbarHeight: 56,
        title: sub.isEmpty
            ? Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
        leading: GlassIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
        ),
        actions: actions,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 64, 20, bottomInset + 28),
        // 用 SingleChildScrollView + Column（而不是 ListView）：卡片数量少，
        // 全部构建出来，测试里屏外的文本也能被找到。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaced,
        ),
      ),
    );
  }
}

/// 胶囊下拉筛选（学年 / 学期 / 批次）：点开弹出菜单，当前项带对勾。
///
/// 普通 Material 样式（不用玻璃）——玻璃只保留在弹窗 / 返回 / 分享 / 底栏 / 标题栏。
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.menuLabel,
  });

  /// 胶囊上显示的文字
  final String label;

  /// 菜单项（值与显示文案）
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  /// 菜单项文案转换（默认与值相同）
  final String Function(String value)? menuLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return PopupMenuButton<String>(
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      color: colors.card,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    menuLabel?.call(option) ?? option,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  ),
                ),
                if (option == selected)
                  Icon(Icons.check_rounded, size: 16, color: colors.accent),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 14, right: 12),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 一行筛选 chip（学年 / 学期 / 批次等），横向可滚。
///
/// 普通 Material 样式（不用玻璃）：液态玻璃只保留在弹窗 / 返回 / 分享 / 底栏 / 标题栏，
/// 内容区大量小控件跑 shader 会拖性能。
class GlassChoiceRow extends StatelessWidget {
  const GlassChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: option == selected ? colors.accent : colors.chipBg,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelected(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option == selected ? FontWeight.w600 : FontWeight.w400,
                        color: option == selected ? colors.onAccent : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 小统计块（成绩页顶部四格用）
class MiniStatTile extends StatelessWidget {
  const MiniStatTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
