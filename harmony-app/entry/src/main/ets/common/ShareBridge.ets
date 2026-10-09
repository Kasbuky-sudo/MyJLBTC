import { harmonyShare, systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ShareBridge';

/**
 * 跨端分享（碰一碰 + 隔空手势）的注册/注销收口。
 *
 * 页面只需要给一个"取当前分享数据"的回调：
 * - 进页面 register()：注册 knockShare（不需要 windowId）与 gesturesShare（需要 windowId）；
 * - 离开页面 unregister()：必须注销，否则退到后台也会被触发；
 * - 回调里 3 秒内必须 share()，所以分享数据要在页面里提前生成好缓存（取不到就先跳过并提示）。
 */
export class ShareBridge {
  private getData: () => Promise<systemShare.SharedData | undefined>;
  private onEmpty: () => void;
  private windowId: number = 0;
  private registered: boolean = false;

  private knockCallback = (target: harmonyShare.SharableTarget): void => {
    this.send(target);
  };

  private gestureCallback = (target: harmonyShare.SharableTarget): void => {
    this.send(target);
  };

  constructor(getData: () => Promise<systemShare.SharedData | undefined>, onEmpty: () => void) {
    this.getData = getData;
    this.onEmpty = onEmpty;
  }

  private send(target: harmonyShare.SharableTarget): void {
    // 现取（页面会在回调里先截图生成）——碰一碰要求 3 秒内 share，截图+打包通常几百毫秒
    this.getData().then((data: systemShare.SharedData | undefined) => {
      if (data === undefined) {
        this.onEmpty();
        return;
      }
      target.share(data).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'cross-device share failed: %{public}s', err.message);
      });
    });
  }

  async register(context: common.UIAbilityContext): Promise<void> {
    if (this.registered) {
      return;
    }
    try {
      harmonyShare.on('knockShare', this.knockCallback);
      const win: window.Window = await window.getLastWindow(context);
      this.windowId = win.getWindowProperties().id;
      const capability: harmonyShare.SendCapabilityRegistry = { windowId: this.windowId };
      harmonyShare.on('gesturesShare', capability, this.gestureCallback);
      this.registered = true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'register failed: %{public}d %{public}s', error.code, error.message);
    }
  }

  unregister(): void {
    if (!this.registered) {
      return;
    }
    harmonyShare.off('knockShare', this.knockCallback);
    const capability: harmonyShare.SendCapabilityRegistry = { windowId: this.windowId };
    harmonyShare.off('gesturesShare', capability, this.gestureCallback);
    this.registered = false;
  }
}
