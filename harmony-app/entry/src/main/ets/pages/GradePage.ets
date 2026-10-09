import { SymbolGlyphModifier } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppAnim } from '../common/Animation';
import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShareUtil } from '../common/ShareUtil';
import { ShareBridge } from '../common/ShareBridge';
import { ShareButton } from '../components/ShareButton';
import {
  averageOf,
  creditSumOf,
  filterGrades,
  gpaOf,
  GradeRecord,
  gradeRecords,
  gradeYears,
  SEMESTERS,
  semesterLabel,
  termLabel,
  termSemester,
  termYear
} from '../model/CampusData';

/** 成绩配色：分数自动分档，等级制按档位 */
function gradeColor(grade: string): Resource {
  const value: number = Number(grade);
  if (!isNaN(value)) {
    if (value >= 85) {
      return AppColor.GREEN;
    }
    if (value >= 75) {
      return AppColor.ACCENT;
    }
    if (value >= 60) {
      return AppColor.WARNING;
    }
    return AppColor.DANGER;
  }
  if (grade === '优秀' || grade === '良好') {
    return AppColor.GREEN;
  }
  if (grade === '中等') {
    return AppColor.ACCENT;
  }
  if (grade === '及格') {
    return AppColor.WARNING;
  }
  return AppColor.DANGER;
}

/**
 * 成绩查询（二级页）。
 * 标题栏用 NavDestination 自带的：字符串/主副标题形式会自动带系统返回按钮，
 * 主标题放页面名、副标题放当前学年学期，选中项一变副标题就跟着变；
 * 标题栏是官方材质槽位，所以这里直接给 title 的 options 传 systemMaterial（不支持时退化为模糊底）。
 * 路由栈按官方写法用 onReady 里的 context.pathStack，不自己 @Provide。
 */
