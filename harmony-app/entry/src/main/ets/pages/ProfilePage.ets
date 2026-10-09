import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor, AppSize, StoreKey, titleBarHeight } from '../common/Theme';
import { MaterialKit } from '../common/Material';
import { Haptics } from '../common/Haptics';
import {
  KEY_PROFILE_ADMISSION_NO,
  KEY_PROFILE_ADDR,
  KEY_PROFILE_BIRTH,
  KEY_PROFILE_CLASS,
  KEY_PROFILE_CLASSSIZE,
  KEY_PROFILE_COLLEGE,
  KEY_PROFILE_DURATION,
  KEY_PROFILE_EMAIL,
  KEY_PROFILE_ENROLL,
  KEY_PROFILE_EXAMNO,
  KEY_PROFILE_GRADUATE_AT,
  KEY_PROFILE_HOMEPHONE,
  KEY_PROFILE_ID,
  KEY_PROFILE_IDCARD,
  KEY_PROFILE_NAME,
  KEY_PROFILE_NATION,
  KEY_PROFILE_PHONE,
  KEY_PROFILE_SEX,
  KEY_PROFILE_STATUS,
  KEY_PROFILE_QQ,
  KEY_PROFILE_WECHAT,
  KEY_PROFILE_CAMPUS,
  KEY_PROFILE_MAJOR,
  KEY_PROFILE_MIDDLE_SCHOOL
} from '../model/CampusSync';
import { studentProfile } from '../model/CampusData';

const DOMAIN: number = 0x0000;
const TAG: string = 'ProfilePage';

/** 信息卡里的一行 */
class InfoRow {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

/**
 * 个人信息（二级页）：学籍全部字段，按"基本信息 / 学业信息 / 联系方式 / 家庭与来源"分组。
 * 数据源是 AppStorage 的 profile* 键（CampusProfile.publish 从学籍接口缓存发布），
 * 没同步过时用示例值兜底，显示"待同步"占位。
 */
@Component
export struct ProfilePage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp(StoreKey.TOP_INSET) topInset: number = 0;
  @StorageProp(StoreKey.BOTTOM_INSET) bottomInset: number = 0;
  @State viewportHeight: number = 0;

  @StorageLink(KEY_PROFILE_NAME) name: string = studentProfile.name;
  @StorageLink(KEY_PROFILE_ID) studentId: string = studentProfile.studentId;
  @StorageLink(KEY_PROFILE_COLLEGE) college: string = studentProfile.college;
  @StorageLink(KEY_PROFILE_MAJOR) major: string = studentProfile.major;
  @StorageLink(KEY_PROFILE_CLASS) className: string = studentProfile.classNo;
  @StorageLink(KEY_PROFILE_SEX) sex: string = '';
  @StorageLink(KEY_PROFILE_NATION) nation: string = '';
  @StorageLink(KEY_PROFILE_BIRTH) birth: string = '';
  @StorageLink(KEY_PROFILE_IDCARD) idCard: string = '';
  @StorageLink(KEY_PROFILE_PHONE) phone: string = '';
  @StorageLink(KEY_PROFILE_EMAIL) email: string = '';
  @StorageLink(KEY_PROFILE_QQ) qq: string = '';
  @StorageLink(KEY_PROFILE_WECHAT) wechat: string = '';
  @StorageLink(KEY_PROFILE_CAMPUS) campus: string = '';
  @StorageLink(KEY_PROFILE_DURATION) duration: string = '';
  @StorageLink(KEY_PROFILE_ENROLL) enrollYear: string = '';
  @StorageLink(KEY_PROFILE_STATUS) status: string = '';
  @StorageLink(KEY_PROFILE_CLASSSIZE) classSize: string = '';
  @StorageLink(KEY_PROFILE_ADDR) homeAddr: string = '';
  @StorageLink(KEY_PROFILE_HOMEPHONE) homePhone: string = '';
  @StorageLink(KEY_PROFILE_MIDDLE_SCHOOL) middleSchool: string = '';
  @StorageLink(KEY_PROFILE_EXAMNO) examNo: string = '';
  @StorageLink(KEY_PROFILE_ADMISSION_NO) admissionNo: string = '';
  @StorageLink(KEY_PROFILE_GRADUATE_AT) graduateAt: string = '';

  /** 长文本（住址）默认收缩，点击展开 */
  @State addrExpanded: boolean = false;

  private basicRows(): InfoRow[] {
    return [
      new InfoRow('姓名', this.name),
      new InfoRow('学号', this.studentId),
      new InfoRow('性别', this.sex),
      new InfoRow('民族', this.nation),
      new InfoRow('出生日期', this.birth),
      new InfoRow('身份证号', this.maskIdCard(this.idCard))
    ];
  }

