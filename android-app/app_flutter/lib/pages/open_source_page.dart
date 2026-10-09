import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 开源相关：本项目的开源地址（鸿蒙版 + Android 版），以及用到的开源软件清单。
class OpenSourcePage extends StatelessWidget {
  const OpenSourcePage({super.key});

  /// 本项目开源仓库（鸿蒙版与 Android 版同一仓库）
  static const String repoUrl = 'https://github.com/Kasbuky-sudo/MyJLBTC';

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SubPageScaffold(
      title: '开源相关',
      subtitle: '用了什么 · 在哪儿开源',
      children: [
        // 本项目
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本项目开源',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '鸿蒙版（ArkTS）与 Android 版（Flutter + Rust）的代码都在同一个仓库开源：',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.textMeta,
                ),
              ),
              const SizedBox(height: 10),
              _RepoLink(url: repoUrl),
              const SizedBox(height: 12),
              Text(
                '出于合规与安全考虑，仓库里不包含与学校系统对接的部分实现细节'
                '（网关适配、接口对接等），也不包含任何真实数据、账号信息与抓包样本；'
                '公开部分可直接阅读，但不保证能原样编译运行。',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // 开源软件清单
        for (final group in _groups)
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    group.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                for (var i = 0; i < group.items.length; i++) ...[
                  _OssRow(item: group.items[i]),
                  if (i != group.items.length - 1) const IndentedDivider(),
                ],
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '以上项目的名称与版权归各自所有者所有；许可证以各项目仓库为准。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.placeholder),
          ),
        ),
      ],
    );
  }
}

/// 一个开源组件
class _OssItem {
  const _OssItem(this.name, this.usage, this.license, this.url);

  final String name;
  final String usage;
  final String license;
  final String url;
}

class _OssGroup {
  const _OssGroup(this.title, this.items);

  final String title;
  final List<_OssItem> items;
}

const List<_OssGroup> _groups = [
  _OssGroup('应用框架', [
    _OssItem('Flutter', '跨平台 UI 框架（Android 版界面）', 'BSD-3-Clause', 'https://flutter.dev'),
    _OssItem('Rust', '核心数据层（登录 / 缓存 / 解析）', 'MIT / Apache-2.0', 'https://www.rust-lang.org'),
    _OssItem('ArkTS / ArkUI', '鸿蒙版界面与业务（HarmonyOS SDK）', '华为开发者协议', 'https://developer.huawei.com'),
  ]),
  _OssGroup('Rust 依赖', [
    _OssItem('reqwest', 'HTTP 客户端', 'MIT / Apache-2.0', 'https://github.com/seanmonstar/reqwest'),
    _OssItem('rustls', 'TLS 实现（纯 Rust，便于交叉编译）', 'Apache-2.0 / ISC / MIT', 'https://github.com/rustls/rustls'),
    _OssItem('tokio', '异步运行时', 'MIT', 'https://github.com/tokio-rs/tokio'),
    _OssItem('serde / serde_json', '序列化与 JSON', 'MIT / Apache-2.0', 'https://github.com/serde-rs/serde'),
    _OssItem('rsa', 'CAS 登录密码加密（RSA PKCS#1 v1.5）', 'MIT / Apache-2.0', 'https://github.com/RustCrypto/RSA'),
    _OssItem('regex', '页面内容提取', 'MIT / Apache-2.0', 'https://github.com/rust-lang/regex'),
    _OssItem('chrono', '日期与时间', 'MIT / Apache-2.0', 'https://github.com/chronotope/chrono'),
    _OssItem('base64 / rand / thiserror / log / async-trait', '编码、随机数、错误与日志等基础库', 'MIT / Apache-2.0', 'https://crates.io'),
  ]),
  _OssGroup('Flutter 插件', [
    _OssItem('liquid_glass_widgets', '液态玻璃外壳（底栏 / 标题栏 / 弹层）', 'MIT', 'https://github.com/David1024Smith/liquid_glass_widgets'),
    _OssItem('dynamic_color', 'Material You 动态取色（莫奈变色）', 'BSD-3-Clause', 'https://github.com/material-foundation/flutter-packages'),
    _OssItem('flutter_svg', 'AI 公示页的模型 logo（SVG）渲染', 'MIT', 'https://github.com/dnfield/flutter_svg'),
    _OssItem('share_plus', '调用系统分享（长图 / 文本）', 'BSD-3-Clause', 'https://github.com/fluttercommunity/plus_plugins'),
    _OssItem('url_launcher', '打开系统浏览器与邮件', 'BSD-3-Clause', 'https://github.com/flutter/packages'),
    _OssItem('path_provider', '读取应用沙箱目录', 'BSD-3-Clause', 'https://github.com/flutter/packages'),
    _OssItem('ffi', 'Dart 侧调用 Rust 动态库（dart:ffi 封装）', 'BSD-3-Clause', 'https://github.com/dart-lang/ffi'),
  ]),
  _OssGroup('图标与字体', [
    _OssItem('Material Symbols / Icons', '界面图标', 'Apache-2.0', 'https://fonts.google.com/icons'),
    _OssItem('系统字体', '中文字体由系统提供（思源黑体 / 苹方等），未随包分发', '系统许可', ''),
  ]),
];

/// 仓库链接行
class _RepoLink extends StatelessWidget {
  const _RepoLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // 没有浏览器也不影响阅读
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.code_rounded, size: 18, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'github.com/Kasbuky-sudo/MyJLBTC',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colors.accent,
                ),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _OssRow extends StatelessWidget {
  const _OssRow({required this.item});

  final _OssItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: item.url.isEmpty
          ? null
          : () async {
              try {
                await launchUrl(
                  Uri.parse(item.url),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // 打开失败不影响阅读
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  item.license,
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
                if (item.url.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 13,
                    color: colors.placeholder,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.usage,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
