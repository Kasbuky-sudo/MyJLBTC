import { SymbolGlyphModifier } from '@kit.ArkUI';
import { AppAnim } from '../common/Animation';
import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import {
  ALL_BATCHES,
  daysUntilExam,
  examBatches,
  ExamRecord,
  examTerms,
  filterExams,
  termLabel,
  termSemester,
  termYear
} from '../model/CampusData';
import { SchoolClient } from '../common/SchoolClient';

/** 课程名配色：和学校页面一样轮转（绿 / 琥珀 / 橙红） */
function courseColor(index: number): Resource {
  const mod: number = index % 3;
  if (mod === 0) {
    return AppColor.GREEN;
  }
  if (mod === 1) {
    return AppColor.WARNING;
  }
  return AppColor.DANGER;
}

/** 距离考试的状态文案与配色（负数=已考完） */
function examStatusColor(days: number): Resource {
  if (isNaN(days) || days < 0) {
    return AppColor.TEXT_SECONDARY;
  }
  if (days === 0) {
    return AppColor.DANGER;
  }
  if (days <= 3) {
    return AppColor.WARNING;
  }
  return AppColor.ACCENT;
}

function examStatusText(days: number): string {
  if (isNaN(days)) {
    return '';
  }
  if (days < 0) {
    return '已结束';
  }
  if (days === 0) {
    return '今天';
  }
  return `还有 ${days} 天`;
}

/**
 * 信息行用 @Component（@Prop 会随筛选刷新；@Builder 的传值参数不会，踩过）
 */
@Component
struct ExamInfoRow {
  @Prop label: string;
  @Prop value: string;

  

  build() {
    Row() {
      Text(`${this.label}：`)
        .fontSize(14)
        .fontColor(AppColor.TEXT_SECONDARY)
        .width(92)
      Text(this.value.length > 0 ? this.value : '—')
        .fontSize(14)
        .fontColor(this.value.length > 0 ? AppColor.TEXT_PRIMARY : AppColor.TEXT_SECONDARY)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}

/**
 * 考试卡片：用 @Component 而不是 @Builder —— 点光源状态是它自己的 @State，
 * @Builder 的传值参数不随状态刷新（踩过），组件内 state 才可靠。
 */
@Component
struct ExamCard {
  @Prop record: ExamRecord;
  @Prop colorIndex: number;
  @State lightPressed: boolean = false;

  build() {
    Column() {
      Row() {
        Text(this.record.course)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(courseColor(this.colorIndex))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(examStatusText(daysUntilExam(this.record.time)))
          .fontSize(12)
          .fontColor(examStatusColor(daysUntilExam(this.record.time)))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(AppColor.CHIP_BG)
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColor.DIVIDER)
        .margin({ left: 16, right: 16 })

      Column({ space: 10 }) {
        ExamInfoRow({ label: '考试时间', value: this.record.time })
        ExamInfoRow({ label: '考试地址', value: this.record.place })
        ExamInfoRow({ label: '考试批次', value: this.record.batch })
        ExamInfoRow({ label: '考场座位号', value: this.record.seat })
        ExamInfoRow({ label: '考试方式', value: this.record.method })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    }
    .width('100%')
    .backgroundColor(AppColor.CARD)
    .borderRadius(AppSize.CARD_RADIUS_SM)
    // 沉浸光感点光：平时受光，按下时自身发紫光
    .visualEffect(MaterialKit.cardEffectBy(this.lightPressed))
    .onTouch((event: TouchEvent) => {
      this.lightPressed = event.type === TouchType.Down;
    })
  }
}

/**
 * 考试安排（二级页）：学年学期 + 批次筛选，下面按考试逐张卡片。
 * 卡片接 HDS 点光（平时受光、按下变紫色光源），和首页卡片一套。
 */
@Component
export struct ExamPage {
  /** 真实数据替换后触发重绘（见 CampusData.replaceGrades/replaceExams） */
  @StorageLink('dataEpoch') dataEpoch: number = 0;
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;
  private scroller: Scroller = new Scroller();
  private terms: string[] = [];
  @State selectedTerm: string = '';

  aboutToAppear(): void {
    // 与 GradePage 同理：真实数据可能在启动后才替换进来；
    // 没有任何考试数据时兜底到当前学期（学期选择器至少有这一项可选）
    this.terms = examTerms();
    if (this.terms.length > 0) {
      this.selectedTerm = this.terms[0];
    } else {
      this.selectedTerm = SchoolClient.currentTerm();
      this.terms = [this.selectedTerm];
    }
  }
  @State selectedBatch: string = ALL_BATCHES;

  private exams(): ExamRecord[] {
    return filterExams(this.selectedTerm, this.selectedBatch);
  }

  /** 批次胶囊只显示批次名（去掉学期前缀，否则太长） */
  private batchLabel(): string {
    if (this.selectedBatch === ALL_BATCHES) {
      return ALL_BATCHES;
    }
    if (this.selectedBatch.startsWith(this.selectedTerm)) {
      return this.selectedBatch.substring(this.selectedTerm.length);
    }
    return this.selectedBatch;
  }

  private selectTerm(term: string): void {
    this.selectedTerm = term;
    this.selectedBatch = ALL_BATCHES;
    Haptics.light();
  }

  private selectBatch(batch: string): void {
    this.selectedBatch = batch;
    Haptics.light();
  }

  @Builder
  TermMenu() {
    Menu() {
      ForEach(this.terms, (term: string) => {
        MenuItem({
          content: `${term}学期`,
          symbolEndIcon: this.selectedTerm === term ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectTerm(term);
          })
      }, (term: string) => term)
    }
  }

  @Builder
  BatchMenu() {
    Menu() {
      ForEach(examBatches(this.selectedTerm), (batch: string) => {
        MenuItem({
          content: batch,
          symbolEndIcon: this.selectedBatch === batch ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectBatch(batch);
          })
      }, (batch: string) => batch)
    }
  }

  /** 导航栏：和成绩查询页同一套（自绘标准版式 + 圆形玻璃返回键 + 材质） */
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
        Text('考试安排')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
        Text(termLabel(termYear(this.selectedTerm), termSemester(this.selectedTerm)))
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

  @Builder
  FilterBar() {
    Row({ space: 10 }) {
      Row({ space: 4 }) {
        Text(`${this.selectedTerm}学期`)
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
      .bindMenu(this.TermMenu(), { placement: Placement.BottomLeft })

      Row({ space: 4 }) {
        Text(this.batchLabel())
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
      .bindMenu(this.BatchMenu(), { placement: Placement.BottomLeft })

      Blank()

      Text(`${this.exams().length} 场`)
        .fontSize(13)
        .fontColor(AppColor.TEXT_SECONDARY)
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          this.FilterBar()

          if (this.exams().length === 0) {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(34)
                .fontColor([AppColor.TEXT_SECONDARY])
              Text('该学期暂无考试安排')
                .fontSize(15)
                .fontColor(AppColor.TEXT_PRIMARY)
              Text('学校还没排考，或你的名下暂无考试')
                .fontSize(13)
                .fontColor(AppColor.TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .backgroundColor(AppColor.CARD)
            .borderRadius(AppSize.CARD_RADIUS_SM)
          } else {
            ForEach(this.exams(), (record: ExamRecord, index: number) => {
              ExamCard({ record: record, colorIndex: index })
                .transition(AppAnim.enter(index))
            }, (record: ExamRecord) => `${record.course}_${record.time}`)
          }

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
