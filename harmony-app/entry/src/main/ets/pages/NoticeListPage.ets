import { AppAnim } from '../common/Animation';
import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import { NoticeParam, NoticeRecord, notices } from '../model/NoticeData';

/**
 * 通知公告列表（首页公告条点进来的第一层）：
 * 一行一条（标题两行 + 作者·时间 + 箭头），点进去是详情页。
 * 首页公告条只显示最新一条，全部通知在这里看。
 */
@Component
export struct NoticeListPage {
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

      Text('通知公告')
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
  NoticeRow(notice: NoticeRecord, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(notice.title)
            .fontSize(16)
            .fontColor(AppColor.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${notice.author} · ${notice.time}`)
            .fontSize(12)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppColor.TEXT_SECONDARY])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => {
        Haptics.light();
        this.pathStack.pushPath({ name: 'NoticePage', param: new NoticeParam(notice.id) });
      })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          Column() {
            ForEach(notices, (notice: NoticeRecord, index: number) => {
              this.NoticeRow(notice, index === notices.length - 1)
            }, (notice: NoticeRecord) => notice.id)
          }
          .width('100%')
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          .transition(AppAnim.enter(0))

          Column().height(this.bottomInset + 24)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8 })
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
