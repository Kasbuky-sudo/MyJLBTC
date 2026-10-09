import { curves } from '@kit.ArkUI';

/** 动效工厂：所有转场/弹性参数集中在这里 */
export class AppAnim {
  /** 列表/卡片逐项入场：淡入 + 轻微缩放，延迟随 index 递增 */
  static enter(index: number): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
      .animation({
        duration: 280,
        curve: curves.springMotion(),
        delay: Math.min(index, 9) * 20 + 20
      });
  }

  /** 登录页 ↔ 主界面：进场淡入上浮，退场快速淡出 */
  static page(): TransitionEffect {
    return TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 14 }))
        .animation({ duration: 300, curve: Curve.FastOutSlowIn }),
      TransitionEffect.OPACITY
        .animation({ duration: 180, curve: Curve.EaseIn })
    );
  }

  /** 标题文字换页：新标题上滑淡入 */
  static titleSwap(): TransitionEffect {
    return TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 16 }))
        .animation({ duration: 260, curve: Curve.FastOutSlowIn }),
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -12 }))
        .animation({ duration: 160, curve: Curve.EaseIn })
    );
  }

  /** 通用弹性参数 */
  static spring(duration: number = 300): AnimateParam {
    return { duration: duration, curve: curves.springMotion(0.5, 0.9) };
  }
}
