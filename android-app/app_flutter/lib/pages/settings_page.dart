import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 设置页（我的 → 设置）。
///
/// - 外观：跟随系统 / 浅色 / 深色（三端通用）
/// - MD3 莫奈变色：跟随壁纸取色（Android 12+）
/// - Android 实时通知：上课提醒走 Android 16 实时通知（课前 15 分钟"上岛"）
///
/// 后两项是 **Android 独占**，其它平台不显示。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _dynamicAvailable;

  @override
  void initState() {
    super.initState();
    _probeDynamicColor();
    // 进页面读一次后台运行状态（省电白名单是否已允许）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadBackgroundStatus();
    });
  }

  Future<void> _probeDynamicColor() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _dynamicAvailable = false);
      return;
    }
    // 插件没有 isDynamicColorAvailable：能拿到系统动态取色就等于支持（Android 12+）
    final palette = await DynamicColorPlugin.getCorePalette();
    if (mounted) setState(() => _dynamicAvailable = palette != null);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final colors = AppColor.of(context);
    final isAndroid = Platform.isAndroid;

    return SubPageScaffold(
      title: '设置',
      subtitle: '外观与提醒',
      children: [
        // 外观
        _GroupHeader('外观'),
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final (index, label) in _appearanceOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Choice(
                        label: label,
                        selected: store.appearanceMode == index,
                        onTap: () => store.setAppearanceMode(index),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '深色模式会同时影响应用与上课提醒通知的配色。',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),

        if (isAndroid) ...[
          _GroupHeader('Android 独占'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _SwitchRow(
                  title: 'MD3 莫奈变色',
                  subtitle: _dynamicAvailable == false
                      ? '当前系统不支持（需 Android 12 及以上）'
                      : '跟随壁纸取色，系统级 Material You 配色',
                  value: store.dynamicColor && _dynamicAvailable != false,
                  enabled: _dynamicAvailable != false,
                  onChanged: (on) => store.setDynamicColor(on),
                ),
                const IndentedDivider(),
                _SwitchRow(
                  title: 'Android 实时通知',
                  subtitle: store.liveUpdatesAvailable
                      ? '上课前 15 分钟提醒，Android 16 实时通知"上岛"'
                      : '上课前 15 分钟在通知栏提醒（Android 16 起可"上岛"）',
                  value: store.classReminder,
                  onChanged: (on) => store.setClassReminder(on),
                ),
                if (store.classReminder && !store.notificationsAllowed) ...[
                  const IndentedDivider(),
                  _Notice(
                    text: '还没拿到通知权限：请在弹出的系统对话框里允许通知，'
                        '或到「系统设置 → 应用 → MyJLBTC → 通知」里打开。',
                    onTap: () => store.setClassReminder(true),
                  ),
                ],
                // 顺序：MD3 → 实时通知（含权限提示）→ 灵动岛测试（按钮 + 适配说明）
                // → 后台运行引导 → 桌面小部件
                const IndentedDivider(),
                _IslandTestRow(store: store),
                const IndentedDivider(),
                _IslandNote(store: store),
                const IndentedDivider(),
                _BackgroundRow(store: store),
                const IndentedDivider(),
                _WidgetPinRow(store: store),
              ],
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            isAndroid
                ? '说明：实时通知只读取本机的课表缓存，不联网；'
                      '提醒由系统闹钟驱动，未授权精确闹钟时可能有一两分钟偏差。'
                : '说明：莫奈变色与实时通知是 Android 独占特性（Android 12 / 16 起系统支持）。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

const List<(int, String)> _appearanceOptions = [
  (0, '跟随系统'),
  (1, '浅色'),
  (2, '深色'),
];

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 2),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColor.of(context).textSecondary,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Material(
      color: selected ? colors.accent : colors.chipBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.onAccent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final titleColor = enabled ? colors.textPrimary : colors.placeholder;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: colors.accent,
          ),
        ],
      ),
    );
  }
}

