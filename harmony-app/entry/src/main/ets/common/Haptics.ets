import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'Haptics';

/** 轻触感反馈：无能力/无权限时静默降级 */
export class Haptics {
  static light(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'unknown' })
        .catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'vibrate skipped: %{public}d', err.code);
        });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'vibrate unsupported');
    }
  }
}
