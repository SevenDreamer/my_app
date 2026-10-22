//! 统一提示（ShadSonner 封装）——替代 Material SnackBar（去 Material 化）
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppToast {
  AppToast._();

  /// 顶部滑出提示（自动消失）
  static void show(BuildContext context, String message) {
    final sonner = ShadSonner.maybeOf(context);
    if (sonner == null) return; // 根节点未挂 ShadSonner 时静默
    sonner.show(ShadToast(description: Text(message)));
  }
}
