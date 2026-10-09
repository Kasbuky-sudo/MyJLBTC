import { Want, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import { DOC_UPDATED_AT, DocSection, USER_AGREEMENT } from '../model/LegalDocs';

const DOMAIN = 0x0000;
const TAG = 'AboutPage';

/**
 * 隐私声明：由华为应用市场托管（AGC 生成），应用内不再自建正文。
 * 点击"隐私政策"→ 弹窗确认 → 交系统浏览器打开。
 */
const PRIVACY_URL: string =
  'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2053813468083037120';

/**
 * 关于 MyJLBTC：应用图标 + 版本 + 信息行 + 用户协议/隐私政策。
 * 版本展示文案在 DISPLAY_VERSION 常量里：版本号 + 平台 + 构建日期（261005 = 2026-10-05）；
 * 协议正文在 model/LegalDocs.ets 里单独维护。
 */
@Component
export struct AboutPage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;
  @State showDoc: boolean = false;
  @State docTitle: string = '';
  @State docSections: DocSection[] = [];
  @State cardLight: boolean = false;

  /** 关于页展示的版本文案：版本号 + 平台 + 构建日期（261005 = 2026-10-05） */
  private readonly DISPLAY_VERSION: string = '1.0.8.HarmonyOS.arkts.261007';

  private versionName(): string {
    return this.DISPLAY_VERSION;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'toast unavailable');
    }
  }

  private openDoc(title: string, sections: DocSection[]): void {
    this.docTitle = title;
    this.docSections = sections;
    this.showDoc = true;
    Haptics.light();
  }

  /** 隐私声明不在应用里读了：先弹窗说清楚"要离开应用"，再去浏览器 */
  private confirmOpenPrivacy(): void {
    Haptics.light();
    this.getUIContext().getPromptAction()
      .showDialog({
        title: '隐私政策',
        message: '将用系统浏览器打开由华为应用市场托管的隐私声明页面。',
        buttons: [
          { text: '取消', color: AppColor.TEXT_SECONDARY },
          { text: '打开浏览器', color: AppColor.ACCENT }
        ]
      })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.openPrivacyInBrowser();
        }
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'privacy dialog failed: %{public}d %{public}s', err.code, err.message);
      });
  }

  private openPrivacyInBrowser(): void {
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: PRIVACY_URL
    };
    context.startAbility(want).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'open privacy failed: %{public}d %{public}s', err.code, err.message);
      this.toast('没能打开浏览器，可稍后重试');
    });
  }

  @Builder
  NavigationBar() {
    Row({ space: 2 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([AppColor.TEXT_PRIMARY])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.CHIP_BG)
      .systemMaterial(MaterialKit.iconButton())
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.92 })
      .onClick(() => {
        this.pathStack.pop();
      })

      Text('关于')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.TEXT_PRIMARY)
        .layoutWeight(1)
        .margin({ left: 6 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: this.topInset, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.TITLE_BAR_BG)
    .backdropBlur(MaterialKit.supported() ? 0 : 24)
    .systemMaterial(MaterialKit.navigationBar())
  }

  @Builder
  InfoRow(label: string, value: string, arrow: boolean, isLast: boolean, action: () => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(15)
          .fontColor(AppColor.TEXT_PRIMARY)
        Blank()
        Text(value)
          .fontSize(14)
          .fontColor(AppColor.TEXT_SECONDARY)
          .margin({ right: arrow ? 6 : 0 })
        if (arrow) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(15)
            .fontColor([AppColor.TEXT_SECONDARY])
        }
      }
      .width('100%')
      .height(56)
      .clickEffect(arrow ? { level: ClickEffectLevel.LIGHT } : null)
      .onClick(() => {
        if (arrow) {
          action();
        }
      })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  /** 协议 / 政策文档半模态（分章节） */
  @Builder
  DocSheet() {
    Scroll() {
      Column({ space: 20 }) {
        ForEach(this.docSections, (section: DocSection) => {
          Column({ space: 8 }) {
            Text(section.title)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.TEXT_PRIMARY)
              .width('100%')
            ForEach(section.paragraphs, (paragraph: string) => {
              Text(paragraph)
                .fontSize(15)
                .lineHeight(26)
                .fontColor(AppColor.TEXT_PRIMARY)
                .width('100%')
            }, (paragraph: string, index: number) => `${index}_${paragraph.length}`)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (section: DocSection) => section.title)

        Text(DOC_UPDATED_AT)
          .fontSize(13)
          .fontColor(AppColor.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 40 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          // 应用图标 + 名称 + 版本（用真实分层图标的前景层叠在品牌紫上，和桌面图标同源）
          Column({ space: 10 }) {
            Stack() {
              Image($r('app.media.foreground'))
                .width(130)
                .height(130)
                .objectFit(ImageFit.Contain)
            }
            .width(96)
            .height(96)
            .borderRadius(26)
            .clip(true)
            .linearGradient({
              angle: 135,
              colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
            })

            Text('MyJLBTC')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.TEXT_PRIMARY)

            Text(`版本 ${this.versionName()}`)
              .fontSize(13)
              .fontColor(AppColor.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 24, bottom: 8 })

          // 信息卡
          Column() {
            this.InfoRow('版本号', this.versionName(), false, false, () => {
            })
            this.InfoRow('开发者', 'anlanas', false, false, () => {
            })
            this.InfoRow('检查更新', '', true, false, () => {
              Haptics.light();
              this.toast('已是最新版本（演示）');
            })
            this.InfoRow('更新日志', '', true, false, () => {
              Haptics.light();
              this.pathStack.pushPath({ name: 'ChangelogPage' });
            })
            this.InfoRow('AI 辅助编程公示', '', true, false, () => {
              Haptics.light();
              this.pathStack.pushPath({ name: 'AiCreditsPage' });
            })
            this.InfoRow('用户协议', '', true, false, () => {
              this.openDoc('用户协议', USER_AGREEMENT);
            })
            this.InfoRow('隐私政策', '应用市场托管', true, true, () => {
              this.confirmOpenPrivacy();
            })          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          // 沉浸光感点光：平时受光，按下时自身发紫光
          .visualEffect(MaterialKit.cardEffectBy(this.cardLight))
          .onTouch((event: TouchEvent) => {
      this.cardLight = event.type === TouchType.Down;
    })

          Text('© 2026 MyJLBTC')
            .fontSize(12)
            .fontColor(AppColor.PLACEHOLDER)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 24 })

          Column().height(this.bottomInset + 32)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8 })
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ minHeight: this.viewportHeight })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.viewportHeight = newValue.height as number;
      })
    }
    .title({ builder: this.NavigationBar(), height: titleBarHeight(this.topInset) },
      { barStyle: BarStyle.STACK })
    .hideBackButton(true)
    .backgroundColor(AppColor.PAGE_BG)
    .bindSheet($$this.showDoc, this.DocSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: true,
      dragBar: false,
      title: { title: this.docTitle },
      backgroundColor: AppColor.PAGE_BG,
      onDisappear: () => {
        this.showDoc = false;
      },
      onWillSpringBackWhenDismiss: () => {
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
