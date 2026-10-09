import 'package:flutter/material.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 考试安排（二级页）：学期 / 批次下拉筛选 + 每场考试一张卡片。
///
/// 版式对齐原版：标题栏主副标题、两个胶囊下拉 +「N 场」计数、
/// 卡片 = 彩色课程名 + 右上角状态胶囊 + 五行 label:value。
class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  String? _term;
  String? _batch;

  @override
  Widget build(BuildContext context) {
    final snapshot = AppScope.of(context).snapshot;
    final colors = AppColor.of(context);
    final terms = snapshot.examTerms;
    final term = _term ?? (terms.isNotEmpty ? terms.first : '');
    final batches = term.isEmpty ? const <String>[] : snapshot.examBatchesOf(term);
    final batch = _batch ?? (batches.isNotEmpty ? batches.first : allBatches);
    final records = term.isEmpty ? const <ExamRecord>[] : snapshot.examsOf(term, batch);

    return SubPageScaffold(
      title: '考试安排',
      subtitle: term.isEmpty ? '' : termLabel(termYear(term), termSemester(term)),
      children: [
        if (terms.isEmpty)
          const SectionCard(
            child: EmptyHint('还没有考试数据：登录后刷新即可同步', padding: EdgeInsets.zero),
          )
        else ...[
          // 筛选：学期下拉 + 批次下拉，右侧场次计数（窄屏可横滑）
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChipButton(
                        label: '$term 学期',
                        options: terms,
                        selected: term,
                        menuLabel: (t) => '$t 学期',
                        onSelected: (value) => setState(() {
                          _term = value;
                          _batch = null;
                        }),
                      ),
                      const SizedBox(width: 10),
                      FilterChipButton(
                        label: _batchLabel(batch, term),
                        options: batches,
                        selected: batch,
                        onSelected: (value) => setState(() => _batch = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${records.length} 场',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
          if (records.isEmpty)
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 34,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '该学期暂无考试安排',
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '学校还没排考，或你的名下暂无考试',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < records.length; i++)
              _ExamCard(record: records[i], colorIndex: i),
        ],
      ],
    );
  }

  /// 批次胶囊只显示批次名（去掉学期前缀，否则太长）
  static String _batchLabel(String batch, String term) {
    if (batch == allBatches) return batch;
    if (batch.startsWith(term)) return batch.substring(term.length);
    return batch;
  }
}

/// 课程名配色：和学校页面一样轮转（绿 / 橙 / 红）
Color _courseColor(AppColor colors, int index) {
  switch (index % 3) {
    case 0:
      return colors.brandGreen;
    case 1:
      return colors.warning;
    default:
      return colors.danger;
  }
}

/// 距离考试的状态文案与配色
Color _statusColor(AppColor colors, int? days) {
  if (days == null || days < 0) return colors.textSecondary;
  if (days == 0) return colors.danger;
  if (days <= 3) return colors.warning;
  return colors.accent;
}

String _statusText(int? days) {
  if (days == null) return '';
  if (days < 0) return '已结束';
  if (days == 0) return '今天';
  return '还有 $days 天';
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.record, required this.colorIndex});

  final ExamRecord record;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final days = record.daysUntil;
    final status = _statusText(days);

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    record.course,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _courseColor(colors, colorIndex),
                    ),
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chipBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(colors, days),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const IndentedDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _InfoRow(label: '考试时间', value: record.time),
                _InfoRow(label: '考试地址', value: record.place),
                _InfoRow(label: '考试批次', value: record.batch),
                _InfoRow(label: '考场座位号', value: record.seat),
                _InfoRow(label: '考试方式', value: record.method, last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行「标签：值」（原版五行固定顺序，值为空显示 —）
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final empty = value.isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // 104：够放「考场座位号：」一行（中文全角 7 字 × 14 = 98）
            width: 104,
            child: Text(
              '$label：',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              empty ? '—' : value,
              style: TextStyle(
                fontSize: 14,
                color: empty ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
