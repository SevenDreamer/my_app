//! 表情选择菜单：右键/长按弹出的表情与风格切换项
//!
//! ShadContextMenuRegion 的 items 构造器（零 Material）。
//! 菜单本身是 UI 控件而非"输入源"，但选择结果走同一条表情命令通道
//! （onPick，null=随机），与键盘命令源殊途同归。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../expressions.dart';

/// 构造表情菜单项：表情列表 + 随机 + 切换风格
List<ShadContextMenuItem> buildExpressionMenuItems({
  required void Function(ExpressionType? command) onPick,
  required VoidCallback onSwitchStyle,
  String currentStyleName = '',
}) {
  return [
    for (final t in ExpressionType.values)
      ShadContextMenuItem(
        onPressed: () => onPick(t),
        child: Text('${t.index + 1}. ${t.label}'),
      ),
    ShadContextMenuItem(
      onPressed: () => onPick(null),
      child: const Text('🎲 随机'),
    ),
    ShadContextMenuItem(
      onPressed: onSwitchStyle,
      child: Text('🎨 切换风格（当前：$currentStyleName）'),
    ),
  ];
}
