import 'package:flutter/material.dart';

/// 设计令牌：与原 ArkTS `common/Theme.ets` + `resources/*/element/color.json` 一比一对应。
/// 页面里不出现魔法值，颜色 / 尺寸统一从这里取。
class AppColor {
  const AppColor({
    required this.pageBg,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMeta,
    required this.placeholder,
    required this.accent,
    required this.accentSoft,
    required this.huaweiRed,
    required this.brandGreen,
    required this.profileFrom,
    required this.profileTo,
    required this.divider,
    required this.chipBg,
    required this.track,
    required this.barBg,
    required this.barShadow,
    required this.titleBarBg,
    required this.onBrand,
    required this.onAccent,
    required this.danger,
    required this.warning,
  });

  final Color pageBg;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMeta;
  final Color placeholder;
  final Color accent;
  final Color accentSoft;
  final Color huaweiRed;
  final Color brandGreen;
  final Color profileFrom;
  final Color profileTo;
  final Color divider;
  final Color chipBg;
  final Color track;
  final Color barBg;
  final Color barShadow;
  final Color titleBarBg;
  final Color onBrand;

  /// 铺在强调色（accent）/ 品牌渐变上的前景色：
  /// 浅色模式白字，深色模式（尤其莫奈取色后 accent 是浅色）要用深色字，否则看不清。
  final Color onAccent;
  final Color danger;
  final Color warning;

  /// 浅色（resources/base/element/color.json）
  static const AppColor light = AppColor(
    pageBg: Color(0xFFF1F3F5),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF141518),
    textSecondary: Color(0xFF8A9099),
    textMeta: Color(0xFF5B6067),
    placeholder: Color(0xFFB9BEC5),
    accent: Color(0xFF7C3AED),
    accentSoft: Color(0xFFF0E8FD),
    huaweiRed: Color(0xFFCF0A2C),
    brandGreen: Color(0xFF22B14C),
    profileFrom: Color(0xFF9B4AD8),
    profileTo: Color(0xFF6B2B9E),
    divider: Color(0x14000000),
    chipBg: Color(0xFFEDF1F6),
    track: Color(0xFFF0F1F3),
    barBg: Color(0xB3FFFFFF),
    barShadow: Color(0x14000000),
    titleBarBg: Color(0xF2F1F3F5),
    onBrand: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFFF3B30),
    warning: Color(0xFFFF9F0A),
  );

  /// 深色（resources/dark/element/color.json）
  static const AppColor dark = AppColor(
    pageBg: Color(0xFF000000),
    card: Color(0xFF1A1A1C),
    textPrimary: Color(0xFFF5F6F7),
    textSecondary: Color(0xFF9096A0),
    textMeta: Color(0xFFA8ADB4),
    placeholder: Color(0xFF5F646B),
    accent: Color(0xFFA78BFA),
    accentSoft: Color(0xFF2A2140),
    huaweiRed: Color(0xFFE03A55),
    brandGreen: Color(0xFF2FC463),
    profileFrom: Color(0xFF7E3AB8),
    profileTo: Color(0xFF521F7E),
    divider: Color(0x1FFFFFFF),
    chipBg: Color(0xFF26272B),
    track: Color(0xFF2A2B2F),
    barBg: Color(0xB31C1C1E),
    barShadow: Color(0x66000000),
    titleBarBg: Color(0xF2000000),
    onBrand: Color(0xFFFFFFFF),
    // 深色下 accent 是浅紫（#A78BFA），前景要用深色
    onAccent: Color(0xFF241640),
    danger: Color(0xFFFF453A),
    warning: Color(0xFFFFB340),
  );

  static AppColor of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorExt>();
    if (ext != null) return ext.color;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static AppColor byBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;

  /// 任意底色上该用白字还是深色字（课块这类"颜色随课程/主题变"的地方用）。
  ///
  /// 阈值取相对亮度 0.5：浅色模式那套紫/绿/橙/深紫（亮度都 ≤0.47）仍然是白字，
  /// 观感与原来一致；深色模式（尤其莫奈取色后 accent/tertiary 是浅色）自动切成深色字。
  static Color contentOn(Color background) =>
      background.computeLuminance() < 0.5
      ? Colors.white
      : const Color(0xFF1B1B1F);

  /// MD3 动态取色（莫奈变色）：把动态 ColorScheme 的语义槽位映射到本应用的设计令牌。
  ///
  /// 语义色（成绩分档的绿/橙/红、危险色）刻意**不跟随**动态取色 —— 它们表达的是含义而不是品牌色；
  /// 品牌渐变色改成 primary → tertiary 的取色。
  factory AppColor.fromDynamic(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // 浅色：浅底 + 白卡；深色：近黑底 + 略亮的卡（保持原有层级观感）
    final page = isDark ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow;
    final card = isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest;
    return AppColor(
      pageBg: page,
      card: card,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textMeta: scheme.onSurfaceVariant,
      placeholder: scheme.onSurfaceVariant.withValues(alpha: 0.62),
      accent: scheme.primary,
      accentSoft: scheme.primaryContainer,
      huaweiRed: light.huaweiRed,
      brandGreen: isDark ? dark.brandGreen : light.brandGreen,
      profileFrom: scheme.primary,
      profileTo: scheme.tertiary,
      divider: scheme.outlineVariant.withValues(alpha: 0.6),
      chipBg: scheme.surfaceContainerHigh,
      track: scheme.surfaceContainerHighest,
      barBg: scheme.surface.withValues(alpha: 0.72),
      barShadow: isDark ? const Color(0x66000000) : const Color(0x14000000),
      titleBarBg: scheme.surface.withValues(alpha: 0.95),
      onBrand: Colors.white,
      // 动态取色下 primary 在深色模式是浅色 → 前景用 onPrimary（深色）
      onAccent: scheme.onPrimary,
      danger: isDark ? dark.danger : light.danger,
      warning: isDark ? dark.warning : light.warning,
    );
  }
}

