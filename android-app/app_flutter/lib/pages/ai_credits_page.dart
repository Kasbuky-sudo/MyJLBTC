import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 一个 AI 模型的公示行：logo（深浅两套资源）+ 名称 + 用途说明。
class _AiModel {
  const _AiModel({
    required this.name,
    required this.usage,
    required this.asset,
    this.darkAsset,
    this.colored = false,
  });

  final String name;
  final String usage;

  /// 浅色主题下的 logo（PNG 或 SVG）
  final String asset;

  /// 深色主题下的 logo；为空表示一张图通用（彩色 logo 不分深浅）
  final String? darkAsset;

  /// 彩色 logo（如盘古）：不做深浅切换
  final bool colored;
}

/// 与原版 `AiCreditsPage.ets` 的 AI_MODELS 一一对应
const List<_AiModel> _models = [
  _AiModel(
    name: 'HUAWEI PANGU',
    usage: '组件写法与调用方式指引',
    asset: 'assets/images/ai/pangu.png',
    colored: true,
  ),
  _AiModel(
    name: 'DeepSeek V4.1 Flash',
    usage: '接口调用与组件开发',
    asset: 'assets/images/ai/deepseek.svg',
    darkAsset: 'assets/images/ai/deepseek_dark.svg',
  ),
  _AiModel(
    name: 'GLM-5.3',
    usage: '部分协议逆向与教务接口排查',
    asset: 'assets/images/ai/glm.svg',
    darkAsset: 'assets/images/ai/glm_dark.svg',
  ),
  _AiModel(
    name: 'GLM-5.3 Flash',
    usage: '接口调用与组件开发',
    asset: 'assets/images/ai/glm.svg',
    darkAsset: 'assets/images/ai/glm_dark.svg',
  ),
  _AiModel(
    name: 'Kimi K3',
    usage: '部分协议逆向与教务接口排查',
    asset: 'assets/images/ai/kimi.svg',
    darkAsset: 'assets/images/ai/kimi_dark.svg',
  ),
];

/// AI 辅助编程公示：开发过程用了哪些 AI 模型、各自做了什么。
class AiCreditsPage extends StatelessWidget {
  const AiCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SubPageScaffold(
      title: 'AI 辅助编程公示',
      subtitle: '开发透明度声明',
      children: [
        // 说明卡
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本应用在开发过程中使用了下列 AI 模型辅助编程。',
                style: TextStyle(
                  fontSize: 14,
                  height: 22 / 14,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '所有代码均经人工审核后提交，学校数据只在你的手机本地处理。',
                style: TextStyle(
                  fontSize: 14,
                  height: 22 / 14,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // 模型列表卡：左 logo 右文字
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              for (var i = 0; i < _models.length; i++) ...[
                _ModelRow(model: _models[i]),
                if (i != _models.length - 1)
                  const IndentedDivider(indent: 58, endIndent: 18),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '模型名称与商标归各自所有者所有',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.placeholder),
          ),
        ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model});

  final _AiModel model;

  Widget _logo(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = (dark && !model.colored && model.darkAsset != null)
        ? model.darkAsset!
        : model.asset;
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(asset, width: 26, height: 26);
    }
    return Image.asset(asset, width: 26, height: 26, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Row(
        children: [
          SizedBox(width: 26, height: 26, child: Center(child: _logo(context))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  model.usage,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
