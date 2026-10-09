import 'package:flutter/material.dart';

import '../models/legal_docs.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 用户协议：应用内分章节展示（隐私政策走系统浏览器打开托管声明）。
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SubPageScaffold(
      title: '用户协议',
      children: [
        for (final section in userAgreement)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(section.title),
                const SizedBox(height: 10),
                for (final paragraph in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      paragraph,
                      style: TextStyle(fontSize: 14, height: 1.7, color: colors.textMeta),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Text(
            '隐私政策的完整版由应用市场托管，可在「关于 → 隐私政策」中打开查看。',
            style: TextStyle(fontSize: 12, height: 1.5, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
