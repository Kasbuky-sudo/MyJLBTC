import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/sub_page.dart';

/// 个人信息（二级页）：完整学籍，按「基本信息 / 学业信息 / 联系方式 / 家庭与来源」分组。
///
/// 版式对齐原版：顶部头像卡（渐变圆 + 姓名 + 学号 + 学籍状态/校区胶囊）、
/// 分组标题在卡片**外**（灰色小字）、行内 value 右对齐、长文本点一下展开。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).snapshot.profile;
    if (profile == null) {
      return const SubPageScaffold(
        title: '个人信息',
        subtitle: '示例学院 · 学籍信息',
        children: [
          SectionCard(
            child: EmptyHint('还没有学籍数据：登录后刷新即可同步', padding: EdgeInsets.zero),
          ),
        ],
      );
    }

    final groups = <(String, List<(String, String)>)>[
      (
        '基本信息',
        [
          ('姓名', profile.name ?? ''),
          ('学号', profile.studentId ?? ''),
          ('性别', profile.sex ?? ''),
          ('民族', profile.nation ?? ''),
          ('出生日期', profile.birth ?? ''),
          ('身份证号', profile.maskedIdCard ?? ''),
        ],
      ),
      (
        '学业信息',
        [
          ('学籍状态', profile.status ?? ''),
          ('学院', profile.college ?? ''),
          ('专业', profile.major ?? ''),
          ('班级', profile.className ?? ''),
          ('班级人数', profile.classSize ?? ''),
          ('校区', profile.campus ?? ''),
          ('学制', profile.duration ?? ''),
          ('入学年级', profile.enrollYear ?? ''),
          ('预计毕业', profile.graduateAt ?? ''),
        ],
      ),
      (
        '联系方式',
        [
          ('手机号', profile.phone ?? ''),
          ('邮箱', profile.email ?? ''),
          ('QQ', profile.qq ?? ''),
          ('微信', profile.wechat ?? ''),
        ],
      ),
      (
        '家庭与来源',
        [
          ('家庭住址', profile.homeAddr ?? ''),
          ('家庭电话', profile.homePhone ?? ''),
          ('毕业中学', profile.middleSchool ?? ''),
          ('考生号', profile.examNo ?? ''),
          ('录取通知书号', profile.admissionNo ?? ''),
        ],
      ),
    ];

    final children = <Widget>[
      _AvatarCard(profile: profile),
      for (final group in groups) ...[
        _GroupHeader(group.$1),
        _GroupCard(rows: group.$2),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '数据来自学校教务系统 · 点击长文本可展开',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColor.of(context).placeholder,
          ),
        ),
      ),
    ];

    return SubPageScaffold(
      title: '个人信息',
      subtitle: '示例学院 · 学籍信息',
      children: children,
    );
  }
}

/// 顶部头像卡：渐变圆（姓氏一字）+ 姓名 + 学号 + 学籍状态 / 校区胶囊
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.profile});

  final ProfileView profile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final name = profile.name ?? '';
    final status = (profile.status ?? '').isEmpty ? '在读' : profile.status!;
    final campus = profile.campus ?? '';

    return SectionCard(
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.profileFrom, colors.profileTo],
              ),
            ),
            child: Text(
              name.isEmpty ? '学' : name.substring(0, 1),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: colors.onAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? '待同步' : name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          if ((profile.studentId ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.studentId!,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Pill(text: status, color: colors.brandGreen),
              if (campus.isNotEmpty) ...[
                const SizedBox(width: 6),
                _Pill(text: campus, color: colors.textSecondary),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

/// 分组标题（卡片外）
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColor.of(context).textSecondary,
        ),
      ),
    );
  }
}

/// 分组卡片：每组一张白卡，行内 value 右对齐
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _ProfileRow(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1) const IndentedDivider(),
          ],
        ],
      ),
    );
  }
}

/// 一行「标签 ｜ 值（右对齐）」；长文本点一下展开
class _ProfileRow extends StatefulWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final empty = widget.value.isEmpty;
    final expandable = widget.value.length > 24;

    return InkWell(
      onTap: expandable
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  widget.label,
                  style: TextStyle(fontSize: 15, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  empty ? '—' : widget.value,
                  textAlign: TextAlign.end,
                  maxLines: _expanded ? 4 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: empty ? colors.placeholder : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
