import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/snapshot.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/share_image.dart';
import '../widgets/sub_page.dart';

/// 通知公告列表：全部通知（点进详情）。
class NoticeListPage extends StatelessWidget {
  const NoticeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = AppScope.of(context).snapshot.notices;
    return SubPageScaffold(
      title: '通知公告',
      children: [
        if (notices.isEmpty)
          const SectionCard(child: EmptyHint('还没有通知数据：登录后刷新即可同步', padding: EdgeInsets.zero))
        else
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < notices.length; i++) ...[
                  _NoticeRow(notice: notices[i]),
                  if (i != notices.length - 1) const IndentedDivider(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final NoticeRecord notice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/notice', arguments: notice.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${notice.author} · ${notice.time}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// 通知详情：标题 + 来源时间 + 正文分段 + 落款。
class NoticePage extends StatefulWidget {
  const NoticePage({super.key, required this.id});

  final String id;

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  /// 分享长图的边界（原版 `componentSnapshot.get('noticeContent')` 的对应物）
  final GlobalKey _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final notice = AppScope.of(context).snapshot.noticeById(widget.id);

    if (notice == null) {
      return const SubPageScaffold(
        title: '通知详情',
        children: [SectionCard(child: EmptyHint('通知不存在或已被清理', padding: EdgeInsets.zero))],
      );
    }

    return SubPageScaffold(
      title: '通知详情',
      actions: [
        // 右上角分享（玻璃按钮）：长图 + 全文（对齐原版 ShareUtil.buildImageData）
        GlassIconButton(
          onPressed: () => _share(notice),
          icon: Icon(
            Icons.ios_share_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
        ),
      ],
      children: [
        Container(
          color: colors.pageBg,
          child: RepaintBoundary(
            key: _shareKey,
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${notice.author} · ${notice.time}',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: colors.divider, height: 1),
                  const SizedBox(height: 14),
                  for (final paragraph in notice.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraph,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: colors.textMeta,
                        ),
                      ),
                    ),
                  if (notice.signature.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        notice.signature,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  // 分享长图的落款（原版 in-image 落款同款）
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
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
        ),
      ],
    );
  }

  /// 纯文本分享的内容：**全文**（标题 + 作者时间 + 所有段落 + 落款），与原版一致
  void _share(NoticeRecord notice) {
    final nl = String.fromCharCode(10);
    final head = '【通知公告】${notice.title}$nl${notice.author} ${notice.time}';
    final body = notice.paragraphs.join('$nl$nl');
    shareBoundaryImage(
      boundaryKey: _shareKey,
      fileName: 'notice_${notice.id}.png',
      subject: notice.title,
      text: '$head$nl$nl$body$nl$nl${notice.signature}$nl$nl来自 MyJLBTC App',
    );
  }
}
