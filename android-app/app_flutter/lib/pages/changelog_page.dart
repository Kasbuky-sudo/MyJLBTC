import 'package:flutter/material.dart';

import '../models/changelog.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_page.dart';

/// 更新日志：版本卡片，最新展开、其余可点开收拢。
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SubPageScaffold(
      title: '更新日志',
      children: [
        for (var i = 0; i < changelog.length; i++)
          // 用 Material 当卡片底：ExpansionTile 内部是 ListTile，
          // 放进带背景色的 DecoratedBox 会触发框架断言（墨水效果会不可见）。
          Material(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppSize.cardRadiusSm),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                iconColor: colors.accent,
                collapsedIconColor: colors.textSecondary,
                title: Row(
                  children: [
                    Text(
                      changelog[i].version,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      changelog[i].date,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
                children: [
                  for (final item in changelog[i].items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: colors.textMeta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
