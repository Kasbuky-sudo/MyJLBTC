import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/legal_docs.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 应用版本（与 pubspec version 保持一致）
const String appVersion = '2.2.0';

/// 关于页展示的版本文案：版本号 + 平台 + 构建日期（261008 = 2026-10-08），
/// 对齐原版 `1.0.8.HarmonyOS.arkts.261007` 的口径。
const String appDisplayVersion = '2.2.0.Android.flutter.261009';

/// 关于：大 logo + 名称版本 + 信息行（版本号 / 开发者 / 检查更新 / 更新日志 /
/// AI 辅助编程公示 / 用户协议 / 隐私政策）+ 版权。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SubPageScaffold(
      title: '关于',
      children: [
        // 大 logo（居中）：品牌紫渐变 + 应用图标前景层
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.profileFrom, colors.profileTo],
                  ),
                ),
                // 前景层按 130 画后溢出裁切（原版同比例），字形贴满色块；
                // 原资源是白色字形，深色模式（渐变变浅）要染成 onAccent 才看得清
                child: OverflowBox(
                  maxWidth: 130,
                  maxHeight: 130,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      colors.onAccent,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/images/app_foreground.png',
                      width: 130,
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'MyJLBTC',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '版本 $appDisplayVersion',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),

        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const _AboutRow(label: '版本号', value: appDisplayVersion),
              const IndentedDivider(),
              const _AboutRow(label: '开发者', value: 'anlanas'),
              const IndentedDivider(),
              _AboutRow(
                label: '检查更新',
                onTap: () => AppToast.show(context, '已是最新版本'),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: '更新日志',
                onTap: () => Navigator.of(context).pushNamed('/changelog'),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: 'AI 辅助编程公示',
                onTap: () => Navigator.of(context).pushNamed('/ai-credits'),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: '开源相关',
                value: 'GitHub',
                onTap: () => Navigator.of(context).pushNamed('/open-source'),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: '用户协议',
                onTap: () => Navigator.of(context).pushNamed('/legal'),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: '隐私政策',
                value: '应用市场托管',
                onTap: () => _openPrivacy(context),
              ),
              const IndentedDivider(),
              _AboutRow(
                label: '其他系统设备',
                onTap: () => _openOtherPlatforms(context),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            '© 2026 MyJLBTC',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.placeholder),
          ),
        ),
      ],
    );
  }
}

/// 隐私政策：确认后用系统浏览器打开应用市场托管的声明（原版口径）
Future<void> _openPrivacy(BuildContext context) async {
  final colors = AppColor.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('隐私政策', style: TextStyle(color: colors.textPrimary)),
      content: Text(
        '将用系统浏览器打开由应用市场托管的隐私声明页面。',
        style: TextStyle(color: colors.textMeta, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('取消', style: TextStyle(color: colors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.accent),
          child: const Text('打开浏览器'),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await launchUrl(
        Uri.parse(privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // 打开失败不影响应用
    }
  }
}

/// 其他系统设备：华为 / iOS 用户的说明（含开发者邮箱，点一下可直接发邮件）
Future<void> _openOtherPlatforms(BuildContext context) async {
  final colors = AppColor.of(context);
  const mail = 'Kasbukyaichat@163.com';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('其他系统设备', style: TextStyle(color: colors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '华为用户请使用原生鸿蒙版 MyJLBTC APP（尚未上架，如需试用请向开发者发送您的华为账号，'
            '邮箱 $mail）。',
            style: TextStyle(
              color: colors.textMeta,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'iOS 适配中。',
            style: TextStyle(
              color: colors.textMeta,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('关闭', style: TextStyle(color: colors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.accent),
          child: const Text('发邮件'),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await launchUrl(Uri.parse('mailto:$mail'), mode: LaunchMode.externalApplication);
    } catch (_) {
      // 没有邮件客户端也不影响阅读
    }
  }
}

/// 信息行：文字（15）+ 右侧值（14，灰）+ 箭头；点一下才响应
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, this.value = '', this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final arrow = onTap != null;
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