/// 后台运行引导：自启动 + 省电策略无限制（不设的话上课提醒/小组件可能被系统延迟或清掉）
class _BackgroundRow extends StatelessWidget {
  const _BackgroundRow({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final allowed = store.ignoringBatteryOptimizations;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '后台运行设置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                allowed
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: allowed ? colors.brandGreen : colors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                allowed ? '已允许后台运行' : '未设置',
                style: TextStyle(
                  fontSize: 12,
                  color: allowed ? colors.brandGreen : colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '把「自启动」打开、「省电策略」设为"无限制"，上课提醒与桌面小组件才能在后台按时刷新；'
            '否则系统省电会延迟或清掉后台唤醒。',
            style: TextStyle(fontSize: 12, height: 1.45, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await store.openBackgroundSettings();
                if (!context.mounted) return;
                AppToast.show(
                  context,
                  ok
                      ? '在系统设置里把「自启动」打开、省电策略设为「无限制」，回来点这里可复查'
                      : '没找到对应设置页：请到「设置 → 应用管理 → MyJLBTC」里开启自启动与后台无限制',
                  long: true,
                );
                await store.loadBackgroundStatus();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('去设置', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 桌面小部件：一键把三种尺寸钉到桌面（`requestPinAppWidget`，Android 8+）
class _WidgetPinRow extends StatelessWidget {
  const _WidgetPinRow({required this.store});

  final AppStore store;

  Future<void> _pin(BuildContext context, String mode, String label) async {
    final (ok, supported) = await store.pinWidget(mode);
    if (!context.mounted) return;
    if (ok) {
      AppToast.show(context, '已请求添加「$label」到桌面，按系统提示确认');
    } else if (!supported) {
      AppToast.show(
        context,
        '这个桌面不支持应用内添加，请长按桌面 → 小组件 → 安卓小部件里找 MyJLBTC',
        long: true,
      );
    } else {
      AppToast.show(context, '添加未完成：可到桌面长按 → 小组件里手动添加', long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '桌面小部件',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '四种卡片：今日课程 2×2 / 4×2 / 4×4，以及 4×4 周视图（整周网格）。',
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (mode, label) in const [
                ('small', '添加 2×2'),
                ('full', '添加 4×2'),
                ('list', '添加 4×4'),
                ('week', '添加周视图'),
              ])
                Padding(
                  padding: EdgeInsets.zero,
                  child: OutlinedButton(
                    onPressed: () => _pin(context, mode, label.replaceFirst('添加 ', '')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(label),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '走的是系统「请求钉住小组件」接口：原生 / OPPO / 华为等会弹确认框；'
            '小米 / HyperOS 实测不弹框（该接口在它上面不生效），请到桌面长按 → 小组件 → '
            '「安卓小部件」里找 MyJLBTC 手动添加；部分 vivo 机型同样不支持。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 灵动岛自测：一键发一条「示例课程」实时通知，自己看状态栏 / 锁屏 / 灵动岛有没有反应
class _IslandTestRow extends StatelessWidget {
  const _IslandTestRow({required this.store});

  final AppStore store;

  /// 测试通知：静态探针（挂着直到再点一次收回）—— 用来看"岛上有没有它"
  Future<void> _probe(BuildContext context) async {
    final wasTesting = store.islandTesting;
    final (ok, promotable) = await store.islandTest(!wasTesting);
    if (!context.mounted) return;
    if (!ok) {
      AppToast.show(context, '没发出去：请先允许通知权限');
      return;
    }
    if (wasTesting) {
      AppToast.show(context, '测试通知已收回');
    } else if (promotable) {
      AppToast.show(context, '已发送：这条具备实时通知资格，看状态栏芯片 / 锁屏');
    } else {
      AppToast.show(
        context,
        '已发送，但系统判定它不具备实时通知资格（会按普通通知显示，上不了岛）',
        long: true,
      );
    }
  }

  /// 模拟上课：走真实提醒的完整链路（进度每分钟走一格、到点自动收掉），
  /// 用来验证「进度条会不会动」「下课后会不会消失」。
  Future<void> _simulate(BuildContext context) async {
    final (ok, promotable) = await store.simulateClass(minutes: 10);
    if (!context.mounted) return;
    if (!ok) {
      AppToast.show(context, '没发出去：请先允许通知权限');
      return;
    }
    AppToast.show(
      context,
      promotable
          ? '已开始模拟上课（10 分钟）：进度条每分钟走一格，到点自动消失'
          : '已开始模拟上课（10 分钟），但这条按普通常驻通知显示（不具备实时通知资格）',
      long: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final testing = store.islandTesting;
    final running = store.simulatedRunning;

    Widget button({
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      final tint = active ? colors.danger : colors.accent;
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: tint,
            side: BorderSide(color: tint.withValues(alpha: 0.5)),
            shape: const StadiumBorder(),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 14)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实时通知自测',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '发一条和真实上课提醒同一条通道的实时通知，确认你的机型能不能"上岛"。',
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          button(
            active: testing,
            icon: testing
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded,
            label: testing ? '结束测试' : '灵动岛测试',
            onPressed: () => _probe(context),
          ),
          const SizedBox(height: 8),
          button(
            active: running,
            icon: running ? Icons.stop_circle_outlined : Icons.hourglass_top_rounded,
            label: running ? '结束模拟' : '模拟上课 10 分钟',
            onPressed: running
                ? () async {
                    await store.cancelSimulatedClass();
                    if (!context.mounted) return;
                    AppToast.show(context, '模拟已结束');
                  }
                : () => _simulate(context),
          ),
          const SizedBox(height: 6),
          Text(
            testing
                ? '测试通知已发出：看看状态栏芯片 / 锁屏 / 机型的"岛"上有没有它；再点一下收回。'
                : running
                ? '模拟中：进度条应当每分钟往前走一格，10 分钟后这条通知应当自己消失。'
                : '「模拟上课」会往提醒状态机里塞一节课（1 分钟前开始、10 分钟后下课）：'
                      '进度条每分钟走一格、到点自动收掉 —— 进度不动 / 下课不消失这两个毛病当场就能验出来。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 灵动岛适配说明：本机结论 + 已适配机型清单
class _IslandNote extends StatelessWidget {
  const _IslandNote({required this.store});

  final AppStore store;

  /// 各品牌已接入灵动岛的系统版本（用户 2026-10-08 提供，三星 One UI 8 后续补上）
  static const String _adaptList =
      '已接入灵动岛：OPPO / 一加 / realme（ColorOS 17）、小米 / 红米（HyperOS 3 起）、'
      '荣耀（MagicOS 10）、三星（One UI 8）。';

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final status = store.islandStatus;
    final brand = status['brand'] ?? '';
    final rom = status['rom'] ?? '';
    final version = status['version'] ?? '';
    final required = status['required'] ?? '';
    final verdict = status['verdict'] ?? 'untested';

    final (icon, color, line) = switch (verdict) {
      'supported' => (
        Icons.check_circle_rounded,
        colors.brandGreen,
        '本机 $brand${rom.isEmpty ? '' : ' · $rom${version.isEmpty ? '' : ' $version'}'}'
            '：已接入灵动岛',
      ),
      'low' => (
        Icons.system_update_alt_rounded,
        colors.warning,
        '本机 $brand（$rom${version.isEmpty ? '' : ' $version'}）：'
            '升级到 $required 后可上岛',
      ),
      _ => (
        Icons.help_outline_rounded,
        colors.textSecondary,
        '本机 $brand${rom.isEmpty ? '' : '（$rom）'}：暂未确认是否上岛'
            '${required.isEmpty ? '' : '（需 $required）'}',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _adaptList,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
