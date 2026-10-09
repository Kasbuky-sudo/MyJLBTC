import { AppAnim } from '../common/Animation';
import { AppColor, AppSize } from '../common/Theme';
import { MaterialKit } from '../common/Material';

/** 大号统计卡：标题 + 绿色大数字 + 刷新按钮；按下时变成紫色点光源照亮相邻卡片 */
@Component
export struct StatCard {
  @Prop label: string;
  @Prop value: string;
  @Prop refreshing: boolean = false;
  onRefresh: () => void = () => {};
  @State lightPressed: boolean = false;

  build() {
    Column({ space: 10 }) {
      Text(this.label)
        .fontSize(15)
        .fontColor(AppColor.TEXT_PRIMARY)
      Text(this.value)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.GREEN)
        .opacity(this.refreshing ? 0.35 : 1)
        .animation(AppAnim.spring(220))
      Row() {
        Text('刷新')
          .fontSize(13)
          .fontColor(AppColor.ON_BRAND)
      }
      .height(32)
      .padding({ left: 22, right: 22 })
      .borderRadius(16)
      .backgroundColor(AppColor.ACCENT)
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
      .onClick(() => {
        this.onRefresh();
      })
    }
    .layoutWeight(1)
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(AppColor.CARD)
    .borderRadius(AppSize.CARD_RADIUS_SM)
    .alignItems(HorizontalAlign.Center)
    // 沉浸光感点光源：平时受光，按下时自身发光照亮周围卡片
    .visualEffect(MaterialKit.cardEffectBy(this.lightPressed))
    .onTouch((event: TouchEvent) => {
      this.lightPressed = event.type === TouchType.Down;
    })
  }
}
