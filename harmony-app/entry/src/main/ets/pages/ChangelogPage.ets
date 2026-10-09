import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import { CHANGELOG, ChangelogEntry } from '../model/Changelog';

/**
 * 更新日志（关于页二级页）：版本卡片手风琴。
 * 每张卡片一行（版本号 + 日期 + 箭头），点击展开显示条目列表，再点收起。
 * 展开箭头旋转 180°，条目列表带高度动画。
 */
@Component
export struct ChangelogPage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;
  /** 当前展开的版本下标（-1 = 全部收起） */
  @State expanded: number = 0;

  private toggle(index: number): void {
    this.expanded = this.expanded === index ? -1 : index;
    Haptics.light();
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

      Text('更新日志')
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
  VersionCard(entry: ChangelogEntry, index: number) {
    Column() {
      // 头行：版本号 + 日期 + 箭头
      Row() {
        Text(entry.version)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
        Blank()
        Text(entry.date)
          .fontSize(14)
          .fontColor(AppColor.TEXT_SECONDARY)
          .margin({ right: 8 })
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([AppColor.TEXT_SECONDARY])
          .rotate({ angle: this.expanded === index ? 180 : 0 })
          .animation({ duration: 220, curve: Curve.EaseInOut })
      }
      .width('100%')
      .height(56)
      .padding({ left: 18, right: 18 })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => {
        this.toggle(index);
      })

      // 条目列表：展开时显示（动画高度）
      if (this.expanded === index) {
        Column({ space: 10 }) {
          Divider()
            .color(AppColor.DIVIDER)
          ForEach(entry.items, (item: string, itemIndex: number) => {
            Row({ space: 8 }) {
              Text('·')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.ACCENT)
              Text(item)
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppColor.TEXT_PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (item: string, itemIndex: number) => `${index}_${itemIndex}_${item.length}`)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 16 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 })
          .combine(TransitionEffect.translate({ y: -6 })))
      }
    }
    .width('100%')
    .backgroundColor(AppColor.CARD)
    .borderRadius(AppSize.CARD_RADIUS_SM)
    .clip(true)
    .visualEffect(MaterialKit.cardReceiver())
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          ForEach(CHANGELOG, (entry: ChangelogEntry, index: number) => {
            this.VersionCard(entry, index)
          }, (entry: ChangelogEntry) => entry.version)

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