@Component
export struct GradePage {
  /** 真实数据替换后触发重绘（见 CampusData.replaceGrades/replaceExams） */
  @StorageLink('dataEpoch') dataEpoch: number = 0;
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;
  /** 概览卡/列表卡的点光源状态（按下时自身发紫光） */
  @State statLight: boolean = false;
  @State listLight: boolean = false;
  private scroller: Scroller = new Scroller();
  private shareData: systemShare.SharedData | undefined = undefined;
  private shareBridge: ShareBridge = new ShareBridge(async () => {
    await this.prepareShare();
    return this.shareData;
  }, () => {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '分享内容生成失败，请重试', duration: 1600 });
    } catch (err) {
      hilog.warn(0x0000, 'GradePage', 'toast unavailable');
    }
  });
  private years: string[] = [];
  @State selectedYear: string = '';
  @State selectedSemester: string = '';

  aboutToAppear(): void {
    // 真实数据可能在启动后才替换进来，这里重新取；
    // 默认选中"最新一条成绩所在的学年学期"（有数据的学期），不是学年列表第一个+第1学期
    this.years = gradeYears();
    const latestTerm: string = gradeRecords.length > 0 ? gradeRecords[0].term : '';
    this.selectedYear = latestTerm.length > 0 ? termYear(latestTerm)
      : (this.years.length > 0 ? this.years[0] : '');
    this.selectedSemester = latestTerm.length > 0 ? termSemester(latestTerm) : '1';
  }

  private records(): GradeRecord[] {
    return filterGrades(this.selectedYear, this.selectedSemester);
  }

  private selectYear(year: string): void {
    this.selectedYear = year;
    Haptics.light();
  }

  private selectSemester(semester: string): void {
    this.selectedSemester = semester;
    Haptics.light();
  }

  @Builder
  YearMenu() {
    Menu() {
      ForEach(this.years, (year: string) => {
        MenuItem({
          content: `${year} 学年`,
          symbolEndIcon: this.selectedYear === year ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectYear(year);
          })
      }, (year: string) => year)
    }
  }

  @Builder
  SemesterMenu() {
    Menu() {
      ForEach(SEMESTERS, (semester: string) => {
        MenuItem({
          content: semesterLabel(semester),
          symbolEndIcon: this.selectedSemester === semester
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectSemester(semester);
          })
      }, (semester: string) => semester)
    }
  }

  @Builder
  FilterBar() {
    Row({ space: 10 }) {
      Row({ space: 4 }) {
        Text(`${this.selectedYear} 学年`)
          .fontSize(14)
          .fontColor(AppColor.TEXT_PRIMARY)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([AppColor.TEXT_SECONDARY])
      }
      .height(34)
      .padding({ left: 14, right: 12 })
      .borderRadius(17)
      .backgroundColor(AppColor.CHIP_BG)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .bindMenu(this.YearMenu(), { placement: Placement.BottomLeft })

      Row({ space: 4 }) {
        Text(semesterLabel(this.selectedSemester))
          .fontSize(14)
          .fontColor(AppColor.TEXT_PRIMARY)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([AppColor.TEXT_SECONDARY])
      }
      .height(34)
      .padding({ left: 14, right: 12 })
      .borderRadius(17)
      .backgroundColor(AppColor.CHIP_BG)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .bindMenu(this.SemesterMenu(), { placement: Placement.BottomLeft })

      Blank()
    }
    .width('100%')
  }

  @Builder
  GradeRow(record: GradeRecord, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(record.name)
              .fontSize(15)
              .fontColor(AppColor.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            // 补考 / 缓考补考 / 重修：教务按同一门课另记一行，靠 sfbk、xdxz 区分
            if (record.tag.length > 0) {
              Text(record.tag)
                .fontSize(10)
                .fontColor(AppColor.ACCENT)
                .backgroundColor(AppColor.ACCENT_SOFT)
                .borderRadius(4)
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(record.code)
            .fontSize(12)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 绩点 / 学分（教务口径：xfjd / hdxf）
        Column({ space: 4 }) {
          Text(record.gradePoint.length > 0 ? record.gradePoint : '—')
            .fontSize(13)
            .fontColor(AppColor.TEXT_SECONDARY)
          Text('绩点')
            .fontSize(10)
            .fontColor(AppColor.PLACEHOLDER)
        }
        .width(44)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(record.credit.length > 0 ? record.credit : '—')
            .fontSize(13)
            .fontColor(AppColor.TEXT_SECONDARY)
          Text('学分')
            .fontSize(10)
            .fontColor(AppColor.PLACEHOLDER)
        }
        .width(44)
        .alignItems(HorizontalAlign.Center)

        Text(record.grade)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(gradeColor(record.grade))
          .width(52)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  /**
   * 二级页导航栏：标准导航条版式（返回箭头 + 主标题 + 副标题），
   * 高度 = 状态栏 + 60，材质挂在栏内组件上 —— 这样玻璃能盖住状态栏那一段（沉浸），
   * 标题又落在状态栏下方。系统标题栏做不到两全：不加内边距标题会压状态栏，
   * 加了内边距状态栏那条就露不出玻璃（真机对比过）。
   */
  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToDisappear(): void {
    this.shareBridge.unregister();
  }

  /** 成绩内容截成图片，组装分享数据（碰一碰/隔空要用，进页面就准备好） */
  private async prepareShare(): Promise<void> {
    try {
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot()
        .get('gradeContent', { scale: 2, waitUntilRenderFinished: true });
      const uri: string = await ShareUtil.buildImageFileUri(this.context(), pixelMap,
        `grade_${this.selectedYear}_${this.selectedSemester}_${Date.now()}.png`);
      const term: string = termLabel(this.selectedYear, this.selectedSemester);
      this.shareData = ShareUtil.buildImageData('成绩查询',
        `来自 MyJLBTC App · ${term}`, uri, this.gradeText(term));
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(0x0000, 'GradePage', 'build share image failed: %{public}d %{public}s',
        error.code, error.message);
    }
  }

  /** 纯文本分享的内容：**全文**（学期 + 每门课一行 + 统计 + 落款） */
  private gradeText(term: string): string {
    const records: GradeRecord[] = this.records();
    let body: string = '';
    for (let i = 0; i < records.length; i++) {
      const point: string = records[i].gradePoint.length > 0 ? `（绩点 ${records[i].gradePoint} · ${records[i].credit} 学分）` : '';
      body += `${records[i].name}：${records[i].grade}${point}\n`;
    }
    const head: string = `【成绩查询】${term}\n共 ${records.length} 门课程 · 平均分 ${averageOf(records)} · 绩点 ${gpaOf(records)}`;
    return `${head}\n\n${body}\n来自 MyJLBTC App`;
  }

  /** 分享前现截图：避开入场动画（截早了列表是空的），同时保证筛选改动后是最新内容 */
  private showSharePanel(): void {
    this.prepareShare().then(() => {
      const fresh: systemShare.SharedData | undefined = this.shareData;
      if (fresh !== undefined) {
        ShareUtil.showSystemShare(this.context(), fresh);
      } else {
        try {
          this.getUIContext().getPromptAction().showToast({ message: '分享内容生成失败，请重试', duration: 1600 });
        } catch (err) {
          hilog.warn(0x0000, 'GradePage', 'toast unavailable');
        }
      }
    });
  }

  @Builder
  NavigationBar() {
    Row({ space: 2 }) {
      // 官方返回键样式：圆形图标按钮 + 沉浸材质（系统绘制时就是这个长相）
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
        Text('成绩查询')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
        Text(termLabel(this.selectedYear, this.selectedSemester))
          .fontSize(13)
          .fontColor(AppColor.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      ShareButton({
        onShare: () => {
          this.showSharePanel();
        }
      })
    }
    .width('100%')
    .height('100%')
    // 左内边距 16vp：返回键别贴边（原来 8vp 太靠边了）
    .padding({ left: 16, right: 16, top: this.topInset, bottom: 8 })
    .alignItems(VerticalAlign.Bottom)
    // 有材质时别叠自己的底色/模糊，否则糊上糊
    .backgroundColor(MaterialKit.supported() ? Color.Transparent : AppColor.TITLE_BAR_BG)
    .backdropBlur(MaterialKit.supported() ? 0 : 24)
    .systemMaterial(MaterialKit.navigationBar())
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          // STACK 模式下内容顶到最上面，这里让出自绘导航栏的高度（状态栏 + 60）
          Column().height(titleBarHeight(this.topInset))

          // 这块就是分享出去的长图（id 给 componentSnapshot 用）
          Column({ space: 12 }) {
          this.FilterBar()

          // 概览：统计口径随筛选变化
          // 注意：这里不能用带参数的 @Builder（传值参数不会随状态刷新），必须内联
          Row() {
            Column({ space: 4 }) {
              Text(`${this.records().length}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('课程数')
                .fontSize(12)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .layoutWeight(1)

            Divider().vertical(true).height(28).color(AppColor.DIVIDER)

            Column({ space: 4 }) {
              Text(`${creditSumOf(this.records())}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('学分')
                .fontSize(12)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .layoutWeight(1)

            Divider().vertical(true).height(28).color(AppColor.DIVIDER)

            Column({ space: 4 }) {
              Text(`${gpaOf(this.records())}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('绩点')
                .fontSize(12)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .layoutWeight(1)

            Divider().vertical(true).height(28).color(AppColor.DIVIDER)

            Column({ space: 4 }) {
              Text(`${averageOf(this.records())}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('平均分')
                .fontSize(12)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          // 沉浸光感点光源：平时受光，按下时自身发紫光照亮周围卡片
          .visualEffect(MaterialKit.cardEffectBy(this.statLight))
          .onTouch((event: TouchEvent) => {
      this.statLight = event.type === TouchType.Down;
    })

          if (this.records().length === 0) {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.doc_text'))
                .fontSize(34)
                .fontColor([AppColor.TEXT_SECONDARY])
              Text('该学期暂无成绩数据')
                .fontSize(15)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('换个学年或学期看看')
                .fontSize(13)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .backgroundColor(AppColor.CARD)
            .borderRadius(AppSize.CARD_RADIUS_SM)
          } else {
            Column() {
              Row() {
                Text(termLabel(this.selectedYear, this.selectedSemester))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColor.TEXT_PRIMARY)
                Blank()
                Text(`${this.records().length} 门`)
                  .fontSize(13)
                  .fontColor(AppColor.TEXT_SECONDARY)
              }
              .width('100%')
              .height(50)
              .padding({ left: 16, right: 16 })

              ForEach(this.records(), (record: GradeRecord, index: number) => {
                this.GradeRow(record, index === this.records().length - 1)
              }, (record: GradeRecord) => record.code)
            }
            .width('100%')
            .padding({ top: 4, bottom: 6 })
            .backgroundColor(AppColor.CARD)
            .borderRadius(AppSize.CARD_RADIUS_SM)
            .visualEffect(MaterialKit.cardEffectBy(this.listLight))
            .onTouch((event: TouchEvent) => {
      this.listLight = event.type === TouchType.Down;
    })
            .transition(AppAnim.enter(0))
          }

            // 分享出去的长图落款（在截图区域内）
            Text('来自 MyJLBTC App')
              .fontSize(12)
              .fontColor(AppColor.PLACEHOLDER)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 20 })
          }
          .id('gradeContent')
          .width('100%')
          .padding({ left: 20, right: 20, top: 12, bottom: 24 })
          .backgroundColor(AppColor.PAGE_BG)
          .alignItems(HorizontalAlign.Start)

          Column().height(this.bottomInset + 24)
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
    // 自绘导航栏（高度含状态栏），系统返回键隐藏、用栏内的返回箭头；
    // title 的 options 只设 barStyle STACK，别加 backgroundColor / backgroundBlurStyle（会盖掉材质）
    .title({ builder: this.NavigationBar(), height: titleBarHeight(this.topInset) },
      { barStyle: BarStyle.STACK })
    .hideBackButton(true)
    .backgroundColor(AppColor.PAGE_BG)
    .onReady((context: NavDestinationContext) => {
      // 官方写法：路由栈从 onReady 上下文取
      this.pathStack = context.pathStack;
      this.shareBridge.register(this.context());
    })
  }
}
