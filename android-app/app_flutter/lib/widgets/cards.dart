import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 白色圆角卡片（原版各处 `backgroundColor(CARD).borderRadius(CARD_RADIUS_SM)`）
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppSize.cardRadiusSm,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// 卡片小标题（如「常用功能」「今日课程」）
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// 列表行分隔线（左缩进对齐图标，与原版一致）
class IndentedDivider extends StatelessWidget {
  const IndentedDivider({super.key, this.indent = 16, this.endIndent = 16});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: AppColor.of(context).divider,
    );
  }
}

/// 空态文案
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 18)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColor.of(context).textSecondary,
        ),
      ),
    );
  }
}
