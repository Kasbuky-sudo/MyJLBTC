import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor, AppSize } from '../common/Theme';
import { ScheduleStore } from '../model/ScheduleStore';
import { SystemGate } from '../common/SystemGate';

/** 启动页各阶段 */
const STEP_CHECK: number = 1;
const STEP_DONE: number = 4;

/**
 * 应用内启动页：纯本地检查，秒进主界面（不联网）。
 *
 * 口径（用户定）：打开 App 只用本机缓存，不重连服务器；联网只发生在
 * 「首页手动刷新」和「登录账号」两处。
 * 本地有课表缓存 = 同步过一次 → 直接进主界面（离线可用）；
 * 没有任何缓存（新装 / 从没同步过）→ 登录页。
 * 会话过期不在这里探测，交给下次真实请求被服务端拒绝时处理。
 */
@Entry
@Component
struct Splash {
  @State step: number = 0;
  @State statusText: string = '正在启动';

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    this.step = STEP_CHECK;
    const supported: boolean = SystemGate.ok();
    hilog.info(0x0000, 'Splash', 'system gate: api=%{public}d version=%{public}s supported=%{public}s',
      SystemGate.apiVersion(), SystemGate.currentVersion(), `${supported}`);
    // 低版本系统（< HarmonyOS 7.0）没有沉浸光感那套属性，一进主界面就 "xxx is not callable" 闪退，
    // 所以先看系统版本：不够新就直接去登录页，由登录页弹窗请用户升级系统。
    if (!supported) {
      this.statusText = '系统版本过低…';
      this.gotoIndex(false);
      return;
    }
    // 口径（用户定）：打开 App 不联网、只用本机缓存；联网只发生在
    // 「首页手动刷新」和「登录账号」两处。启动页只做本地检查，秒进。
    // 会话死没死交给服务端在下次真实请求时拒绝来体现，不在这里提前探测。
    const hasData: boolean = await ScheduleStore.hasCachedData();
    if (hasData) {
      this.gotoIndex(true);
      return;
    }
    // 没有任何缓存（新装 / 从没同步过）：去登录页
    this.statusText = '正在检查登录状态…';
    this.gotoIndex(false);
  }

  private gotoIndex(loggedIn: boolean): void {
    if (this.step === STEP_DONE) {
      return;
    }
    this.step = STEP_DONE;
    AppStorage.setOrCreate('appLoggedIn', loggedIn);
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Stack() {
      Column() {
        // 上半：居中大 logo + 应用名（对齐用户示意）
        Blank().layoutWeight(5)

        // 白 logo 垫在品牌紫渐变圆角块上：浅色模式下也看得清。
        // 比例照关于页那套（logo 130 / 块 96，前景溢出裁切贴满），不搞"小图居中在大色块里"
        Stack() {
          Image($r('app.media.foreground'))
            .width(220)
            .height(220)
            .objectFit(ImageFit.Contain)
        }
        .width(160)
        .height(160)
        .borderRadius(38)
        .clip(true)
        .linearGradient({
          angle: 135,
          colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
        })

        Text('MyJLBTC')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
          .margin({ top: 24 })

        Blank().layoutWeight(6)

        // 底部：状态文字（正在连接学校服务器…）
        Text(this.statusText)
          .fontSize(14)
          .fontColor(AppColor.TEXT_SECONDARY)
          .margin({ bottom: 64 })
      }
      .width('100%')
      .height('100%')

    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.PAGE_BG)
  }
}
