/**
 * 全局设计令牌：颜色、尺寸只在这里定义，页面里不出现魔法值。
 * 颜色走资源引用（resources/base 与 resources/dark 同名不同值），深色模式由系统解析。
 */
export class AppColor {
  static readonly PAGE_BG: Resource = $r('app.color.page_bg');
  static readonly CARD: Resource = $r('app.color.card');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.text_primary');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly TEXT_META: Resource = $r('app.color.text_meta');
  static readonly PLACEHOLDER: Resource = $r('app.color.placeholder');
  static readonly ACCENT: Resource = $r('app.color.accent');
  static readonly ACCENT_SOFT: Resource = $r('app.color.accent_soft');
  static readonly HUAWEI_RED: Resource = $r('app.color.huawei_red');
  /** 危险/破坏性操作用色（退出登录等），与华为品牌红区分开 */
  static readonly DANGER: Resource = $r('app.color.danger');
  /** 警示色（及格、待办提醒等） */
  static readonly WARNING: Resource = $r('app.color.warning');
  static readonly GREEN: Resource = $r('app.color.brand_green');
  static readonly PROFILE_FROM: Resource = $r('app.color.profile_from');
  static readonly PROFILE_TO: Resource = $r('app.color.profile_to');
  static readonly DIVIDER: Resource = $r('app.color.divider');
  static readonly CHIP_BG: Resource = $r('app.color.chip_bg');
  static readonly TRACK: Resource = $r('app.color.track');
  static readonly BAR_BG: Resource = $r('app.color.bar_bg');
  static readonly BAR_SHADOW: Resource = $r('app.color.bar_shadow');
  static readonly TITLE_BAR_BG: Resource = $r('app.color.title_bar_bg');
  /** 品牌色底上的文字（纯白，两个模式一致） */
  static readonly ON_BRAND: Resource = $r('app.color.on_brand');
}

export class AppSize {
  static readonly PAGE_PADDING: number = 24;
  static readonly TITLE_SIZE: number = 30;
  static readonly TITLE_SIZE_MIN: number = 22;
  /** 标题栏内容区高度（不含状态栏） */
  static readonly TITLE_BAR_HEIGHT: number = 60;
  /** 滚动多少 vp 后大标题完全收起 */
  static readonly TITLE_COLLAPSE_DISTANCE: number = 90;
  static readonly CARD_RADIUS: number = 24;
  static readonly CARD_RADIUS_SM: number = 20;
  static readonly BUTTON_HEIGHT: number = 52;
  static readonly FIELD_HEIGHT: number = 56;
  static readonly BAR_HEIGHT: number = 60;
  static readonly BAR_RADIUS: number = 30;
  static readonly BAR_ITEM_WIDTH: number = 68;
  /** 悬浮栏外壳宽度：3 个 item + 左右 padding，壳宽必须收窄到实际占位（官方材质槽位的限制） */
  static readonly BAR_SHELL_WIDTH: number = 220;
}

/** AppStorage 键名集中管理 */
export class StoreKey {
  static readonly SCROLL_Y: string = 'pageScrollY';
  static readonly TOP_INSET: string = 'topInset';
  static readonly BOTTOM_INSET: string = 'bottomInset';
}

/** 标题栏总高度：状态栏 + 内容区 */
export function titleBarHeight(topInset: number): number {
  return topInset + AppSize.TITLE_BAR_HEIGHT;
}

/** 0 = 顶部未滚动，1 = 标题完全收起 */
export function collapseRatio(scrollY: number): number {
  return Math.min(1, Math.max(0, scrollY / AppSize.TITLE_COLLAPSE_DISTANCE));
}

/** 大标题随滚动收缩 */
export function collapsedTitleSize(scrollY: number): number {
  return AppSize.TITLE_SIZE - (AppSize.TITLE_SIZE - AppSize.TITLE_SIZE_MIN) * collapseRatio(scrollY);
}

/** 悬浮底栏 + 底部安全区的占位高度 */
export function barZone(bottomInset: number): number {
  return bottomInset + AppSize.BAR_HEIGHT + 18;
}
