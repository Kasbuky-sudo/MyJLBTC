import { AppColor, AppSize, barZone, StoreKey, titleBarHeight } from '../common/Theme';
import { ScheduleKeys, ScheduleStore } from '../model/ScheduleStore';
import { SMALL_PERIOD_TIMES, todayWeekday } from '../model/ScheduleData';
import { SchoolClient, WeekCourseData } from '../common/SchoolClient';
import { Haptics } from '../common/Haptics';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { MaterialKit } from '../common/Material';

/** 学期总周数（教务课表页口径 22 周） */
const TOTAL_WEEKS: number = 22;

/** 周一到周日表头 */
const WEEKDAY_HEADS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

/** 节次轴每行的"下课时刻"（8 小节，取自 SMALL_PERIOD_TIMES 偶数位） */
const SMALL_ROW_TIMES: string[] = [
  SMALL_PERIOD_TIMES[1], SMALL_PERIOD_TIMES[3], SMALL_PERIOD_TIMES[5], SMALL_PERIOD_TIMES[7],
  SMALL_PERIOD_TIMES[9], SMALL_PERIOD_TIMES[11], SMALL_PERIOD_TIMES[13], SMALL_PERIOD_TIMES[15]
];

/** 单个小节的行高（vp）：轴 / 网格线 / 课程块三方共用，保证纵向对齐 */
const SLOT_H: number = 54;

/** 课程块配色轮转（主题系：紫 / 绿 / 橙 / 蓝紫），按课程名哈希取，同一课程每天同色 */
const COURSE_COLORS: Resource[] = [
  $r('app.color.accent'),
  $r('app.color.brand_green'),
  $r('app.color.warning'),
  $r('app.color.profile_to')
];

/** 课程名 → 稳定配色索引（名字哈希，避免每次渲染变色） */
function courseColorIndex(name: string): number {
  let hash: number = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) % 997;
  }
  return hash % COURSE_COLORS.length;
}

/** 一周里某天某节落着的课（周网格查表用） */
class GridSlot {
  course: WeekCourseData;
  span: number;

  constructor(course: WeekCourseData, span: number) {
    this.course = course;
    this.span = span;
  }
}

/**
 * 课表：周视图网格（左侧节次轴 + 顶部星期条，课程块按 星期×大节 落格）。
 * 数据来自教务系统缓存（schedule.raw 全量条目，按当前教学周过滤，可手动切周次）。
 */
