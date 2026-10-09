import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';

/** 一个 AI 模型的公示行：logo 资源（深浅主题自动切换）+ 名称 + 用途说明。
 *  彩色 logo（如小艺）用彩色=true，走单份资源不做深浅变色。 */
class AiModel {
  name: string;
  usage: string;
  icon: Resource;
  colored: boolean;

  constructor(name: string, usage: string, icon: Resource, colored: boolean) {
    this.name = name;
    this.usage = usage;
    this.icon = icon;
    this.colored = colored;
  }
}

const AI_MODELS: AiModel[] = [
  // HUAWEI PANGU（盘古）：华为系统级 AI，告诉了我们具体组件怎么写、怎么调用；logo 本身彩色渐变，不分深浅主题
  new AiModel('HUAWEI PANGU', '组件写法与调用方式指引', $r('app.media.ic_ai_pangu'), true),
  new AiModel('DeepSeek V4.1 Flash', '接口调用与组件开发', $r('app.media.ic_ai_deepseek'), false),
  new AiModel('GLM-5.3', '部分协议逆向与教务接口排查', $r('app.media.ic_ai_glm'), false),
  new AiModel('GLM-5.3 Flash', '接口调用与组件开发', $r('app.media.ic_ai_glm'), false),
  new AiModel('Kimi K3', '部分协议逆向与教务接口排查', $r('app.media.ic_ai_kimi'), false)
];

/**
 * AI 辅助编程公示（关于页二级页）：
 * 开发过程使用了哪些 AI 模型、各自做了什么。左 logo 右文字；
 * logo 为 SVG 资源，深色模式自动切白色（resources/dark/media），浅色为黑。
 */
@Component
export struct AiCreditsPage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;

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

      Column({ space: 2 }) {
        Text('AI 辅助编程公示')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
        Text('开发透明度声明')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: this.topInset, bottom: 8 })
    .alignItems(VerticalAlign.Bottom)
    .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.TITLE_BAR_BG)
    .backdropBlur(MaterialKit.supported() ? 0 : 24)
    .systemMaterial(MaterialKit.navigationBar())
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          // 说明卡
          Column({ space: 6 }) {
            Text('本应用在开发过程中使用了下列 AI 模型辅助编程。')
              .fontSize(14)
              .lineHeight(22)
              .fontColor(AppColor.TEXT_PRIMARY)
            Text('所有代码均经人工审核后提交，学校数据只在你的手机本地处理。')
              .fontSize(14)
              .lineHeight(22)
              .fontColor(AppColor.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          .visualEffect(MaterialKit.cardReceiver())

          // 模型列表卡：左 logo 右文字
          Column() {
            ForEach(AI_MODELS, (model: AiModel, index: number) => {
              Column() {
                Row({ space: 14 }) {
                  Image(model.icon)
                    .width(26)
                    .height(26)
                    .objectFit(ImageFit.Contain)
                  Column({ space: 3 }) {
                    Text(model.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColor.TEXT_PRIMARY)
                    Text(model.usage)
                      .fontSize(13)
                      .fontColor(AppColor.TEXT_SECONDARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 18, right: 18, top: 15, bottom: 15 })

                if (index < AI_MODELS.length - 1) {
                  Divider()
                    .color(AppColor.DIVIDER)
                    .margin({ left: 58, right: 18 })
                }
              }
              .width('100%')
            }, (model: AiModel) => model.name)
          }
          .width('100%')
          .padding({ top: 3, bottom: 3 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          .visualEffect(MaterialKit.cardReceiver())

          Text('模型名称与商标归各自所有者所有')
            .fontSize(12)
            .fontColor(AppColor.PLACEHOLDER)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })

          Column().height(this.bottomInset + 24)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
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
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