/// 把 [AppColor] 挂进 ThemeData，页面里 `AppColor.of(context)` 就能拿到
/// （没有扩展时回落静态浅/深色，测试与桌面一样能用）。
class AppColorExt extends ThemeExtension<AppColorExt> {
  const AppColorExt(this.color);

  final AppColor color;

  @override
  AppColorExt copyWith({AppColor? color}) => AppColorExt(color ?? this.color);

  @override
  AppColorExt lerp(ThemeExtension<AppColorExt>? other, double t) {
    if (other is! AppColorExt) return this;
    return t < 0.5 ? this : other;
  }
}

/// 尺寸令牌（原 `Theme.ets` AppSize）
class AppSize {
  static const double pagePadding = 24;
  static const double titleSize = 30;
  static const double titleSizeMin = 22;

  /// 标题栏内容区高度（不含状态栏）
  static const double titleBarHeight = 60;

  /// 滚动多少后大标题完全收起
  static const double titleCollapseDistance = 90;
  static const double cardRadius = 24;
  static const double cardRadiusSm = 20;
  static const double buttonHeight = 52;
  static const double fieldHeight = 56;

  /// 悬浮底栏
  static const double barHeight = 60;
  static const double barRadius = 30;
  static const double barItemWidth = 68;
  static const double barShellWidth = 220;
}

/// 0 = 顶部未滚动，1 = 标题完全收起
double collapseRatio(double scrollY) =>
    (scrollY / AppSize.titleCollapseDistance).clamp(0.0, 1.0);

/// 大标题随滚动收缩
double collapsedTitleSize(double scrollY) =>
    AppSize.titleSize -
    (AppSize.titleSize - AppSize.titleSizeMin) * collapseRatio(scrollY);

/// 悬浮底栏 + 底部安全区的占位高度
/// （液态玻璃底栏：barHeight 60 + 上下各 20 的内边距 + 一点余量）
double barZone(double bottomInset) => bottomInset + AppSize.barHeight + 40;

/// 全局主题
///
/// [dynamicScheme] 非空时走 MD3 动态取色（莫奈变色，Android 12+ 系统给的那套）；
/// 为空则用应用自己的紫/绿配色。
ThemeData buildAppTheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
  final c = dynamicScheme == null
      ? AppColor.byBrightness(brightness)
      : AppColor.fromDynamic(dynamicScheme, brightness);
  final scheme = (dynamicScheme ??
          ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness))
      .copyWith(primary: c.accent, surface: c.card, error: c.danger);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.pageBg,
    extensions: [AppColorExt(c)],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
