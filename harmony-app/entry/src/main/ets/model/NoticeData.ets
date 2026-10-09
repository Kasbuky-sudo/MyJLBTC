/**
 * 通知公告（站内信函）数据。
 * 纯数据文件，页面只依赖这里的类型；接教务系统时换 notices 数组即可。
 */

export class NoticeRecord {
  id: string;
  title: string;
  author: string;
  /** 展示用时间，如 '06-01 19:55' */
  time: string;
  readCount: number;
  totalCount: number;
  /** 正文段落（列表里每个元素是一段，换行用 \n） */
  paragraphs: string[];
  /** 落款，如 '安全保卫处\n2026年6月1日' */
  signature: string;
  /** 点赞的人（展示时取前 3 个 + 总数） */
  likers: string[];
  commentClosed: boolean;

  constructor(id: string, title: string, author: string, time: string, readCount: number,
    totalCount: number, paragraphs: string[], signature: string, likers: string[],
    commentClosed: boolean) {
    this.id = id;
    this.title = title;
    this.author = author;
    this.time = time;
    this.readCount = readCount;
    this.totalCount = totalCount;
    this.paragraphs = paragraphs;
    this.signature = signature;
    this.likers = likers;
    this.commentClosed = commentClosed;
  }
}

/** 路由传参：只带 id，页面自己去 notices 里取 */
export class NoticeParam {
  id: string;

  constructor(id: string) {
    this.id = id;
  }
}

export const notices: NoticeRecord[] = [
  new NoticeRecord(
    'n1',
    '学生公寓消防电气检测停电通知',
    '宗秀丽',
    '06-01 19:55',
    10007,
    14676,
    [
      '各位同学：',
      '为保障学生公寓用电安全，安全保卫处计划于本周二（6月2日）对全校学生公寓逐栋开展消防电气检测。检测期间，相关公寓楼将短暂停电。',
      '请同学们提前做好电子设备断电准备，避免造成数据丢失。感谢大家的理解与配合，让我们一起为更安全的住宿环境助力！',
      '各公寓具体停电时间安排如下：',
      '一公寓：10:00 – 10:30\n二公寓：10:30 – 11:00\n三公寓：11:00 – 11:30\n四公寓：13:00 – 13:30\n五公寓：13:30 – 14:00\n六公寓：14:00 – 14:30\n七公寓：15:00 – 15:30\n八公寓：15:30 – 16:00\n九公寓：16:00 – 17:00'
    ],
    '安全保卫处\n2026年6月1日',
    ['赵博成', '宋青青', '胡茗博', '林一诺', '陈嘉禾', '周亦然', '吴子墨', '何思远', '郑允安'],
    true
  ),
  new NoticeRecord(
    'n2',
    '关于 2025-2026 学年第一学期期末考试安排的通知',
    '教务处',
    '06-05 09:00',
    8421,
    12030,
    [
      '各二级学院、全体同学：',
      '2025-2026 学年第一学期期末考试将于第 18-19 教学周进行，具体考试时间、考场及座位号已发布，请登录教务系统「考试安排」查询。',
      '请同学们携带学生证与身份证按时参加考试，开考 15 分钟后不得入场。',
      '如有疑问请联系所在学院教学办公室。'
    ],
    '教务处\n2026年6月5日',
    ['李知遥', '王沐辰', '张予安'],
    false
  ),
  new NoticeRecord(
    'n3',
    '关于开展本学期期末教学评价工作的通知',
    '教学质量办公室',
    '06-08 14:20',
    5233,
    12030,
    [
      '各位同学：',
      '本学期期末教学评价已开放，请于 6 月 20 日前完成所有课程的评价。',
      '评价结果将作为教师教学考核的重要依据，请客观、如实填写。'
    ],
    '教学质量办公室\n2026年6月8日',
    ['陈嘉禾', '周亦然'],
    false
  ),
  new NoticeRecord(
    'n4',
    '图书馆国庆假期开放时间调整公告',
    '图书馆',
    '09-28 16:40',
    3120,
    12030,
    [
      '各位读者：',
      '国庆假期期间，图书馆开放时间调整如下：10 月 1 日至 10 月 3 日闭馆，10 月 4 日起恢复正常开放（08:00 - 22:00）。',
      '闭馆期间到期的图书将自动顺延，请合理安排借阅。'
    ],
    '图书馆\n2026年9月28日',
    ['吴子墨'],
    true
  )
];

/** 最新一条（首页公告条用） */
export function latestNotice(): NoticeRecord {
  return notices[0];
}

export function noticeById(id: string): NoticeRecord | undefined {
  for (let i = 0; i < notices.length; i++) {
    if (notices[i].id === id) {
      return notices[i];
    }
  }
  return undefined;
}

// ---------------- 真实数据接入（教务缓存 → 页面数组） ----------------

/** notices.raw 的接口行（字段按教务 tzsjx/ajaxList 实测口径） */
interface RawNoticeRow {
  id?: string;
  title?: string;
  releaseDate?: string;
  content?: string;
  noticeTypeName?: string;
}

/** '2026-02-28 13:58:07' → '02-28 13:58'（列表展示口径） */
function shortDate(raw: string): string {
  if (raw.length >= 16 && raw.indexOf('-') === 4) {
    return raw.substring(5, 16);
  }
  return raw;
}

/**
 * 用真实通知替换页面数组（原地替换；正文按空行分段）。
 * 接口行没有阅读数/点赞字段，这些位显示为空态而不是假数字；
 * 发布者用通知类型名兜底（接口没给部门名）。
 */
export function replaceNotices(rawJson: string): boolean {
  try {
    const parsed = JSON.parse(rawJson) as Record<string, Object>;
    const rowsObj = parsed['results'];
    if (rowsObj === undefined) {
      return false;
    }
    const rows = rowsObj as RawNoticeRow[];
    const next: NoticeRecord[] = [];
    for (const row of rows) {
      const id: string = row.id !== undefined ? row.id : '';
      const title: string = row.title !== undefined ? row.title.trim() : '';
      const content: string = row.content !== undefined ? row.content.trim() : '';
      if (id.length === 0 || title.length === 0) {
        continue;
      }
      // 正文按空行分段（接口 content 里空行分隔），段内换行保留
      const paragraphs: string[] = content.length > 0
        ? content.split('\n\n').map((p: string) => p.trim()).filter((p: string) => p.length > 0)
        : ['（正文为空）'];
      next.push(new NoticeRecord(
        id,
        title,
        row.noticeTypeName !== undefined && row.noticeTypeName.length > 0 ? row.noticeTypeName : '学校通知',
        shortDate(row.releaseDate !== undefined ? row.releaseDate : ''),
        0,
        0,
        paragraphs,
        '示例学院',
        [],
        true
      ));
    }
    if (next.length === 0) {
      return false;
    }
    notices.splice(0, notices.length);
    for (const record of next) {
      notices.push(record);
    }
    return true;
  } catch (err) {
    return false;
  }
}