  private studyRows(): InfoRow[] {
    return [
      new InfoRow('学籍状态', this.status),
      new InfoRow('学院', this.college),
      new InfoRow('专业', this.major),
      new InfoRow('班级', this.className),
      new InfoRow('班级人数', this.classSize),
      new InfoRow('校区', this.campus),
      new InfoRow('学制', this.duration),
      new InfoRow('入学年级', this.enrollYear),
      new InfoRow('预计毕业', this.graduateAt)
    ];
  }

  private contactRows(): InfoRow[] {
    return [
      new InfoRow('手机号', this.phone),
      new InfoRow('邮箱', this.email),
      new InfoRow('QQ', this.qq),
      new InfoRow('微信', this.wechat)
    ];
  }

  private originRows(): InfoRow[] {
    return [
      new InfoRow('家庭住址', this.homeAddr),
      new InfoRow('家庭电话', this.homePhone),
      new InfoRow('毕业中学', this.middleSchool),
      new InfoRow('考生号', this.examNo),
      new InfoRow('录取通知书号', this.admissionNo)
    ];
  }

  /** 身份证打码：保留前 6 后 4 */
  private maskIdCard(value: string): string {
    if (value.length <= 10) {
      return value;
    }
    return `${value.substring(0, 6)}********${value.substring(value.length - 4)}`;
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

      Column({ space: 2 }) {
        Text('个人信息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.TEXT_PRIMARY)
        Text('示例学院 · 学籍信息')
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

  /** 分组卡片标题 */
  @Builder
  GroupHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColor.TEXT_SECONDARY)
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 2 })
  }

  @Builder
  RowView(row: InfoRow, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Text(row.label)
          .fontSize(15)
          .fontColor(AppColor.TEXT_PRIMARY)
          .width(104)
        Text(row.value.length > 0 ? row.value : '—')
          .fontSize(14)
          .fontColor(row.value.length > 0 ? AppColor.TEXT_SECONDARY : AppColor.PLACEHOLDER)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .maxLines(this.addrExpanded ? 4 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        // 长值点击展开/收起（住址这类）
        if (row.value.length > 24) {
          this.addrExpanded = !this.addrExpanded;
          Haptics.light();
        }
      })

      if (!isLast) {
        Divider()
          .color(AppColor.DIVIDER)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  GroupCard(rows: InfoRow[]) {
    Column() {
      ForEach(rows, (row: InfoRow, index: number) => {
        this.RowView(row, index === rows.length - 1)
      }, (row: InfoRow) => row.label)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .backgroundColor(AppColor.CARD)
    .borderRadius(AppSize.CARD_RADIUS_SM)
    .visualEffect(MaterialKit.cardReceiver())
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column().height(titleBarHeight(this.topInset))

          // 顶部头像卡：大头像 + 姓名 + 学号 + 学籍状态 chip
          Column({ space: 6 }) {
            Column() {
              Text(this.name.substring(0, 1))
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.ON_BRAND)
            }
            .width(76)
            .height(76)
            .borderRadius(38)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .linearGradient({
              angle: 135,
              colors: [[AppColor.PROFILE_FROM, 0], [AppColor.PROFILE_TO, 1]]
            })

            Text(this.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.TEXT_PRIMARY)
              .margin({ top: 6 })

            Text(this.studentId)
              .fontSize(14)
              .fontColor(AppColor.TEXT_SECONDARY)

            Row({ space: 6 }) {
              Text(this.status.length > 0 ? this.status : '在读')
                .fontSize(12)
                .fontColor(AppColor.GREEN)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(AppColor.CHIP_BG)
                .borderRadius(12)
              if (this.campus.length > 0) {
                Text(this.campus)
                  .fontSize(12)
                  .fontColor(AppColor.TEXT_SECONDARY)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor(AppColor.CHIP_BG)
                  .borderRadius(12)
              }
            }
            .margin({ top: 6 })
          }
          .width('100%')
          .padding({ top: 24, bottom: 20 })
          .backgroundColor(AppColor.CARD)
          .borderRadius(AppSize.CARD_RADIUS_SM)
          .alignItems(HorizontalAlign.Center)
          .visualEffect(MaterialKit.cardReceiver())

          this.GroupHeader('基本信息')
          this.GroupCard(this.basicRows())

          this.GroupHeader('学业信息')
          this.GroupCard(this.studyRows())

          this.GroupHeader('联系方式')
          this.GroupCard(this.contactRows())

          this.GroupHeader('家庭与来源')
          this.GroupCard(this.originRows())

          Text('数据来自学校教务系统 · 点击长文本可展开')
            .fontSize(12)
            .fontColor(AppColor.PLACEHOLDER)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 12 })

          Column().height(this.bottomInset + 12)
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
    .title({ builder: this.NavigationBar(), height: titleBarHeight(this.topInset) },
      { barStyle: BarStyle.STACK })
    .hideBackButton(true)
    .backgroundColor(AppColor.PAGE_BG)
    .onReady((context: NavDestinationContext) => {
      // 官方写法：路由栈从 onReady 上下文取
      this.pathStack = context.pathStack;
    })
  }
}
