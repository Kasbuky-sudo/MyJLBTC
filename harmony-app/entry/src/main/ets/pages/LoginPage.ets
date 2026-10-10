import { AppColor, AppSize, StoreKey } from '../common/Theme';
import { Haptics } from '../common/Haptics';
import { SchoolClient } from '../common/SchoolClient';
import { SystemGate } from '../common/SystemGate';
import { hilog } from '@kit.PerformanceAnalysisKit';

const COUNTDOWN_SECONDS: number = 60;

/**
 * 登录页：按学校实际流程走**一条**链路 —— 学号 + 密码 → 获取验证码（学校往账号绑定的手机号发短信）
 * → 填验证码 → 登录。所以卡片先是两行（学号/密码）、蓝按钮是「获取验证码」；
 * 验证码发出去后卡片长出第三行，蓝按钮变成「登录」。
 * 真正的网络请求都在 SchoolClient 里：发码 /cas/mobile/captcha，登录 POST /cas/login（RSA 加密密码）。
 */
@Component
export struct LoginPage {
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  onLoggedIn: () => void = () => {};

  @State studentId: string = '';
  @State password: string = '';
  @State code: string = '';
  @State codeSent: boolean = false;
  @State countdown: number = 0;
  @State agreed: boolean = false;
  @State loading: boolean = false;
  @State shakeX: number = 0;
  /** 系统版本不够新：只提示升级，不放行登录（进主界面必崩，见 SystemGate 注释） */
  @State systemTooOld: boolean = false;

  private codeTimer: number = -1;
  private shakeTimer: number = -1;

  aboutToAppear(): void {
    if (!SystemGate.ok()) {
      this.systemTooOld = true;
      hilog.warn(0x0000, 'LoginPage',
        `system too old: api=${SystemGate.currentVersion()}`);
      // 等页面渲染完再弹，避免弹窗被首帧盖掉
      setTimeout(() => {
        this.showUpgradeDialog();
      }, 450);
    }
  }

  aboutToDisappear(): void {
    if (this.codeTimer >= 0) {
      clearInterval(this.codeTimer);
      this.codeTimer = -1;
    }
    if (this.shakeTimer >= 0) {
      clearTimeout(this.shakeTimer);
      this.shakeTimer = -1;
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.warn(0x0000, 'LoginPage', 'toast unavailable');
    }
  }

  /** 低版本系统提示：应用用了 HarmonyOS 7.0 才提供的界面能力，低版本上没法跑 */
  private showUpgradeDialog(): void {
    const current: string = SystemGate.currentVersion();
    const required: string = SystemGate.requiredVersion();
    try {
      this.getUIContext().getPromptAction().showDialog({
        title: '请先升级系统',
        message: `当前系统版本${current.length > 0 ? `（${current}）` : ''}过低，暂时无法使用本应用。\n\n` +
          `本应用使用了 ${required} 才提供的界面能力，请升级到 ${required} 及以上后再登录：\n` +
          `设置 → 系统和更新 → 软件更新。`,
        buttons: [{ text: '知道了', color: AppColor.ACCENT }]
      }).catch((err: Error) => {
        hilog.warn(0x0000, 'LoginPage', 'upgrade dialog unavailable');
      });
    } catch (err) {
      hilog.warn(0x0000, 'LoginPage', 'upgrade dialog unavailable');
    }
  }

  /** 学号校验：学校学号是纯数字（本项目样例为 202411000000），这里只兜底位数 */
  private isStudentIdValid(): boolean {
    return this.studentId.length >= 6;
  }

