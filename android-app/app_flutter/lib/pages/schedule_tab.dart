import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/page_scaffold.dart';

/// 课表页（周视图网格，自绘）：左节次轴 + 顶部星期条，课程块按 星期 × 大节 落格。
///
/// 口径与学校课表一致：
/// - 一天 8 小節（大节 = 2 小節，第 1-4 大节为白天，第 5-6 大节为晚课）；
/// - 节次轴每行一个小節，标注该小節的**下课时刻**（1→09:05 … 8→17:00）；
/// - 课程块高 = 大节数 × 2 × 行高，同一门课固定配色；
/// - 周次可切（点「切换周次」或左右滑动），非本周时给「回到本周」；
/// - 本页**不使用液态玻璃**（用户口径）：课块详情 / 周次选择走普通 Material 底部弹层。

/// 学期总周数（教务课表页口径 22 周）
const int totalWeeks = 22;

/// 周一到周日表头
const List<String> _weekdayHeads = ['一', '二', '三', '四', '五', '六', '日'];

/// 节次轴每行的「下课时刻」（8 小節，取作息表偶数位）
const List<String> _smallRowTimes = [
  '09:05',
  '10:00',
  '11:05',
  '12:00',
  '14:05',
  '15:00',
  '16:05',
  '17:00',
];

/// 晚课（第 5-6 大节 = 第 9-12 小節）的下课时刻；本学期没排晚课时用不到
const List<String> _nightRowTimes = ['18:45', '19:30', '20:20', '21:05'];

/// 单个小節的行高（轴 / 网格线 / 课程块三方共用，保证纵向对齐）
const double slotHeight = 54;

/// 左侧节次轴宽度
const double _axisWidth = 40;

/// 表头高度
const double _headerHeight = 40;

/// 课程块配色轮转（紫 / 绿 / 橙 / 深紫），按课程名哈希取，同一门课每天同色
List<Color> _coursePalette(AppColor c) => [
  c.accent,
  c.brandGreen,
  c.warning,
  c.profileTo,
];

/// 课程名 → 稳定配色索引（名字哈希，避免每次渲染变色）
int _courseColorIndex(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) % 997;
  }
  return hash % 4;
}

/// 一周里某天某节落着的课（周网格查表用）
class _GridBlock {
  const _GridBlock(this.course, this.span);

  final WeekCourse course;

