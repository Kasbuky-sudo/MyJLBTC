import { AppColor } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';

/**
 * 导航栏里的分享键：和返回键同一套（40×40 圆形 + 沉浸材质 + 按压反馈）。
 * 凡是标题栏带分享的二级页都用它，保证大小、材质、手感一致。
 */
@Component
export struct ShareButton {
  onShare: () => void = () => {};

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.share'))
        .fontSize(20)
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
      Haptics.light();
      this.onShare();
    })
  }
}
