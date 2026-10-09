import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 轻提示：**Android 上用系统原生 Toast**（`android.widget.Toast`），其他平台退回
/// Flutter 自己画的提示条（桌面只是开发画板）。
///
/// 原生 Toast 的好处：不受应用内层叠/玻璃影响、跟随系统深浅色与字号、不会挡住按钮。
class AppToast {
  AppToast._();

  static const MethodChannel _channel = MethodChannel(
    'com.anlanas.myjlbtc/native',
  );

  /// 短提示（默认 2 秒；`long` 走系统 LENGTH_LONG）
  static Future<void> show(
    BuildContext context,
    String message, {
    bool long = false,
    bool warning = false,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('toast', {
          'message': message,
          'long': long,
        });
        return;
      } catch (_) {
        // 通道不可用（如单测环境）就退回 Flutter 提示
      }
    }
    if (!context.mounted) return;
    GlassToast.show(
      context,
      message: message,
      type: warning ? GlassToastType.warning : GlassToastType.info,
      duration: Duration(seconds: long ? 3 : 2),
    );
  }
}
