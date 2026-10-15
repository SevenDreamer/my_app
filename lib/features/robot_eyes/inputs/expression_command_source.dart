//! 表情命令输入抽象层：把外界输入翻译成"切换表情"的请求
//!
//! 与视线输入（look_source.dart）对称：键盘、未来的手势/语音/表情识别
//! 都实现 ExpressionCommandSource，向页面层投递语义命令。
import 'package:flutter/material.dart';

import '../expressions.dart';

/// 表情命令源接口
abstract class ExpressionCommandSource {
  const ExpressionCommandSource();

  /// 开始产出命令；命令为表情语义，null 表示"随机来一个"
  void start(void Function(ExpressionType? command) onCommand);

  /// 停止产出并释放资源
  void stop();

  /// 需要挂进 widget 树的源（如键盘焦点）返回包装组件；纯逻辑源原样返回
  Widget build(Widget child) => child;
}
