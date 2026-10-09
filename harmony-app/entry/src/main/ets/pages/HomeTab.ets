import { AppAnim } from '../common/Animation';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor, AppSize, barZone, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import {
  CourseItem,
  FunctionEntry,
  functionEntries,
  studentProfile
} from '../model/CampusData';
import { ScheduleCourse, todayWeekday, weekdayLabel } from '../model/ScheduleData';
import { ScheduleKeys } from '../model/ScheduleStore';
import { latestNotice } from '../model/NoticeData';

/** 首页：公告条 + 个人资料卡 + 学分统计 + 常用功能 + 今日课程 */
@Component
export struct HomeTab {
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StoreKey.SCROLL_Y) scrollY: number = 0;
  @StorageLink(ScheduleKeys.TODAY_COURSES) realCourses: ScheduleCourse[] = [];
  @StorageProp(ScheduleKeys.TODAY_UPDATED) coursesUpdatedAt: number = 0;
  onOpenGrades: () => void = () => {};
  onOpenExams: () => void = () => {};
  onOpenNotice: () => void = () => {};
  /** 首页「刷新」：交给主界面统一处理（会话失效时会先走登录/网关） */
  onRefreshData: () => void = () => {};
  @StorageLink('dataRefreshAt') lastRefreshAt: number = 0;
  @StorageLink('dataRefreshState') @Watch('onRefreshState') refreshState: string = 'idle';
  @StorageLink('dataRequiredCredits') requiredCredits: string = '--';
  @StorageLink('profileName') profileName: string = studentProfile.name;
  @StorageLink('profileStudentId') profileId: string = studentProfile.studentId;
  @StorageLink('profileCollege') profileCollege: string = studentProfile.college;
  @StorageLink('profileMajor') profileMajor: string = studentProfile.major;
  @StorageLink('profileClass') profileClass: string = studentProfile.classNo;
  @StorageLink('dataCredits') credits: string = '--';
  @StorageLink('dataCourseCount') courseCount: string = '--';
  @State viewportHeight: number = 0;
  @State refreshingKey: string = '';
  @State profileLight: boolean = false;
  @State noticeLight: boolean = false;
  @State miniLight: boolean = false;
  @State functionLight: boolean = false;
  @State courseLight: boolean = false;
  @State creditLight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollY = 0;
  }

  /** 今日课程：优先真实数据（教务同步的缓存），没有就空状态 */
  private todayRows(): CourseItem[] {
    return this.realCourses.map((course: ScheduleCourse) =>
      new CourseItem(course.name, course.teacher, course.timeText, course.place));
  }

  private syncScroll(): void {
    const y: number = this.scroller.currentOffset().yOffset;
    const clamped: number = Math.min(140, Math.max(0, y));
    if (clamped !== this.scrollY) {
      this.scrollY = clamped;
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      hilog.warn(0x0000, 'HomeTab', 'toast unavailable');
    }
  }

  /** 刷新：由主界面统一执行（会话过期会先走登录/网关），这里只做状态与提示 */
  private refreshCard(key: string): void {
    if (this.refreshingKey.length > 0) {
      return;
    }
    this.refreshingKey = key;
    Haptics.light();
    this.onRefreshData();
  }

  private onRefreshState(): void {
    if (this.refreshState === 'busy') {
      return;
    }
    this.finishRefresh(this.refreshState === 'ok');
  }

  /** 主界面刷新结束时调用：收尾状态 + 提示 */
  finishRefresh(ok: boolean): void {
    this.refreshingKey = '';
    this.toast(ok ? '数据已更新' : '刷新失败：需要重新登录或网络异常');
  }

  @Builder
  ProfileCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 装饰圆
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#1AFFFFFF')
        .translate({ x: 46, y: -46 })
      Column()
        .width(90)
        .height(90)
        .borderRadius(45)
        .backgroundColor('#14FFFFFF')
        .translate({ x: -120, y: 96 })

      Column({ space: 6 }) {
        Row({ space: 10 }) {
          Text(this.profileName)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.ON_BRAND)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.profileCollege)
            .fontSize(11)
            .fontColor(AppColor.ON_BRAND)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#2EFFFFFF')
            .borderRadius(10)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.profileMajor)
          .fontSize(13.5)
          .fontColor('#E6FFFFFF')
        Text(this.profileClass)
          .fontSize(13.5)
          .fontColor('#E6FFFFFF')
        Text(this.profileId)
          .fontSize(13)
          .fontColor('#B3FFFFFF')
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(158)
    .borderRadius(AppSize.CARD_RADIUS)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
    })
    // 沉浸光感点光源：平时受光，按下时自身发紫光照亮周围卡片
    .visualEffect(MaterialKit.cardEffectBy(this.profileLight))
    .onTouch((event: TouchEvent) => {
      this.profileLight = event.type === TouchType.Down;
    })
  }

  @Builder
  NoticeBar() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.bell'))
        .fontSize(16)
        .fontColor([AppColor.ACCENT])
      Text(latestNotice().title)
        .fontSize(13)
        .fontColor(AppColor.TEXT_META)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([AppColor.TEXT_SECONDARY])
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 14 })
    .backgroundColor(AppColor.CARD)
    .borderRadius(16)
    .visualEffect(MaterialKit.cardEffectBy(this.noticeLight))
    .onTouch((event: TouchEvent) => {
      this.noticeLight = event.type === TouchType.Down;
    })
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.99 })
    .onClick(() => {
      Haptics.light();
      this.onOpenNotice();
    })
  }

  @Builder
  FunctionRow(entry: FunctionEntry, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph(entry.icon)
            .fontSize(19)
            .fontColor([AppColor.ACCENT])
        }
        .width(38)
        .height(38)
        .borderRadius(10)
        .backgroundColor(AppColor.ACCENT_SOFT)
        .justifyContent(FlexAlign.Center)

        Column({ space: 2 }) {
          Text(entry.label)
            .fontSize(15)
            .fontColor(AppColor.TEXT_PRIMARY)
          Text(entry.desc)
            .fontSize(12)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppColor.TEXT_SECONDARY])
      }
      .width('100%')
      .height(62)
      .padding({ left: 16, right: 14 })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 66 })
      }
    }
    .width('100%')
    .onClick(() => {
      Haptics.light();
      if (entry.key === 'grade') {
        this.onOpenGrades();
      } else {
        this.onOpenExams();
      }
    })
  }

  @Builder
  DataCard() {
    Row() {
      Column({ space: 4 }) {
        Text('数据')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.TEXT_PRIMARY)
        Text(`上次刷新：${this.refreshAgoText()}`)
          .fontSize(12)
          .fontColor(AppColor.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.refreshingKey === 'all') {
        // 刷新中：按钮内放华为风格的加载转圈（LoadingProgress），完成后换回文字
        Button() {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(Color.White)
        }
        .width(88)
        .height(38)
        .backgroundColor(AppColor.ACCENT)
        .enabled(false)
      } else {
        Button('刷新')
          .fontSize(15)
          .fontColor(Color.White)
          .height(38)
          .padding({ left: 22, right: 22 })
          .backgroundColor(AppColor.ACCENT)
          .onClick(() => {
            Haptics.light();
            // 先切到加载态再触发刷新（直接调 onRefreshData 不经过状态，按钮不会变）
            this.refreshingKey = 'all';
            this.onRefreshData();
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(AppColor.CARD)
    .borderRadius(AppSize.CARD_RADIUS_SM)
    .visualEffect(MaterialKit.cardEffectBy(this.miniLight))
    .onTouch((event: TouchEvent) => {
      this.miniLight = event.type === TouchType.Down;
    })
  }

  /** 上次刷新时间的相对文案 */
  private refreshAgoText(): string {
    if (this.lastRefreshAt <= 0) {
      return '暂无数据';
    }
    const diff: number = Date.now() - this.lastRefreshAt;
    const minutes: number = Math.floor(diff / 60000);
    if (minutes < 1) {
      return '刚刚';
    }
    if (minutes < 60) {
      return `${minutes}分钟前`;
    }
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) {
      return `${hours}小时前`;
    }
    return `${Math.floor(hours / 24)}天前`;
  }

  @Builder
  CourseRow(course: CourseItem, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column()
          .width(3)
          .height(34)
          .borderRadius(2)
          .backgroundColor(AppColor.ACCENT)
        Column({ space: 3 }) {
          Text(course.name)
            .fontSize(15)
            .fontColor(AppColor.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${course.timeText} · ${course.teacher} · ${course.place}`)
            .fontSize(12)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 31, right: 16 })
      }
    }
    .width('100%')
  }

  

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Column().height(titleBarHeight(this.topInset))

        this.NoticeBar()

        this.ProfileCard()

        this.DataCard()

        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text('已修学分')
              .fontSize(16)
              .fontColor(AppColor.TEXT_PRIMARY)
            Text(this.credits)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.GREEN)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          // 沉浸光感点光源：平时受光，按下时自身发紫光照亮周围卡片
          .visualEffect(MaterialKit.cardEffectBy(this.creditLight))
          .onTouch((event: TouchEvent) => {
      this.creditLight = event.type === TouchType.Down;
    })

          Column({ space: 6 }) {
            Text('应修学分')
              .fontSize(16)
              .fontColor(AppColor.TEXT_PRIMARY)
            Text(this.requiredCredits)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.GREEN)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          .visualEffect(MaterialKit.cardEffectBy(this.creditLight))
          .onTouch((event: TouchEvent) => {
      this.creditLight = event.type === TouchType.Down;
    })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column() {
          Text('常用功能')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.TEXT_PRIMARY)
            .padding({ left: 16, top: 16, bottom: 4 })

          ForEach(functionEntries, (entry: FunctionEntry, index: number) => {
            this.FunctionRow(entry, index === functionEntries.length - 1)
          }, (entry: FunctionEntry) => entry.key)
        }
        .width('100%')
        .padding({ bottom: 6 })
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        // 沉浸光感点光：平时受光，按下时自身发紫光
        .visualEffect(MaterialKit.cardEffectBy(this.functionLight))
        .onTouch((event: TouchEvent) => {
      this.functionLight = event.type === TouchType.Down;
    })

        Column() {
          Row() {
            Text('今日课程')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.TEXT_PRIMARY)
            Blank()
            Text(weekdayLabel(todayWeekday()))
              .fontSize(13)
              .fontColor(AppColor.TEXT_SECONDARY)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 6 })

          if (this.todayRows().length === 0) {
            Text(this.coursesUpdatedAt > 0 ? '今天没有课' : '课表未同步：教务系统需要校园网关验证')
              .fontSize(13)
              .fontColor(AppColor.TEXT_SECONDARY)
              .width('100%')
              .padding({ left: 16, right: 16, top: 4, bottom: 18 })
          } else {
            ForEach(this.todayRows(), (course: CourseItem, index: number) => {
              this.CourseRow(course, index === this.todayRows().length - 1)
            }, (course: CourseItem, index: number) => `${index}_${course.name}_${course.timeText}`)
          }
        }
        .width('100%')
        .padding({ bottom: 6 })
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        // 沉浸光感点光：平时受光，按下时自身发紫光
        .visualEffect(MaterialKit.cardEffectBy(this.courseLight))
        .onTouch((event: TouchEvent) => {
      this.courseLight = event.type === TouchType.Down;
    })

        Column().height(barZone(this.bottomInset))
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .constraintSize({ minHeight: this.viewportHeight })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll(() => {
      this.syncScroll();
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.viewportHeight = newValue.height as number;
    })
  }
}