  /// 占几个大节（连堂合并）
  final int span;
}

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  /// null = 跟随教学周
  int? _selectedWeek;

  /// 选中周的周一：本周一 + (选中周 − 教学周) × 7 天
  DateTime _mondayOfWeek(int week, int baseWeek) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: (week - baseWeek) * 7));
  }

  void _selectWeek(int week, int baseWeek) {
    HapticFeedback.selectionClick();
    setState(() => _selectedWeek = week.clamp(1, totalWeeks));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final snap = store.snapshot;
    final colors = AppColor.of(context);
    final realWeek = snap.scheduleMeta?.week ?? 0;
    final week = (_selectedWeek ?? (realWeek > 0 ? realWeek : 1)).clamp(
      1,
      totalWeeks,
    );
    final baseWeek = realWeek > 0 ? realWeek : week;
    final monday = _mondayOfWeek(week, baseWeek);
    final syncText = store.scheduleUpdatedText;
    final isCurrentWeek = realWeek <= 0 || week == realWeek;

    return PageScaffold(
      title: '课表',
      slivers: [
        // A1：第 N 周 ｜ 切换周次 ▾ ｜ 回到本周 ……… 已同步
        Row(
          children: [
            Text(
              '第 $week 周',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            _WeekChip(onTap: () => _pickWeek(week, baseWeek)),
            if (!isCurrentWeek) ...[
              const SizedBox(width: 6),
              _BackToWeekChip(
                onTap: () => _selectWeek(realWeek, baseWeek),
              ),
            ],
            const Spacer(),
            Text(
              syncText.isEmpty ? '课表未同步' : syncText,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // A2：提示条（网格上方）
        const _HintBar(),
        const SizedBox(height: 12),

        if (snap.weekCourses.isEmpty)
          const SectionCard(
            padding: EdgeInsets.all(16),
            child: EmptyHint('课表未同步：登录后刷新即可同步本学期课表', padding: EdgeInsets.zero),
          )
        else
          GestureDetector(
            // 左右滑动换周（横滑与页面纵向滚动不冲突）
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -220) {
                _selectWeek(week + 1, baseWeek);
              } else if (v > 220) {
                _selectWeek(week - 1, baseWeek);
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _WeekGridCard(
                key: ValueKey('week-$week'),
                week: week,
                monday: monday,
                courses: snap.weekCourses,
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 周次选择：底部弹层（1-22 周）。课表页不用液态玻璃，走普通 Material 弹层。
  Future<void> _pickWeek(int week, int baseWeek) async {
    final colors = AppColor.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择教学周',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var w = 1; w <= totalWeeks; w++)
                    Material(
                      color: w == week ? colors.accent : colors.chipBg,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(w),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          child: Text(
                            '第 $w 周',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: w == week
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: w == week
                                  ? colors.onAccent
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _selectWeek(picked, baseWeek);
  }
}

/// 「切换周次 ▾」胶囊
class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Material(
      color: colors.chipBg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: SizedBox(
            height: 26,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '切换周次',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「回到本周」胶囊（非本周时出现）
class _BackToWeekChip extends StatelessWidget {
  const _BackToWeekChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Material(
      color: colors.accentSoft,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 26,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_rounded, size: 12, color: colors.accent),
                const SizedBox(width: 3),
                Text(
                  '回到本周',
                  style: TextStyle(fontSize: 12, color: colors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 网格上方的提示条：「提示」胶囊 + 说明文字
class _HintBar extends StatelessWidget {
  const _HintBar();

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '提示',
              style: TextStyle(fontSize: 10, color: colors.accent),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '课表以学校教务系统为准。老师如需调课 / 串课，须先向学校提出申请并通过审核；'
              '学校更新课表后，本应用刷新时即自动同步为最新安排。',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一周的网格卡：表头（月份 + 周几 + 日期）+ 节次轴 + 7 列课程块
class _WeekGridCard extends StatelessWidget {
  const _WeekGridCard({
    super.key,
    required this.week,
    required this.monday,
    required this.courses,
  });

  final int week;
  final DateTime monday;
  final List<WeekCourse> courses;

  /// 本周要画的课块（按天分组）
  List<_GridBlock> _blocksOf(int weekday) {
    final out = <_GridBlock>[];
    for (final c in courses) {
      if (c.weekday != weekday || !c.inWeek(week)) continue;
      out.add(_GridBlock(c, c.endPeriod - c.startPeriod + 1));
    }
    out.sort((a, b) => a.course.startPeriod.compareTo(b.course.startPeriod));
    return out;
  }

  /// 需要几行小節：白天固定 8 行；排到晚课时（第 5-6 大节）再加 4 行
  int _rowCount() {
    var maxBig = 4;
    for (final c in courses) {
      if (c.endPeriod > maxBig) maxBig = c.endPeriod;
    }
    return (maxBig * 2).clamp(8, 12);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final rows = _rowCount();
    final rowTimes = <String>[
      ..._smallRowTimes,
      if (rows > 8) ..._nightRowTimes,
    ].take(rows).toList();
    final palette = _coursePalette(colors);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppSize.cardRadiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 表头：月份角标 + 一~日（带日期，今天高亮）
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                SizedBox(
                  width: _axisWidth,
                  child: Center(
                    child: Text(
                      '${monday.month}月',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayHead(
                      head: _weekdayHeads[i],
                      day: monday.add(Duration(days: i)).day,
                      isToday:
                          monday.add(Duration(days: i)) == todayDate,
                    ),
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: colors.divider),

          // 主体：节次轴 + 7 列
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧节次轴（小節号 + 下课时刻，两行一组：号码在上、时刻在下）
              Column(
                children: [
                  for (var i = 0; i < rows; i++)
                    SizedBox(
                      width: _axisWidth,
                      height: slotHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            rowTimes[i],
                            style: TextStyle(
                              fontSize: 8,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: _DayColumn(
                    rows: rows,
                    blocks: _blocksOf(day),
                    palette: palette,
                    divider: colors.divider,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 表头里的一天：周几 + 日期
class _DayHead extends StatelessWidget {
  const _DayHead({required this.head, required this.day, required this.isToday});

  final String head;
  final int day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final color = isToday ? colors.accent : colors.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          head,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text('$day', style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

/// 一天一列：底层 8 小節网格线 + 课程块层
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.rows,
    required this.blocks,
    required this.palette,
    required this.divider,
  });

  final int rows;
  final List<_GridBlock> blocks;
  final List<Color> palette;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: slotHeight * rows,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 底层网格线（每小節一行）
          Column(
            children: [
              for (var i = 0; i < rows; i++)
                SizedBox(
                  height: slotHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: divider, width: 0.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // 课程块层：大节 → 小節区间 [2n-1, 2n]
          for (final block in blocks)
            Positioned(
              left: 1,
              right: 1,
              top: 1 + (block.course.startPeriod - 1) * 2 * slotHeight,
              height: block.span * 2 * slotHeight - 2,
              child: _CourseBlock(
                course: block.course,
                color: palette[_courseColorIndex(block.course.name)],
                onTap: () => _showDetail(context, block.course),
              ),
            ),
        ],
      ),
    );
  }
}

/// 课程块：课名 / ＠地点 / 老师 / 考查方式（白字，四行）
class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.course,
    required this.color,
    required this.onTap,
  });

  final WeekCourse course;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 课块底色随课程/主题变（深色 + 莫奈时是浅色块），文字颜色按底色亮度自己选，
    // 免得出现"白字压浅色块"看不清
    final fg = AppColor.contentOn(color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                course.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
            if (course.place.isNotEmpty)
              Text(
                '@${course.place}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: fg, height: 1.2),
              ),
            if (course.teacher.isNotEmpty)
              Text(
                course.teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: fg, height: 1.2),
              ),
            if (course.examForm.isNotEmpty)
              Text(
                course.examForm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: fg, height: 1.2),
              ),
          ],
        ),
      ),
    );
  }
}

/// 课块详情：普通 Material 底部弹层（课表页不用液态玻璃）
void _showDetail(BuildContext context, WeekCourse course) {
  final colors = AppColor.of(context);
  final bigIndex = (course.startPeriod - 1).clamp(0, bigPeriodTimes.length - 1);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${weekdayLabel(course.weekday)} 第 ${course.startPeriod}'
              '${course.endPeriod > course.startPeriod ? '-${course.endPeriod}' : ''} 大节'
              ' · ${bigPeriodTimes[bigIndex]}',
              style: TextStyle(fontSize: 14, color: colors.textMeta),
            ),
            const SizedBox(height: 14),
            _detailRow(context, '教师', course.teacher),
            _detailRow(context, '地点', course.place),
            _detailRow(context, '考查方式', course.examForm),
            _detailRow(context, '周次', _weeksText(course.weeks)),
          ],
        ),
      ),
    ),
  );
}

/// 周次列表 → `1-8,10,12-16`
String _weeksText(List<int> weeks) {
  if (weeks.isEmpty) return '—';
  final sorted = [...weeks]..sort();
  final parts = <String>[];
  var start = sorted.first;
  var prev = sorted.first;
  for (final w in sorted.skip(1)) {
    if (w == prev + 1) {
      prev = w;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    start = w;
    prev = w;
  }
  parts.add(start == prev ? '$start' : '$start-$prev');
  return parts.join(',');
}

Widget _detailRow(BuildContext context, String label, String value) {
  final colors = AppColor.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(fontSize: 14, color: colors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
