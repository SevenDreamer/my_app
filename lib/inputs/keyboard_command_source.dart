//! 键盘表情命令源：数字键 1~8 直选表情，空格随机
//!
//! 通过 build 返回的 Focus 包装组件接管键盘事件（桌面端主用）；
//! 移动端未来可在此并列添加手势/语音/表情识别等命令源。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expressions.dart';
import 'expression_command_source.dart';

class KeyboardCommandSource extends ExpressionCommandSource {
  KeyboardCommandSource();

  void Function(ExpressionType? command)? _onCommand;

  @override
  void start(void Function(ExpressionType? command) onCommand) {
    _onCommand = onCommand;
  }

  @override
  void stop() => _onCommand = null;

  @override
  Widget build(Widget child) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }

  /// 键盘映射：1~8 与表情枚举按顺序对应，空格=随机
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final onCommand = _onCommand;
    if (onCommand == null) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      onCommand(null); // null = 随机
      return KeyEventResult.handled;
    }
    const digitKeys = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
    ];
    for (int i = 0;
        i < digitKeys.length && i < ExpressionType.values.length;
        i++) {
      if (event.logicalKey == digitKeys[i]) {
        onCommand(ExpressionType.values[i]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
