import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 把页面上某块内容截成 PNG 再分享（对齐原版 `ShareUtil.buildImageFileUri` +
/// `componentSnapshot.get(id, { scale: 2 })` 的口径）。
///
/// 原版用 `componentSnapshot` 截「长图 + 纯文本」一起分享；Flutter 侧对应
/// `RenderRepaintBoundary.toImage(pixelRatio: 2)`，图片落到临时目录（系统会清理）。
Future<String?> captureBoundaryPng(
  GlobalKey boundaryKey,
  String fileName, {
  double pixelRatio = 2,
}) async {
  final object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  } finally {
    image.dispose();
  }
}

/// 分享「长图 + 文本」；截不到图就退回纯文本（不打断分享动作）
Future<void> shareBoundaryImage({
  required GlobalKey boundaryKey,
  required String fileName,
  required String subject,
  required String text,
}) async {
  try {
    final path = await captureBoundaryPng(boundaryKey, fileName);
    if (path != null) {
      await SharePlus.instance.share(
        ShareParams(
          subject: subject,
          text: text,
          files: [XFile(path, mimeType: 'image/png')],
        ),
      );
      return;
    }
  } catch (_) {
    // 截图失败（未渲染完 / 平台不支持）走下面的纯文本
  }
  await SharePlus.instance.share(ShareParams(subject: subject, text: text));
}
