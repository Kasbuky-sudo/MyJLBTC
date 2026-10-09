import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import { ShareUtil } from '../common/ShareUtil';
import { ShareBridge } from '../common/ShareBridge';
import { ShareButton } from '../components/ShareButton';
import { latestNotice, NoticeParam, NoticeRecord, noticeById } from '../model/NoticeData';

const DOMAIN = 0x0000;
const TAG = 'NoticePage';

/**
 * 通知公告详情（版式对齐学校"站内信函"页）：标题 / 作者 + 时间 / 正文分段 / 落款。
 *
 * 分享做了三路（都基于同一份分享数据：一张由内容生成的长图 + 一条文本）：
 * - 右上角图标 → 系统分享面板（systemShare.ShareController.show）
 * - 碰一碰（harmonyShare 'knockShare'）
 * - 隔空手势（harmonyShare 'gesturesShare'，需要 windowId）
 * 进页面时预生成分享图并缓存，这样碰一碰/隔空回调里能立刻 share()（官方要求回调后 3 秒内发出）。
 */
@Component
export struct NoticePage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;
  @State noticeId: string = '';
  private scroller: Scroller = new Scroller();
  private shareData: systemShare.SharedData | undefined = undefined;
  private shareBridge: ShareBridge = new ShareBridge(async () => {
    await this.prepareShare();
    return this.shareData;
  }, () => {
    this.toast('分享内容生成失败，请重试');
  });

  private notice(): NoticeRecord {
    const found: NoticeRecord | undefined = noticeById(this.noticeId);
    return found !== undefined ? found : latestNotice();
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'toast unavailable');
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }


  /**
   * 把通知正文截成图片并组装分享数据。
   * 走官方口径：`componentSnapshot.get(组件id, { scale, waitUntilRenderFinished })`
   * → `packToFile` 存 cacheDir → `fileUri.getUriFromPath()` 拿 URI。
   * 在内容 onAppear 后执行，这样碰一碰/隔空回调里能直接发缓存好的数据。
   */
  private async prepareShare(): Promise<void> {
    try {
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot()
        .get('noticeContent', { scale: 2, waitUntilRenderFinished: true });
      const uri: string = await ShareUtil.buildImageFileUri(this.context(), pixelMap,
        `notice_${this.notice().id}_${Date.now()}.png`);
      this.shareData = ShareUtil.buildImageData(this.notice().title,
        `来自 MyJLBTC App · ${this.notice().author}`, uri,
        this.noticeText());
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'build share image failed: %{public}d %{public}s',
        error.code, error.message);
    }
  }

  /**
   * 分享前**现截图**：既保证内容已渲染完（入场动画期间截会得到空列表），
   * 也保证改过筛选后拿到的是最新内容。
   */
  private withShareData(action: (data: systemShare.SharedData) => void): void {
    this.prepareShare().then(() => {
      const fresh: systemShare.SharedData | undefined = this.shareData;
      if (fresh !== undefined) {
        action(fresh);
      } else {
        this.toast('分享内容生成失败，请重试');
      }
    });
  }

  /** 纯文本分享的内容：**全文**（标题 + 作者时间 + 所有正文段落 + 落款） */
  private noticeText(): string {
    const notice: NoticeRecord = this.notice();
    const head: string = `【通知公告】${notice.title}\n${notice.author} ${notice.time}`;
    const body: string = notice.paragraphs.join('\n\n');
    return `${head}\n\n${body}\n\n${notice.signature}\n\n来自 MyJLBTC App`;
  }

  private showSharePanel(): void {
    this.withShareData((data: systemShare.SharedData) => {
      ShareUtil.showSystemShare(this.context(), data);
    });
  }

  aboutToDisappear(): void {
    // 离开页面必须注销，否则退到后台也会被触发
    this.shareBridge.unregister();
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

      Text('站内信函')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.TEXT_PRIMARY)
        .layoutWeight(1)
        .margin({ left: 6 })

      ShareButton({
        onShare: () => {
          this.showSharePanel();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 12, top: this.topInset, bottom: 8 })
    // 单行标题和返回键居中对齐（底部对齐会显得标题偏下）
    .alignItems(VerticalAlign.Center)
    .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.TITLE_BAR_BG)
    .backdropBlur(MaterialKit.supported() ? 0 : 24)
    .systemMaterial(MaterialKit.navigationBar())
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          Column().height(titleBarHeight(this.topInset))

          // 这块就是分享出去的长图（id 给 componentSnapshot.get 用），自带内边距和底色
          Column({ space: 0 }) {
            Text(this.notice().title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.TEXT_PRIMARY)
              .lineHeight(34)
              .width('100%')

            Row({ space: 8 }) {
              Text(this.notice().author)
                .fontSize(14)
                .fontColor(AppColor.ACCENT)
              Text(this.notice().time)
                .fontSize(14)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ top: 10 })

            Divider()
              .color(AppColor.DIVIDER)
              .margin({ top: 16, bottom: 16 })

            ForEach(this.notice().paragraphs, (paragraph: string) => {
              Text(paragraph)
                .fontSize(16)
                .lineHeight(28)
                .fontColor(AppColor.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 14 })
            }, (paragraph: string, index: number) => `${index}_${paragraph.length}`)

            Text(this.notice().signature)
              .fontSize(16)
              .lineHeight(28)
              .fontColor(AppColor.TEXT_PRIMARY)
              .width('100%')
              .margin({ top: 8 })

            // 分享出去的长图落款（在截图区域内）
            Text('来自 MyJLBTC App')
              .fontSize(12)
              .fontColor(AppColor.PLACEHOLDER)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 28 })
          }
          .id('noticeContent')
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 24 })
          .backgroundColor(AppColor.PAGE_BG)
          .alignItems(HorizontalAlign.Start)

          Column().height(this.bottomInset + 32)
        }
        .width('100%')
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
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param: NoticeParam | undefined = context.pathInfo.param as NoticeParam;
      if (param !== undefined && param !== null) {
        this.noticeId = param.id;
      }
      // 参数拿到之后再注册监听和生成分享图
      this.shareBridge.register(this.context());
    })
  }
}
