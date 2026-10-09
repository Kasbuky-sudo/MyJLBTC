/// 数据模型：与 Rust 核心 `Snapshot`（serde JSON）逐字段对应。
///
/// Flutter 侧只读不写：所有业务数据由核心产出，UI 从这里取。
/// 字段名与核心 JSON 完全一致（camelCase），改字段先改 Rust。
library;

// ---------------- 宽松取值（对齐核心 JSON 的 null 语义） ----------------

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _asStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return '$v';
}

String? _asStrOrNull(dynamic v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

List<String> _asStrList(dynamic v) =>
    (v as List?)?.map((e) => '$e').toList(growable: false) ?? const [];

List<int> _asIntList(dynamic v) =>
    (v as List?)?.map((e) => _asInt(e)).toList(growable: false) ?? const [];

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

// ---------------- 课表 ----------------

/// 一节课（今日课程 / 卡片形态）
class ScheduleCourse {
  const ScheduleCourse({
    required this.name,
    required this.teacher,
    required this.timeText,
    required this.place,
  });

  final String name;
  final String teacher;
  final String timeText;
  final String place;

  factory ScheduleCourse.fromJson(Map<String, dynamic> json) => ScheduleCourse(
    name: _asStr(json['name']),
    teacher: _asStr(json['teacher']),
    timeText: _asStr(json['timeText']),
    place: _asStr(json['place']),
  );

  /// `'08:20 - 10:00'` → `[500, 600]`；解析失败 `[-1, -1]`
  List<int> get span {
    final parts = timeText.split('-');
    if (parts.length != 2) return const [-1, -1];
    return [_toMinutes(parts[0]), _toMinutes(parts[1])];
  }
}

/// `'08:20'` → 500；解析失败 -1
int _toMinutes(String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return -1;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return -1;
  return h * 60 + m;
}

/// 周网格课块
class WeekCourse {
  const WeekCourse({
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    required this.name,
    required this.teacher,
    required this.place,
    required this.examForm,
  });

  /// 星期 1-7（周一 = 1）
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final List<int> weeks;
  final String name;
  final String teacher;
  final String place;

  /// 考试形式（考查/考试）
  final String examForm;

  bool inWeek(int week) => weeks.contains(week);

  factory WeekCourse.fromJson(Map<String, dynamic> json) => WeekCourse(
    weekday: _asInt(json['weekday']),
    startPeriod: _asInt(json['startPeriod']),
    endPeriod: _asInt(json['endPeriod']),
    weeks: _asIntList(json['weeks']),
    name: _asStr(json['name']),
    teacher: _asStr(json['teacher']),
    place: _asStr(json['place']),
    examForm: _asStr(json['examForm']),
  );
}

/// 课表缓存元信息
class ScheduleMeta {
  const ScheduleMeta({
    required this.term,
    required this.week,
    required this.updatedAt,
    required this.count,
  });

  final String term;
  final int week;
  final int updatedAt;
  final int count;

  factory ScheduleMeta.fromJson(Map<String, dynamic> json) => ScheduleMeta(
    term: _asStr(json['term']),
    week: _asInt(json['week']),
    updatedAt: _asInt(json['updatedAt']),
    count: _asInt(json['count']),
  );
}

// ---------------- 成绩 / 考试 / 通知 / 学籍 / 统计 ----------------

class GradeRecord {
  const GradeRecord({
    required this.term,
    required this.code,
    required this.name,
    required this.grade,
    required this.credit,
    required this.gradePoint,
    required this.tag,
  });

  final String term;
  final String code;
  final String name;
  final String grade;
  final String credit;
  final String gradePoint;

  /// 补考 / 缓考补考 / 重修 / 复修；没有就是空串
  final String tag;

  /// 等级制成绩（优秀/良好/中等/及格…）为 true
  bool get isLevel => double.tryParse(grade.trim()) == null;

  /// 分数制成绩的数值（等级制返回 null）
  double? get score => double.tryParse(grade.trim());

  factory GradeRecord.fromJson(Map<String, dynamic> json) => GradeRecord(
    term: _asStr(json['term']),
    code: _asStr(json['code']),
    name: _asStr(json['name']),
    grade: _asStr(json['grade']),
    credit: _asStr(json['credit']),
    gradePoint: _asStr(json['gradePoint']),
    tag: _asStr(json['tag']),
  );
}

class ExamRecord {
  const ExamRecord({
    required this.term,
    required this.batch,
    required this.course,
    required this.time,
    required this.place,
    required this.seat,
    required this.method,
  });

  final String term;
  final String batch;
  final String course;
  final String time;
  final String place;
  final String seat;
  final String method;

  factory ExamRecord.fromJson(Map<String, dynamic> json) => ExamRecord(
    term: _asStr(json['term']),
    batch: _asStr(json['batch']),
    course: _asStr(json['course']),
    time: _asStr(json['time']),
    place: _asStr(json['place']),
    seat: _asStr(json['seat']),
    method: _asStr(json['method']),
  );

  /// 距考试天数：今天 / 还有 N 天 / 已结束 / null（解析失败）
  int? get daysUntil => daysUntilOf(time);
}

/// `'2025-06-30 08:30~10:30'` → 距今天的天数（负数 = 已考完）
int? daysUntilOf(String time, {DateTime? now}) {
  if (time.length < 10) return null;
  final date = DateTime.tryParse(time.substring(0, 10));
  if (date == null) return null;
  final today = now ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(todayDate).inDays;
}

/// 倒计时文案（对应原 ExamPage 的口径）
String countdownText(int? days) {
  if (days == null) return '';
  if (days == 0) return '今天';
  if (days > 0) return '还有 $days 天';
  return '已结束';
}

class NoticeRecord {
  const NoticeRecord({
    required this.id,
    required this.title,
    required this.author,
    required this.time,
    required this.readCount,
    required this.totalCount,
    required this.paragraphs,
    required this.signature,
    required this.likers,
    required this.commentClosed,
  });

  final String id;
  final String title;
  final String author;

  /// 展示用时间，如 '06-01 19:55'
  final String time;
  final int readCount;
  final int totalCount;
  final List<String> paragraphs;
  final String signature;
  final List<String> likers;
  final bool commentClosed;

  factory NoticeRecord.fromJson(Map<String, dynamic> json) => NoticeRecord(
    id: _asStr(json['id']),
    title: _asStr(json['title']),
    author: _asStr(json['author']),
    time: _asStr(json['time']),
    readCount: _asInt(json['readCount']),
    totalCount: _asInt(json['totalCount']),
    paragraphs: _asStrList(json['paragraphs']),
    signature: _asStr(json['signature']),
    likers: _asStrList(json['likers']),
    commentClosed: json['commentClosed'] == true,
  );
}

/// 学籍资料（字段全部可空：没同步过就是 null）
class ProfileView {
  const ProfileView({
    this.name,
    this.studentId,
    this.college,
    this.major,
    this.className,
    this.sex,
    this.nation,
    this.birth,
    this.idCard,
    this.phone,
    this.email,
    this.qq,
    this.wechat,
    this.campus,
    this.duration,
    this.enrollYear,
    this.status,
    this.classSize,
    this.homeAddr,
    this.homePhone,
    this.middleSchool,
    this.examNo,
    this.admissionNo,
    this.graduateAt,
  });

  final String? name;
  final String? studentId;
  final String? college;
  final String? major;
  final String? className;
  final String? sex;
  final String? nation;
  final String? birth;
  final String? idCard;
  final String? phone;
  final String? email;
  final String? qq;
  final String? wechat;
  final String? campus;
  final String? duration;
  final String? enrollYear;
  final String? status;
  final String? classSize;
  final String? homeAddr;
  final String? homePhone;
  final String? middleSchool;
  final String? examNo;
  final String? admissionNo;
  final String? graduateAt;

  factory ProfileView.fromJson(Map<String, dynamic> json) => ProfileView(
    name: _asStrOrNull(json['name']),
    studentId: _asStrOrNull(json['studentId']),
    college: _asStrOrNull(json['college']),
    major: _asStrOrNull(json['major']),
    className: _asStrOrNull(json['className']),
    sex: _asStrOrNull(json['sex']),
    nation: _asStrOrNull(json['nation']),
    birth: _asStrOrNull(json['birth']),
    idCard: _asStrOrNull(json['idCard']),
    phone: _asStrOrNull(json['phone']),
    email: _asStrOrNull(json['email']),
    qq: _asStrOrNull(json['qq']),
    wechat: _asStrOrNull(json['wechat']),
    campus: _asStrOrNull(json['campus']),
    duration: _asStrOrNull(json['duration']),
    enrollYear: _asStrOrNull(json['enrollYear']),
    status: _asStrOrNull(json['status']),
    classSize: _asStrOrNull(json['classSize']),
    homeAddr: _asStrOrNull(json['homeAddr']),
    homePhone: _asStrOrNull(json['homePhone']),
    middleSchool: _asStrOrNull(json['middleSchool']),
    examNo: _asStrOrNull(json['examNo']),
    admissionNo: _asStrOrNull(json['admissionNo']),
    graduateAt: _asStrOrNull(json['graduateAt']),
  );

  /// 身份证打码（保留前 6 后 4，与页面口径一致）
  String? get maskedIdCard {
    final id = idCard;
    if (id == null || id.length < 11) return id;
    return '${id.substring(0, 6)}${'*' * (id.length - 10)}${id.substring(id.length - 4)}';
  }
}

/// 首页统计
class Stats {
  const Stats({
    required this.credits,
    required this.courseCount,
    required this.requiredCredits,
    required this.refreshAt,
  });

  final String credits;
  final String courseCount;
  final String requiredCredits;
  final int refreshAt;

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    credits: _asStr(json['credits']),
    courseCount: _asStr(json['courseCount']),
    requiredCredits: _asStr(json['requiredCredits']),
    refreshAt: _asInt(json['refreshAt']),
  );

  /// 「上次刷新：X 分钟前」的相对文案（对应原 DataCard）
  String refreshAgoText({DateTime? now}) {
    if (refreshAt <= 0) return '暂无数据';
    final n = now ?? DateTime.now();
    final diff = n.millisecondsSinceEpoch - refreshAt;
    if (diff < 0) return '刚刚';
    final minutes = diff ~/ 60000;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours小时前';
    return '${hours ~/ 24}天前';
  }

  static const empty = Stats(
    credits: '',
    courseCount: '',
    requiredCredits: '',
    refreshAt: 0,
  );
}

