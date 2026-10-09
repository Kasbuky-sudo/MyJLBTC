/**
 * 课表数据与"下一节课"计算。
 *
 * 这里是**纯数据**，刻意不引用任何 `$r(...)` 资源：卡片的后台
 * `FormExtensionAbility` 也会 import 它，而那里没有 UI 上下文，
 * 模块加载期调用 $r 会出问题（CampusData 里有 $r，所以卡片不能直接引它）。
 */

/** 一节课 */
export class ScheduleCourse {
  name: string;
  teacher: string;
  timeText: string;
  place: string;

  constructor(name: string, teacher: string, timeText: string, place: string) {
    this.name = name;
    this.teacher = teacher;
    this.timeText = timeText;
    this.place = place;
  }
}

/** 与 ScheduleCourse 同构的纯数据版（缓存里的 JSON 反序列化用） */
export interface ScheduleCourseData {
  name: string;
  teacher: string;
  timeText: string;
  place: string;
}

/** 周课表网格用的一节课（原始课表条目：星期 × 大节 + 周次） */
export class WeekCourse {
  /** 星期 1-7（周一=1，教务 xingqi 同口径） */
  weekday: number;
  /** 开始大节 1-6 */
  startPeriod: number;
  /** 结束大节（≥ startPeriod；单大节=自身） */
  endPeriod: number;
  /** 上课周次列表（'1-8,10' 展开） */
  weeks: number[];
  name: string;
  teacher: string;
  place: string;

  constructor(weekday: number, startPeriod: number, endPeriod: number, weeks: number[],
    name: string, teacher: string, place: string) {
    this.weekday = weekday;
    this.startPeriod = startPeriod;
    this.endPeriod = endPeriod;
    this.weeks = weeks;
    this.name = name;
    this.teacher = teacher;
    this.place = place;
  }

  /** 该课是否在某周上 */
  inWeek(week: number): boolean {
    return this.weeks.indexOf(week) >= 0;
  }
}

/** 桌面卡片用的单节课（FormAbility 独立进程同步解析，不含 $r 资源引用） */
export class FormScheduleItem {
  weekday: number;
  startPeriod: number;
  weeks: number[];
  name: string;
  teacher: string;
  place: string;

  constructor(weekday: number, startPeriod: number, weeks: number[],
    name: string, teacher: string, place: string) {
    this.weekday = weekday;
    this.startPeriod = startPeriod;
    this.weeks = weeks;
    this.name = name;
    this.teacher = teacher;
    this.place = place;
  }
}

/** 卡片课表数据（hasData=false 表示本机还没同步过课表） */
export class FormScheduleData {
  hasData: boolean = false;
  /** 当前教学周（0 = 未知，不按周次过滤） */
  week: number = 0;
  items: FormScheduleItem[] = [];
}

/** 学校作息：第 n 大节的上下课时间（从教务课表页面实测，2026-10-03） */
export const BIG_PERIOD_TIMES: string[] = [
  '08:20 - 10:00',
  '10:20 - 12:00',
  '13:20 - 15:00',
  '15:20 - 16:50',
  '18:00 - 19:30',
  '19:40 - 21:05'
];

/** 学校作息：小节制 1-8（学校课表页/参考课表 App 的口径，每节 45 分钟） */
export const SMALL_PERIOD_TIMES: string[] = [
  '08:20', '09:05', '09:15', '10:00', '10:20', '11:05', '11:15', '12:00',
  '13:20', '14:05', '14:15', '15:00', '15:20', '16:05', '16:15', '17:00'
];

/** 大节 n（1-6）覆盖的小节区间：[2n-1, 2n] */
export function smallPeriodRange(bigPeriod: number): number[] {
  return [bigPeriod * 2 - 1, bigPeriod * 2];
}

/** 今天是星期几（1-7，周一开始；教务系统 xingqi 字段同口径） */
export function todayWeekday(): number {
  const day: number = new Date().getDay();
  return day === 0 ? 7 : day;
}

/** 1-7 → 周一…周日 */
export function weekdayLabel(weekday: number): string {
  const names: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  if (weekday >= 1 && weekday <= 7) {
    return names[weekday - 1];
  }
  return '';
}

/** 缓存里的纯对象 → ScheduleCourse 实例 */
export function toScheduleCourses(rows: ScheduleCourseData[]): ScheduleCourse[] {
  return rows.map((row: ScheduleCourseData) =>
    new ScheduleCourse(row.name, row.teacher, row.timeText, row.place));
}

/** 今天的课（示例数据；真实数据接教务后由 ScheduleStore 覆盖，卡片与页面都读 AppStorage） */
export const todaySchedule: ScheduleCourse[] = [
  new ScheduleCourse('高等数学（下）', '张明', '08:00 - 09:40', '教一 A301'),
  new ScheduleCourse('大学英语（四）', '李静', '10:00 - 11:40', '外语楼 B205'),
  new ScheduleCourse('金融学基础', '王海', '14:00 - 15:40', '经管楼 C102')
];

/** '08:00' → 8*60+0；解析不出来返回 -1 */
export function toMinutes(hhmm: string): number {
  const parts: string[] = hhmm.trim().split(':');
  if (parts.length !== 2) {
    return -1;
  }
  const hour: number = Number(parts[0]);
  const minute: number = Number(parts[1]);
  if (isNaN(hour) || isNaN(minute)) {
    return -1;
  }
  return hour * 60 + minute;
}

/** '08:00 - 09:40' → [480, 580]，解析失败返回 [-1, -1] */
export function courseSpan(course: ScheduleCourse): number[] {
  const parts: string[] = course.timeText.split('-');
  if (parts.length !== 2) {
    return [-1, -1];
  }
  return [toMinutes(parts[0]), toMinutes(parts[1])];
}

/** 当前时间距 0 点的分钟数 */
export function nowMinutes(): number {
  const now: Date = new Date();
  return now.getHours() * 60 + now.getMinutes();
}

/** 正在上的课（now 落在某节课的时间段内），没有返回 undefined */
export function ongoingCourseIn(courses: ScheduleCourse[], now: number): ScheduleCourse | undefined {
  for (let i = 0; i < courses.length; i++) {
    const span: number[] = courseSpan(courses[i]);
    if (span[0] >= 0 && now >= span[0] && now <= span[1]) {
      return courses[i];
    }
  }
  return undefined;
}

/** 下一节没开始的课，没有返回 undefined */
export function upcomingCourseIn(courses: ScheduleCourse[], now: number): ScheduleCourse | undefined {
  for (let i = 0; i < courses.length; i++) {
    const span: number[] = courseSpan(courses[i]);
    if (span[0] >= 0 && now < span[0]) {
      return courses[i];
    }
  }
  return undefined;
}

/** 正在上的课（示例数据版；桌面卡片在用） */
export function ongoingCourse(now: number): ScheduleCourse | undefined {
  return ongoingCourseIn(todaySchedule, now);
}

/** 下一节没开始的课（示例数据版；桌面卡片在用） */
export function upcomingCourse(now: number): ScheduleCourse | undefined {
  return upcomingCourseIn(todaySchedule, now);
}
