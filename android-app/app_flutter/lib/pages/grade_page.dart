import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/share_image.dart';
import '../widgets/sub_page.dart';

/// 成绩查询（二级页）：学年 / 学期下拉筛选 + 学期统计 + 成绩列表。
///
/// 版式对齐原版：标题栏主副标题、两个胶囊下拉、统计卡中间竖分隔线、
/// 列表卡内标题行（学期 + N 门）、成绩行三列（课名/课号 ｜ 绩点/学分 ｜ 成绩）。
class GradePage extends StatefulWidget {
  const GradePage({super.key});

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  String? _year;
  String? _semester;

  /// 分享长图的边界（原版 `componentSnapshot.get('gradeContent')` 的对应物）
  final GlobalKey _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final snapshot = AppScope.of(context).snapshot;
    final colors = AppColor.of(context);
    final years = snapshot.gradeYears;
    // 默认选中「最新一条成绩所在的学年学期」（有数据的学期），不是学年列表第一项
    final latestTerm = snapshot.grades.isNotEmpty ? snapshot.grades.first.term : '';
    final year = _year ??
        (latestTerm.isNotEmpty
            ? termYear(latestTerm)
            : (years.isNotEmpty ? years.first : ''));
    final semester = _semester ??
        (latestTerm.isNotEmpty ? termSemester(latestTerm) : '1');
    final records = snapshot.gradesOf(year, semester);
    final hasData = years.isNotEmpty;

    return SubPageScaffold(
      title: '成绩查询',
      subtitle: termLabel(year, semester),
      actions: [
        // 右上角分享（玻璃按钮）
        GlassIconButton(
          onPressed: () => _share(context, year, semester, records),
          icon: Icon(
            Icons.ios_share_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
        ),
      ],
      children: [
        if (!hasData)
          const SectionCard(
            child: EmptyHint('还没有成绩数据：登录后刷新即可同步', padding: EdgeInsets.zero),
          )
        else ...[
          // 分享长图的区域（对齐原版 `id('gradeContent')`：筛选 + 统计 + 列表 + 落款）
          Container(
            color: colors.pageBg,
            child: RepaintBoundary(
              key: _shareKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 筛选：两个胶囊下拉（窄屏可横滑，长文案不挤压）
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChipButton(
                          label: '$year 学年',
                          options: years,
                          selected: year,
                          menuLabel: (y) => '$y 学年',
                          onSelected: (value) => setState(() {
                            _year = value;
                            _semester = null; // 换学年时重挑默认学期
                          }),
                        ),
                        const SizedBox(width: 10),
                        FilterChipButton(
                          label: '第 $semester 学期',
                          options: const ['1', '2'],
                          selected: semester,
                          menuLabel: (s) => '第 $s 学期',
                          onSelected: (value) =>
                              setState(() => _semester = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 概览：统计口径随筛选变化
                  SectionCard(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        _StatCell(label: '课程数', value: '${records.length}'),
                        _statDivider(colors),
                        _StatCell(
                          label: '学分',
                          value: _trim(creditSumOf(records)),
                        ),
                        _statDivider(colors),
                        _StatCell(label: '绩点', value: _trim(gpaOf(records))),
                        _statDivider(colors),
                        _StatCell(
                          label: '平均分',
                          value: _trim(averageOf(records)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (records.isEmpty)
                    SectionCard(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 34,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '该学期暂无成绩数据',
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '换个学年或学期看看',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SectionCard(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Column(
                        children: [
                          // 卡内标题行：学期 + 门数
                          SizedBox(
                            height: 50,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      termLabel(year, semester),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${records.length} 门',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (var i = 0; i < records.length; i++) ...[
                            _GradeRow(record: records[i]),
                            if (i != records.length - 1)
                              const IndentedDivider(),
                          ],
                        ],
                      ),
                    ),

                  // 分享长图的落款
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      '来自 MyJLBTC App',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: colors.placeholder),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statDivider(AppColor colors) => Container(
    width: 1,
    height: 28,
    color: colors.divider,
  );

  void _share(
    BuildContext context,
    String year,
    String semester,
    List<GradeRecord> records,
  ) {
    final term = termLabel(year, semester);
    final nl = String.fromCharCode(10);
    final body = StringBuffer();
    for (final r in records) {
      final point = r.gradePoint.isNotEmpty
          ? '（绩点 ${r.gradePoint} · ${r.credit} 学分）'
          : '';
      body.write('${r.name}：${r.grade}$point$nl');
    }
    final head =
        '【成绩查询】$term'
        '$nl共 ${records.length} 门课程 · '
        '平均分 ${_trim(averageOf(records))} · 绩点 ${_trim(gpaOf(records))}';
    // 长图 + 全文（与原版 ShareUtil.buildImageData 的口径一致）
    shareBoundaryImage(
      boundaryKey: _shareKey,
      fileName: 'grade_${year}_$semester.png',
      subject: 'MyJLBTC 成绩查询',
      text: '$head$nl$nl$body$nl来自 MyJLBTC App',
    );
  }

  static String _trim(double value) {
    if (value == 0) return '0';
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00')
        ? text.substring(0, text.length - 3)
        : (text.endsWith('0') ? text.substring(0, text.length - 1) : text);
  }
}

/// 统计格：数值在上（20 号加粗）、标签在下（12 号灰）
class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.record});

  final GradeRecord record;

  /// 分数自动分档：≥85 绿 / ≥75 紫 / ≥60 橙 / <60 红；等级制按档位映射
  static Color gradeColor(BuildContext context, String grade) {
    final colors = AppColor.of(context);
    final value = double.tryParse(grade.trim());
    if (value != null) {
      if (value >= 85) return colors.brandGreen;
      if (value >= 75) return colors.accent;
      if (value >= 60) return colors.warning;
      return colors.danger;
    }
    switch (grade) {
      case '优秀':
      case '良好':
        return colors.brandGreen;
      case '中等':
        return colors.accent;
      case '及格':
        return colors.warning;
      default:
        return colors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 第 1 列：课名（可 2 行）+ 补考/重修标记，下面课号
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // 补考 / 缓考补考 / 重修：教务按同一门课另记一行
                    if (record.tag.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.tag,
                          style: TextStyle(fontSize: 10, color: colors.accent),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.code,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 第 2 列：绩点（值在上、标签在下）
          _ValueCell(
            value: record.gradePoint,
            label: '绩点',
          ),
          // 第 3 列：学分
          _ValueCell(
            value: record.credit,
            label: '学分',
          ),
          // 第 4 列：成绩（按档配色，右对齐）
          SizedBox(
            width: 52,
            child: Text(
              record.grade.isEmpty ? '—' : record.grade,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: gradeColor(context, record.grade),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 绩点 / 学分小列
class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.placeholder),
          ),
        ],
      ),
    );
  }
}
