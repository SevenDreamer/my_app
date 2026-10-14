//! 表情选择菜单：右键弹出的 UI 细节（封装 showMenu 的坐标与回调）
//!
//! 菜单本身是 UI 控件而非"输入源"，但选择结果走同一条表情命令通道
//! （onPick，null=随机），与键盘命令源殊途同归。
import 'package:flutter/material.dart';

import '../expressions.dart';

/// 在 details 位置弹出表情菜单；选表情后回调 onPick（null=随机），
/// 选风格项则回调 onSwitchStyle（循环切换眼睛风格）。
Future<void> showExpressionMenu(
  BuildContext context,
  TapDownDetails details, {
  required void Function(ExpressionType? command) onPick,
  required VoidCallback onSwitchStyle,
  String currentStyleName = '',
}) async {
  final RenderBox box = context.findRenderObject() as RenderBox;
  final selected = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      Offset.zero & box.size,
    ),
    items: [
      for (final t in ExpressionType.values)
        PopupMenuItem<int>(
          value: t.index,
          child: Text('${t.index + 1}. ${t.label}'),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<int>(
        value: -1,
        child: Text('🎲 随机'),
      ),
      PopupMenuItem<int>(
        value: -2,
        child: Text('🎨 切换风格（当前：$currentStyleName）'),
      ),
    ],
  );
  if (selected == null) return; // 点菜单外 = 取消
  if (selected == -2) {
    onSwitchStyle();
  } else {
    onPick(selected == -1 ? null : ExpressionType.values[selected]);
  }
}