@Component
export struct ScheduleTab {
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StoreKey.SCROLL_Y) scrollY: number = 0;
  @StorageLink(ScheduleKeys.WEEK_COURSES) weekCourses: WeekCourseData[] = [];
  @StorageProp(ScheduleKeys.TODAY_UPDATED) updatedAt: number = 0;
  /** 当前教学周（来自 schedule.meta；周次菜单可切） */
  @StorageLink('scheduleWeek') currentWeek: number = 0;
  @State viewportHeight: number = 0;
  /** 周网格卡片的点光源状态（按下时自身发紫光） */
  @State gridLight: boolean = false;
  /** "现实中的当前教学周"（来自缓存 meta；估算值也存这里），日期换算用 */
  @State realWeek: number = 0;
  /** 表头月份角标随所选周变（比如跨月时 10月 → 11月） */
  @State headerMonth: number = new Date().getMonth() + 1;
  private scroller: Scroller = new Scroller();
  /** 今天星期几（1-7）；网格里高亮这一列 */
  private today: number = todayWeekday();

  aboutToAppear(): void {
    this.scrollY = 0;
    ScheduleStore.restore().then(() => {
      // 没定过周次时，取缓存 meta 里的当前教学周；没有就按日期估一个
      if (this.currentWeek <= 0) {
        loadMetaWeek().then((week: number) => {
          this.realWeek = week > 0 ? week : estimateWeek();
          if (this.currentWeek <= 0) {
            this.currentWeek = this.realWeek;
          }
        });
      } else {
        this.realWeek = this.currentWeek;
      }
    });
  }


  private selectWeek(week: number): void {
    this.currentWeek = week;
    // 表头月份角标跟所选周的周一走
    this.headerMonth = this.mondayOf().getMonth() + 1;
    Haptics.light();
  }

  @Builder
  WeekMenu() {
    Menu() {
      ForEach(this.weekOptions(), (week: number) => {
        MenuItem({
          content: `第 ${week} 周`,
          symbolEndIcon: this.currentWeek === week ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectWeek(week);
          })
      }, (week: number) => `${week}`)
    }
  }

  private weekOptions(): number[] {
    const out: number[] = [];
    for (let w = 1; w <= TOTAL_WEEKS; w++) {
      out.push(w);
    }
    return out;
  }

  /** 所选周 currentWeek 的周一 */
  private mondayOf(): Date {
    const now: Date = new Date();
    const day: number = now.getDay() === 0 ? 7 : now.getDay();
    const realWeek: number = this.realWeek > 0 ? this.realWeek : this.currentWeek;
    const mondayOffset: number = (this.currentWeek - realWeek) * 7;
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() - (day - 1) + mondayOffset);
  }

  /**
   * 第 currentWeek 周、星期 weekday 那天的"日"（表头日期用）。
   * 锚点 = 第 1 周的周一：用今天反推 —— 今天 − (今天星期几−1) 天 = 本周一，
   * 再减 (currentWeek − realWeek) × 7 天回到第 1 周；realWeek 来自缓存 meta（估不出来就当 currentWeek，即退化为"本周"）。
   * currentWeek ≤ 0（还没初始化）时按"本周"显示。
   */
  private dateOf(weekday: number): number {
    const monday: Date = this.mondayOf();
    const target = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + (weekday - 1));
    return target.getDate();
  }

  

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Column().height(titleBarHeight(this.topInset))

        // 顶部：学期 + 周次选择
        Row({ space: 8 }) {
          Text(`第 ${this.currentWeek > 0 ? this.currentWeek : '—'} 周`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.TEXT_PRIMARY)
          Row({ space: 4 }) {
            Text('切换周次')
              .fontSize(12)
              .fontColor(AppColor.TEXT_SECONDARY)
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(11)
              .fontColor([AppColor.TEXT_SECONDARY])
          }
          .height(26)
          .padding({ left: 10, right: 8 })
          .borderRadius(13)
          .backgroundColor(AppColor.CHIP_BG)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .bindMenu(this.WeekMenu(), { placement: Placement.BottomLeft })

          // 非本周时显示「回到本周」
          if (this.currentWeek > 0 && this.realWeek > 0 && this.currentWeek !== this.realWeek) {
            Row({ space: 3 }) {
              SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
                .fontSize(11)
                .fontColor([AppColor.ACCENT])
              Text('回到本周')
                .fontSize(12)
                .fontColor(AppColor.ACCENT)
            }
            .height(26)
            .padding({ left: 10, right: 10 })
            .borderRadius(13)
            .backgroundColor(AppColor.ACCENT_SOFT)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.selectWeek(this.realWeek);
            })
          }

          Blank()

          Text(this.updatedAt > 0 ? ScheduleStore.updatedText(this.updatedAt) : '课表未同步')
            .fontSize(11)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        // 课表更新口径：调课/串课得先过学校那道流程，App 只负责同步学校的最新结果
        Row({ space: 6 }) {
          Text('提示')
            .fontSize(10)
            .fontColor(AppColor.ACCENT)
            .backgroundColor(AppColor.ACCENT_SOFT)
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          Text('课表以学校教务系统为准。老师如需调课 / 串课，须先向学校提出申请并通过审核；学校更新课表后，本应用刷新时即自动同步为最新安排。')
            .fontSize(11)
            .fontColor(AppColor.TEXT_SECONDARY)
            .lineHeight(16)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 4, right: 4 })

        // 周网格卡片
        Column() {
          // 表头：角标 + 一~日（带日期，今天高亮）
          Row() {
            Text(`${this.headerMonth}月`)
              .fontSize(10)
              .fontColor(AppColor.TEXT_SECONDARY)
              .width(40)
              .textAlign(TextAlign.Center)

            ForEach(WEEKDAY_HEADS, (head: string, index: number) => {
              Column({ space: 2 }) {
                Text(head)
                  .fontSize(12)
                  .fontWeight(this.today === index + 1 ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.today === index + 1 ? AppColor.ACCENT : AppColor.TEXT_SECONDARY)
                Text(`${this.dateOf(index + 1)}`)
                  .fontSize(11)
                  .fontColor(this.today === index + 1 ? AppColor.ACCENT : AppColor.TEXT_SECONDARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }, (head: string) => head)
          }
          .width('100%')
          .height(40)
          .padding({ right: 6 })

          Divider().color(AppColor.DIVIDER)

          // 主体：节次轴 + 7 列。8 小节制（学校课表口径）。
          // 行高用固定值 SLOT_H，轴 / 网格线 / 课程块三方共用同一常量，保证对齐；
          // 主体总高 = 8 × SLOT_H（不再 layoutWeight 拉伸，避免量出来的高度和块定位打架）。
          Row() {
            // 左侧节次轴（小节号 + 下课时刻，两行一组：号码在上、结束时间在下）
            Column() {
              ForEach(SMALL_ROW_TIMES, (time: string, index: number) => {
                Column({ space: 1 }) {
                  Text(`${index + 1}`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColor.TEXT_PRIMARY)
                  Text(time)
                    .fontSize(8)
                    .fontColor(AppColor.TEXT_SECONDARY)
                }
                .width(40)
                .height(SLOT_H)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              }, (time: string, index: number) => `${index}_${time}`)
            }
            .width(40)

            ForEach(WEEKDAY_HEADS, (head: string, weekdayIndex: number) => {
              Stack({ alignContent: Alignment.TopStart }) {
                // 底层网格线（8 小节，每行固定高）
                Column() {
                  ForEach(SMALL_ROW_TIMES, (time: string, periodIndex: number) => {
                    Column()
                      .height(SLOT_H)
                      .border({ width: { bottom: 0.5 }, color: AppColor.DIVIDER })
                  }, (time: string, periodIndex: number) => `${weekdayIndex}_line_${periodIndex}`)
                }
                .width('100%')

                // 课程块层：大节 → 小节区间（2n-1 ~ 2n），同一 SLOT_H 换算
                ForEach(this.blocksOf(weekdayIndex + 1), (block: GridSlot) => {
                  Column({ space: 2 }) {
                    Text(block.course.name)
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                      .maxLines(3)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (block.course.place.length > 0) {
                      Text(`@${block.course.place}`)
                        .fontSize(9)
                        .fontColor(Color.White)
                        .opacity(0.9)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    if (block.course.teacher.length > 0) {
                      Text(block.course.teacher)
                        .fontSize(9)
                        .fontColor(Color.White)
                        .opacity(0.8)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    if (block.course.examForm.length > 0) {
                      Text(block.course.examForm)
                        .fontSize(9)
                        .fontColor(Color.White)
                        .opacity(0.7)
                        .maxLines(1)
                    }
                  }
                  .width('100%')
                  .padding(3)
                  .alignItems(HorizontalAlign.Start)
                  .backgroundColor(COURSE_COLORS[courseColorIndex(block.course.name)])
                  .borderRadius(6)
                  .position({
                    x: 1,
                    y: 1 + (block.course.startPeriod - 1) * 2 * SLOT_H
                  })
                  .height(block.span * 2 * SLOT_H - 2)
                }, (block: GridSlot) => `${block.course.name}_${block.course.startPeriod}_${block.course.place}`)
              }
              .layoutWeight(1)
              .height(SLOT_H * 8)
            }, (head: string) => head)
          }
          .width('100%')
        }
        .width('100%')
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        .clip(true)
        // 沉浸光感点光源：平时受光，按下时自身发紫光照亮周围卡片
        .visualEffect(MaterialKit.cardEffectBy(this.gridLight))
        .onTouch((event: TouchEvent) => {
      this.gridLight = event.type === TouchType.Down;
    })

        Column().height(barZone(this.bottomInset))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
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

  /** 某天当周的全部课程块（去重后的起始块列表） */
  private blocksOf(weekday: number): GridSlot[] {
    const out: GridSlot[] = [];
    for (const course of this.weekCourses) {
      if (course.weekday === weekday && course.weeks.indexOf(this.currentWeek) >= 0) {
        out.push(new GridSlot(course, course.endPeriod - course.startPeriod + 1));
      }
    }
    out.sort((a: GridSlot, b: GridSlot) => a.course.startPeriod - b.course.startPeriod);
    return out;
  }
}


/** 从缓存 meta 里取当前教学周（没有返回 0） */
async function loadMetaWeek(): Promise<number> {
  const meta = await SchoolClient.get().cachedScheduleMeta();
  return meta !== undefined ? meta.week : 0;
}

/** 按日期估教学周（9 月第一周为第 1 周的粗略口径；估不出返回 1） */
function estimateWeek(): number {
  const now: Date = new Date();
  const year: number = now.getFullYear();
  const month: number = now.getMonth() + 1;
  // 秋季学期：9 月 1 日所在周为第 1 周；春季学期：3 月 1 日所在周为第 1 周
  const anchor: Date = month >= 2 && month <= 7 ? new Date(year, 2, 1) : new Date(year, 8, 1);
  const diff: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() -
    new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate()).getTime();
  const week: number = Math.floor(diff / (7 * 86400000)) + 1;
  if (week < 1) {
    return 1;
  }
  return week > 22 ? 22 : week;
}
