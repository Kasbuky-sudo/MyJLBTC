import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const APPEARANCE_FOLLOW: number = 0;
export const APPEARANCE_LIGHT: number = 1;
export const APPEARANCE_DARK: number = 2;

export const APPEARANCE_LABELS: string[] = ['跟随系统', '浅色', '深色'];

/** 应用外观模式：0 跟随系统 / 1 浅色 / 2 深色 */
export class Appearance {
  static apply(context: common.UIAbilityContext, mode: number): void {
    let target: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (mode === APPEARANCE_LIGHT) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (mode === APPEARANCE_DARK) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      context.getApplicationContext().setColorMode(target);
    } catch (err) {
      hilog.error(0x0000, 'Appearance', 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
  }
}