// ---------------- 快照（一次读出全部 UI 数据） ----------------

class Snapshot {
  const Snapshot({
    required this.todayCourses,
    required this.weekCourses,
    required this.scheduleMeta,
    required this.scheduleUpdatedAt,
    required this.grades,
    required this.exams,
    required this.notices,
    required this.profile,
    required this.stats,
    required this.dataEpoch,
  });

  final List<ScheduleCourse> todayCourses;
  final List<WeekCourse> weekCourses;
  final ScheduleMeta? scheduleMeta;
  final int scheduleUpdatedAt;
  final List<GradeRecord> grades;
  final List<ExamRecord> exams;
  final List<NoticeRecord> notices;
  final ProfileView? profile;
  final Stats stats;
  final int dataEpoch;

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final meta = json['scheduleMeta'];
    final profile = json['profile'];
    final stats = json['stats'];
    return Snapshot(
      todayCourses: (json['todayCourses'] as List? ?? const [])
          .map((e) => ScheduleCourse.fromJson(_asMap(e)))
          .toList(growable: false),
      weekCourses: (json['weekCourses'] as List? ?? const [])
          .map((e) => WeekCourse.fromJson(_asMap(e)))
          .toList(growable: false),
      scheduleMeta: meta == null ? null : ScheduleMeta.fromJson(_asMap(meta)),
      scheduleUpdatedAt: _asInt(json['scheduleUpdatedAt']),
      grades: (json['grades'] as List? ?? const [])
          .map((e) => GradeRecord.fromJson(_asMap(e)))
          .toList(growable: false),
      exams: (json['exams'] as List? ?? const [])
          .map((e) => ExamRecord.fromJson(_asMap(e)))
          .toList(growable: false),
      notices: (json['notices'] as List? ?? const [])
          .map((e) => NoticeRecord.fromJson(_asMap(e)))
          .toList(growable: false),
      profile: profile == null ? null : ProfileView.fromJson(_asMap(profile)),
      stats: stats == null ? Stats.empty : Stats.fromJson(_asMap(stats)),
      dataEpoch: _asInt(json['dataEpoch']),
    );
  }

  static const empty = Snapshot(
    todayCourses: [],
    weekCourses: [],
    scheduleMeta: null,
    scheduleUpdatedAt: 0,
    grades: [],
    exams: [],
    notices: [],
    profile: null,
    stats: Stats.empty,
    dataEpoch: 0,
  );

  NoticeRecord? get latestNotice => notices.isEmpty ? null : notices.first;

  /// 数据里出现过的学年（新的在前）
  List<String> get gradeYears {
    final years = <String>[];
    for (final g in grades) {
      final y = termYear(g.term);
      if (!years.contains(y)) years.add(y);
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  /// 数据里出现过的学年学期（新的在前）
  List<String> get examTerms {
    final terms = <String>[];
    for (final e in exams) {
      if (!terms.contains(e.term)) terms.add(e.term);
    }
    terms.sort((a, b) => b.compareTo(a));
    return terms;
  }

  List<GradeRecord> gradesOf(String year, String semester) => grades
      .where((g) => termYear(g.term) == year && termSemester(g.term) == semester)
      .toList(growable: false);

  List<String> examBatchesOf(String term) {
    final batches = <String>[allBatches];
    for (final e in exams) {
      if (e.term == term && !batches.contains(e.batch)) batches.add(e.batch);
    }
    return batches;
  }

  List<ExamRecord> examsOf(String term, String batch) => exams
      .where((e) => e.term == term && (batch == allBatches || e.batch == batch))
      .toList(growable: false);

  NoticeRecord? noticeById(String id) {
    for (final n in notices) {
      if (n.id == id) return n;
    }
    return null;
  }
}

/// 考试批次下拉第一项（与原实现一致）
const String allBatches = '全部批次';

/// `2025-2026-2` → `2025-2026`
String termYear(String term) {
  final idx = term.lastIndexOf('-');
  return idx > 0 ? term.substring(0, idx) : term;
}

/// `2025-2026-2` → `2`
String termSemester(String term) {
  final idx = term.lastIndexOf('-');
  return idx > 0 ? term.substring(idx + 1) : '';
}

/// `2025-2026` + `2` → `2025-2026 学年 · 第 2 学期`
String termLabel(String year, String semester) => '$year 学年 · 第 $semester 学期';

/// 学分合计（hdxf 求和）
double creditSumOf(List<GradeRecord> records) {
  var sum = 0.0;
  for (final r in records) {
    final v = double.tryParse(r.credit.trim());
    if (v != null) sum += v;
  }
  return (sum * 100).round() / 100;
}

/// 加权平均绩点（xfjd 按 hdxf 加权）
double gpaOf(List<GradeRecord> records) {
  var weighted = 0.0;
  var credits = 0.0;
  for (final r in records) {
    final point = double.tryParse(r.gradePoint.trim());
    final credit = double.tryParse(r.credit.trim());
    if (point != null && credit != null && credit > 0) {
      weighted += point * credit;
      credits += credit;
    }
  }
  if (credits == 0) return 0;
  return ((weighted / credits) * 100).round() / 100;
}

/// 平均分（只算分数制）
double averageOf(List<GradeRecord> records) {
  var sum = 0.0;
  var count = 0;
  for (final r in records) {
    final v = r.score;
    if (v != null) {
      sum += v;
      count++;
    }
  }
  if (count == 0) return 0;
  return ((sum / count) * 10).round() / 10;
}

/// 等级制课程数量
int levelCountOf(List<GradeRecord> records) =>
    records.where((r) => r.isLevel).length;

/// 第 n 大节的上下课时间（学校作息，从教务课表页实测）
const List<String> bigPeriodTimes = [
  '08:20 - 10:00',
  '10:20 - 12:00',
  '13:20 - 15:00',
  '15:20 - 16:50',
  '18:00 - 19:30',
  '19:40 - 21:05',
];

/// 1-7 → 周一…周日
const List<String> weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayLabel(int weekday) =>
    (weekday >= 1 && weekday <= 7) ? weekdayNames[weekday - 1] : '';

/// 今天星期几（1-7，周一 = 1）
int todayWeekday([DateTime? now]) {
  final n = now ?? DateTime.now();
  return n.weekday; // Dart: 1=Mon..7=Sun，与教务口径一致
}
