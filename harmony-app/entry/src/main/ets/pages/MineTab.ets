import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor, AppSize, barZone, StoreKey, titleBarHeight } from '../common/Theme';
import { Haptics } from '../common/Haptics';
import { Appearance, APPEARANCE_LABELS } from '../common/ColorMode';
import { studentProfile } from '../model/CampusData';

const MINE_ENTRIES: string[] = ['关于 MyJLBTC'];
/** 资料页里的一行（学院 / 专业 / 班级 / 学号） */
class InfoRow {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

/** 我的：账号信息 + 外观切换 + 设置入口 + 退出登录 */
@Component
export struct MineTab {
  @StorageLink('profileName') profileName: string = studentProfile.name;
  @StorageLink('profileStudentId') profileId: string = studentProfile.studentId;
  @StorageLink('profileCollege') profileCollege: string = studentProfile.college;
  @StorageLink('profileMajor') profileMajor: string = studentProfile.major;
  @StorageLink('profileClass') profileClass: string = studentProfile.classNo;

  /** 资料行（真实学籍数据；没同步过时退回示例值） */
  private profileRows(): InfoRow[] {
    return [
      new InfoRow('学院', this.profileCollege),
      new InfoRow('专业', this.profileMajor),
      new InfoRow('班级', this.profileClass),
      new InfoRow('学号', this.profileId)
    ];
  }
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StoreKey.SCROLL_Y) scrollY: number = 0;
  @StorageLink('appearanceMode') appearance: number = 0;
  @State viewportHeight: number = 0;
  @State showProfile: boolean = false;
  onLogout: () => void = () => {};
  onOpenAbout: () => void = () => {};
  onOpenProfile: () => void = () => {};

  aboutToAppear(): void {
    this.scrollY = 0;
  }

  private selectAppearance(index: number): void {
    this.appearance = index;
    try {
      Appearance.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, index);
    } catch (err) {
      hilog.error(0x0000, 'MineTab', 'apply appearance failed: %{public}s', JSON.stringify(err));
    }
    Haptics.light();
  }

  @Builder
  AppearanceMenu() {
    Menu() {
      ForEach(APPEARANCE_LABELS, (label: string, index: number) => {
        MenuItem({
          content: label,
          symbolEndIcon: this.appearance === index ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
        })
          .onClick(() => {
            this.selectAppearance(index);
          })
      }, (label: string) => label)
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      hilog.warn(0x0000, 'MineTab', 'toast unavailable');
    }
  }

  /**
   * 学生信息半模态页：从下往上弹出，版式对齐华为账号页
   * （标题 + 右上角关闭、居中大头像、姓名 + 学号、下面一张信息卡）。
   */
  @Builder
  ProfileSheet() {
    Scroll() {
      Column({ space: 8 }) {
        Column() {
          Text(this.profileName.substring(0, 1))
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.ON_BRAND)
        }
        .width(120)
        .height(120)
        .borderRadius(60)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
        })
        .margin({ top: 36 })

        Column({ space: 6 }) {
          Text(this.profileName)
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.TEXT_PRIMARY)
          Text(this.profileId)
            .fontSize(18)
            .fontColor(AppColor.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 18, bottom: 18 })

        Column() {
          ForEach(this.profileRows(), (row: InfoRow, index: number) => {
            Column() {
              Row() {
                Text(row.label)
                  .fontSize(16)
                  .fontColor(AppColor.TEXT_PRIMARY)
                Blank()
                Text(row.value)
                  .fontSize(15)
                  .fontColor(AppColor.TEXT_SECONDARY)
                  .margin({ right: 6 })
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(15)
                  .fontColor([AppColor.TEXT_SECONDARY])
              }
              .width('100%')
              .height(58)
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => {
                Haptics.light();
              })

              if (index < this.profileRows().length - 1) {
                Divider()
                  .color(AppColor.DIVIDER)
                  .margin({ left: 16, right: 16 })
              }
            }
            .width('100%')
          }, (row: InfoRow) => row.label)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)

        // 完整学籍（性别/民族/身份证/联系方式/家庭住址等）在个人信息二级页
        Button() {
          Text('查看完整学籍信息')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.ON_BRAND)
        }
        .width('100%')
        .height(48)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        .backgroundColor(AppColor.CARD)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.98 })
        .margin({ top: 8 })
        .onClick(() => {
          this.showProfile = false;
          Haptics.light();
          this.onOpenProfile();
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 40 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column().height(titleBarHeight(this.topInset))

        Row({ space: 14 }) {
          Column() {
            Text(this.profileName.substring(0, 1))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.ON_BRAND)
          }
          .width(54)
          .height(54)
          .borderRadius(27)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
          })

          Column({ space: 4 }) {
            Text(this.profileName)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.TEXT_PRIMARY)
            Text(`${this.profileMajor} ${this.profileClass}`)
              .fontSize(13)
              .fontColor(AppColor.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([AppColor.TEXT_SECONDARY])
        }
        .width('100%')
        .padding(18)
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.99 })
        .onClick(() => {
          Haptics.light();
          this.onOpenProfile();
        })
        // 学生信息：从下往上弹出的半模态（概览），完整学籍在个人信息二级页
        .bindSheet($$this.showProfile, this.ProfileSheet(), {
          detents: [SheetSize.LARGE],
          showClose: true,
          dragBar: false,
          title: { title: '学生信息' },
          backgroundColor: AppColor.PAGE_BG,
          onDisappear: () => {
            this.showProfile = false;
          },
          // 注册后避免关闭时的反向回弹
          onWillSpringBackWhenDismiss: () => {
          }
        })

        Column() {
          Column() {
            Row() {
              Text('外观')
                .fontSize(15)
                .fontColor(AppColor.TEXT_PRIMARY)
              Blank()
              Text(APPEARANCE_LABELS[this.appearance])
                .fontSize(14)
                .fontColor(AppColor.TEXT_SECONDARY)
                .margin({ right: 6 })
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(15)
                .fontColor([AppColor.TEXT_SECONDARY])
            }
            .width('100%')
            .height(56)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .bindMenu(this.AppearanceMenu(), { placement: Placement.BottomRight })

            Divider()
              .color(AppColor.DIVIDER)
              .margin({ left: 16, right: 16 })
          }
          .width('100%')

          ForEach(MINE_ENTRIES, (label: string, index: number) => {
            Column() {
              Row() {
                Text(label)
                  .fontSize(15)
                  .fontColor(AppColor.TEXT_PRIMARY)
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(15)
                  .fontColor([AppColor.TEXT_SECONDARY])
              }
              .width('100%')
              .height(56)
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => {
                Haptics.light();
                if (label.startsWith('关于')) {
                  this.onOpenAbout();
                  return;
                }
                this.toast(`${label}（演示）`);
              })

              if (index < MINE_ENTRIES.length - 1) {
                Divider()
                  .color(AppColor.DIVIDER)
                  .margin({ left: 16, right: 16 })
              }
            }
            .width('100%')
          }, (label: string) => label)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppColor.CARD)
        .borderRadius(AppSize.CARD_RADIUS_SM)

        Button() {
          Text('退出登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.DANGER)
        }
        .width('100%')
        .height(AppSize.BUTTON_HEIGHT)
        .borderRadius(AppSize.CARD_RADIUS_SM)
        .backgroundColor(AppColor.CARD)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.98 })
        .onClick(() => {
          Haptics.light();
          this.onLogout();
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
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.viewportHeight = newValue.height as number;
    })
  }
}
