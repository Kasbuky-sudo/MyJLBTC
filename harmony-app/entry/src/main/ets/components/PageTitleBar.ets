import { AppAnim } from '../common/Animation';
import { AppColor, AppSize, collapseRatio, collapsedTitleSize, StoreKey } from '../common/Theme';
import { MaterialKit } from '../common/Material';

/**
 * 官方槽位标题栏（Navigation / NavDestination 的 title 槽位 + barStyle: STACK）：
 * 大标题随滚动收缩、底部发丝线随滚动淡入、换页时标题上滑淡入。
 * 材质常显（不再随滚动淡入）：否则内容不足一屏、滚不动的页面（课表/我的）永远看不到玻璃。
 */
@Component
export struct PageTitleBar {
  @Prop title: string;
  /** 二级页显示返回箭头 */
  @Prop showBack: boolean = false;
  onBack: () => void = () => {};
  @StorageProp(StoreKey.SCROLL_Y) scrollY: number = 0;
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.TITLE_BAR_BG)
        .backdropBlur(MaterialKit.supported() ? 0 : 24)
        .systemMaterial(MaterialKit.titleBar())

      Column()
        .width('100%')
        .height(0.5)
        .backgroundColor(AppColor.DIVIDER)
        .opacity(collapseRatio(this.scrollY) * 0.9)

      Row({ space: 4 }) {
        if (this.showBack) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([AppColor.TEXT_PRIMARY])
            .margin({ right: 2 })
            .onClick(() => {
              this.onBack();
            })
        }
        ForEach([this.title], (text: string) => {
          Text(text)
            .fontSize(collapsedTitleSize(this.scrollY))
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.TEXT_PRIMARY)
            .maxLines(1)
            .transition(AppAnim.titleSwap())
        }, (text: string) => text)
      }
      .width('100%')
      .height('100%')
      .padding({ left: AppSize.PAGE_PADDING, right: AppSize.PAGE_PADDING, top: this.topInset, bottom: 12 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
