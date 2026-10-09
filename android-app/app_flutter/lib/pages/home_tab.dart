import 'package:flutter/material.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/cards.dart';
import '../widgets/page_scaffold.dart';

/// 首页：公告条 / 个人信息卡 / 数据卡 / 学分卡 / 常用功能 / 今日课程
/// （版面顺序与原 `HomeTab.ets` build() 一致）
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final snap = store.snapshot;
    return PageScaffold(
      title: 'MyJLBTC',
      slivers: [
        _NoticeBar(notice: snap.latestNotice),
        const SizedBox(height: 12),
        _ProfileCard(profile: snap.profile),
        const SizedBox(height: 12),
        _DataCard(store: store),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatTile(label: '已修学分', value: snap.stats.credits),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(label: '应修学分', value: snap.stats.requiredCredits),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _FunctionCard(),
        const SizedBox(height: 12),
        _TodayCoursesCard(
          courses: snap.todayCourses,
          synced: snap.scheduleUpdatedAt > 0,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 公告条：铃铛 + 最新一条标题 + 右箭头
class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.notice});

  final NoticeRecord? notice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final text = notice?.title ?? '暂无通知公告';
    return GestureDetector(
      onTap: () {
        // 公告条进的是**列表**（首页只显示最新一条，其余在列表里看）—— 原版 MainShell 口径
        Navigator.of(context).pushNamed('/notices');
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.only(left: 16, right: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_none_rounded, size: 18, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textMeta),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// 个人信息卡：紫渐变 + 装饰圆 + 姓名/学院/专业/班级/学号
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final ProfileView? profile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final p = profile;
    return Container(
      width: double.infinity,
      height: 158,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSize.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.profileFrom, colors.profileTo],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 装饰圆
          Positioned(
            right: -46,
            top: -46,
            child: _disc(150, const Color(0x1AFFFFFF)),
          ),
          Positioned(
            right: 120,
            bottom: -46,
            child: _disc(90, const Color(0x14FFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p?.name ?? '未同步',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                    if (p?.college != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          // 卡片底色深浅随主题变，胶囊底色取前景色 + 低透明度
                          color: colors.onAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p!.college!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  p?.major ?? '登录后同步学籍信息',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: colors.onAccent.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p?.className ?? '',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: colors.onAccent.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p?.studentId ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onAccent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disc(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 数据卡：标题 + 上次刷新相对时间 + 刷新按钮（加载态转圈）
class _DataCard extends StatelessWidget {
  const _DataCard({required this.store});

  final AppStore store;

  Future<void> _onRefresh(BuildContext context) async {
    await store.refresh();
    if (!context.mounted) return;
    final toast = store.toast;
    if (toast != null) {
      store.consumeToast();
      AppToast.show(context, toast, long: true, warning: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final busy = store.refreshState == RefreshState.busy;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上次刷新：${store.snapshot.stats.refreshAgoText()}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 88,
            height: 38,
            child: FilledButton(
              onPressed: busy ? null : () => _onRefresh(context),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                disabledBackgroundColor: colors.accent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: colors.onAccent,
                      ),
                    )
                  : Text(
                      '刷新',
                      style: TextStyle(fontSize: 15, color: colors.onAccent),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 大号统计卡（已修 / 应修学分）
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colors.brandGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// 常用功能：成绩查询 / 考试安排
class _FunctionCard extends StatelessWidget {
  const _FunctionCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
            child: CardTitle('常用功能'),
          ),
          _FunctionRow(
            icon: Icons.description_outlined,
            label: '成绩查询',
            desc: '查看历年成绩与学分',
            onTap: () => Navigator.of(context).pushNamed('/grade'),
          ),
          const IndentedDivider(indent: 66),
          _FunctionRow(
            icon: Icons.schedule_outlined,
            label: '考试安排',
            desc: '查看考试时间与考场',
            onTap: () => Navigator.of(context).pushNamed('/exam'),
          ),
        ],
      ),
    );
  }
}

class _FunctionRow extends StatelessWidget {
  const _FunctionRow({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 15, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日课程卡
class _TodayCoursesCard extends StatelessWidget {
  const _TodayCoursesCard({required this.courses, required this.synced});

  final List<ScheduleCourse> courses;
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SectionCard(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 6),
            child: CardTitle(
              '今日课程',
              trailing: Text(
                weekdayLabel(todayWeekday()),
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          ),
          if (courses.isEmpty)
            EmptyHint(synced ? '今天没有课' : '课表未同步：教务系统需要校园网关验证')
          else
            for (var i = 0; i < courses.length; i++) ...[
              _CourseRow(course: courses[i]),
              if (i != courses.length - 1) const IndentedDivider(indent: 31),
            ],
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course});

  final ScheduleCourse course;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${course.timeText} · ${course.teacher} · ${course.place}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