  private shakeAgreement(): void {
    this.getUIContext().animateTo({
      duration: 55,
      iterations: 6,
      playMode: PlayMode.Alternate,
      curve: Curve.Linear
    }, () => {
      this.shakeX = 8;
    });
    if (this.shakeTimer >= 0) {
      clearTimeout(this.shakeTimer);
    }
    this.shakeTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
        this.shakeX = 0;
      });
      this.shakeTimer = -1;
    }, 420);
  }

  /** 统一前置校验：系统版本 + 协议 + 学号 + 密码 */
  private checkBeforeRequest(): boolean {
    if (this.systemTooOld) {
      // 低版本放行登录 = 进主界面闪退，只能请他升级
      this.showUpgradeDialog();
      Haptics.light();
      return false;
    }
    if (!this.agreed) {
      this.shakeAgreement();
      this.toast('请先阅读并同意用户协议与隐私政策');
      Haptics.light();
      return false;
    }
    if (!this.isStudentIdValid()) {
      this.toast('请输入学号');
      Haptics.light();
      return false;
    }
    if (this.password.length < 6) {
      this.toast('请输入密码（至少 6 位）');
      Haptics.light();
      return false;
    }
    return true;
  }

  /** 第一步：学号 + 密码换验证码（学校回什么就提示什么） */
  private async sendCode(): Promise<void> {
    if (this.countdown > 0 || this.loading) {
      return;
    }
    if (!this.checkBeforeRequest()) {
      return;
    }
    if (await SchoolClient.get().isCasSessionAlive()) {
      // 会话还在（比如刚退出登录又重新进）就不用再发短信，直接进主界面
      this.onLoggedIn();
      return;
    }
    this.loading = true;
    const result = await SchoolClient.get().sendSmsCode(this.studentId, this.password);
    this.loading = false;
    Haptics.light();
    if (!result.success) {
      this.toast(result.message);
      return;
    }
    this.toast(result.message);
    this.codeSent = true;
    this.countdown = COUNTDOWN_SECONDS;
    this.codeTimer = setInterval(() => {
      this.countdown = this.countdown - 1;
      if (this.countdown <= 0) {
        clearInterval(this.codeTimer);
        this.codeTimer = -1;
      }
    }, 1000);
  }

  /** 第二步：验证码登录 */
  private async submit(): Promise<void> {
    if (this.loading) {
      return;
    }
    if (this.systemTooOld) {
      this.showUpgradeDialog();
      Haptics.light();
      return;
    }
    if (!this.agreed) {
      this.shakeAgreement();
      this.toast('请先阅读并同意用户协议与隐私政策');
      Haptics.light();
      return;
    }
    if (this.code.length < 4) {
      this.toast('请输入短信验证码');
      Haptics.light();
      return;
    }
    this.loading = true;
    // 学号 / 加密密码 / 验证码 由 SchoolClient 一起提交给 CAS，成功后会话就留在客户端里
    const result = await SchoolClient.get().login(this.studentId, this.password, this.code);
    this.loading = false;
    Haptics.light();
    if (result.success) {
      // 登录账号是两大联网时机之一：让主界面挂一次网关、把课表和教务数据同步下来
      // （不阻塞进主界面，主界面里后台跑；下次打开只走本地缓存）
      AppStorage.setOrCreate('postLoginSync', true);
      this.onLoggedIn();
    } else {
      this.toast(result.message);
    }
  }

  private onMainClick(): void {
    if (this.codeSent) {
      this.submit();
    } else {
      this.sendCode();
    }
  }

  private huaweiLogin(): void {
    Haptics.light();
    this.toast('华为账号登录将在接入华为账号服务后可用');
  }

  build() {
    Column() {
      Text('MyJLBTC')
        .fontSize(AppSize.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.TEXT_PRIMARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: this.topInset + 56 })

      Blank().layoutWeight(2.4)

      Column({ space: 14 }) {
        // 系统版本过低：登录页就把话说清楚（点了还能再看一次说明弹窗）
        if (this.systemTooOld) {
          Column({ space: 4 }) {
            Text('系统版本过低，暂时无法登录')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.TEXT_PRIMARY)
            Text(`本应用需要 ${SystemGate.requiredVersion()} 及以上，请先升级系统（设置 → 系统和更新 → 软件更新）`)
              .fontSize(12)
              .fontColor(AppColor.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS)
          .border({ width: 1, color: AppColor.WARNING })
          .onClick(() => {
            this.showUpgradeDialog();
          })
        }

        Column() {
          Row() {
            TextInput({ text: this.studentId, placeholder: '学号' })
              .type(InputType.Number)
              .maxLength(20)
              .layoutWeight(1)
              .height(AppSize.FIELD_HEIGHT)
              .padding(0)
              .borderRadius(0)
              .backgroundColor(Color.Transparent)
              .fontSize(16)
              .fontColor(AppColor.TEXT_PRIMARY)
              .placeholderColor(AppColor.PLACEHOLDER)
              .caretColor(AppColor.ACCENT)
              .onChange((value: string) => {
                this.studentId = value;
              })
          }
          .padding({ left: 18, right: 18 })

          Divider()
            .color(AppColor.DIVIDER)
            .margin({ left: 18, right: 18 })

          Row() {
            TextInput({ text: this.password, placeholder: '密码' })
              .type(InputType.Password)
              .showPasswordIcon(true)
              .maxLength(32)
              .layoutWeight(1)
              .height(AppSize.FIELD_HEIGHT)
              .padding(0)
              .borderRadius(0)
              .backgroundColor(Color.Transparent)
              .fontSize(16)
              .fontColor(AppColor.TEXT_PRIMARY)
              .placeholderColor(AppColor.PLACEHOLDER)
              .caretColor(AppColor.ACCENT)
              .onChange((value: string) => {
                this.password = value;
              })
          }
          .padding({ left: 18, right: 18 })

          // 验证码行：发码之后才出现（学校流程的第二步）
          if (this.codeSent) {
            Divider()
              .color(AppColor.DIVIDER)
              .margin({ left: 18, right: 18 })

            Row({ space: 12 }) {
              TextInput({ text: this.code, placeholder: '验证码' })
                .type(InputType.Number)
                .maxLength(6)
                .layoutWeight(1)
                .height(AppSize.FIELD_HEIGHT)
                .padding(0)
                .borderRadius(0)
                .backgroundColor(Color.Transparent)
                .fontSize(16)
                .fontColor(AppColor.TEXT_PRIMARY)
                .placeholderColor(AppColor.PLACEHOLDER)
                .caretColor(AppColor.ACCENT)
                .onChange((value: string) => {
                  this.code = value;
                })
              Text(this.countdown > 0 ? `${this.countdown} s 后重发` : '重新获取')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.countdown > 0 ? AppColor.TEXT_SECONDARY : AppColor.ACCENT)
                .onClick(() => {
                  this.sendCode();
                })
            }
            .padding({ left: 18, right: 18 })
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: -8 }))
              .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
          }
        }
        .width('100%')
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS)
        .clip(true)

        Button() {
          if (this.loading) {
            LoadingProgress()
              .width(22)
              .height(22)
              .color(AppColor.ON_BRAND)
          } else {
            Text(this.codeSent ? '登录' : '获取验证码')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.ON_BRAND)
          }
        }
        .width('100%')
        .height(AppSize.BUTTON_HEIGHT)
        .borderRadius(AppSize.BUTTON_HEIGHT / 2)
        .backgroundColor(AppColor.ACCENT)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.98 })
        .onClick(() => {
          this.onMainClick();
        })

        Button() {
          Text('通过华为账号登录')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.ON_BRAND)
        }
        .width('100%')
        .height(AppSize.BUTTON_HEIGHT)
        .borderRadius(AppSize.BUTTON_HEIGHT / 2)
        .backgroundColor(AppColor.HUAWEI_RED)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.98 })
        .onClick(() => {
          this.huaweiLogin();
        })

        Row({ space: 7 }) {
          if (this.agreed) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(17)
              .fontColor([AppColor.ACCENT])
          } else {
            SymbolGlyph($r('sys.symbol.circle'))
              .fontSize(17)
              .fontColor([AppColor.PLACEHOLDER])
          }
          Text() {
            Span('我已阅读并同意').fontColor(AppColor.TEXT_SECONDARY)
            Span('《用户协议》').fontColor(AppColor.ACCENT)
            Span('与').fontColor(AppColor.TEXT_SECONDARY)
            Span('《隐私政策》').fontColor(AppColor.ACCENT)
          }
          .fontSize(12)
        }
        .height(44)
        .padding({ left: 10, right: 10 })
        .margin({ top: 2 })
        .translate({ x: this.shakeX })
        // Block：整行（含文字之间的空隙）都是有效点击区域
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.agreed = !this.agreed;
          Haptics.light();
        })
      }
      .width('100%')
      .padding({ left: AppSize.PAGE_PADDING, right: AppSize.PAGE_PADDING })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
