//! 眼睛渲染抽象层：定义"逻辑层每帧产出什么"与"样式层怎么画"的契约
//!
//! 分层思想：
//!   逻辑层（widgets/led_eyes.dart）负责动画与状态，产出 EyeVisualState；
//!   样式层实现 EyeRenderer 接口，只管把 state 画出来。
//!   换眼睛样式 = 新写一个 EyeRenderer 实现，逻辑层零改动。
import 'dart:ui';

import '../expressions.dart';

/// 演出指令：逻辑层每帧产出、样式层照着画的完整画面状态
class EyeVisualState {
  const EyeVisualState({
    required this.look,
    required this.blink,
    required this.fromType,
    required this.toType,
    required this.transition,
  });

  /// 视线方向，分量 -1..1（已平滑，瞳孔/眼球随之偏移）
  final Offset look;

  /// 眨眼程度：0=睁开，1=闭合
  final double blink;

  /// 表情过渡的起点/终点语义（0..1 由 transition 给出进度）
  final ExpressionType fromType;
  final ExpressionType toType;
  final double transition;

  @override
  bool operator ==(Object other) {
    return other is EyeVisualState &&
        other.look == look &&
        other.blink == blink &&
        other.fromType == fromType &&
        other.toType == toType &&
        other.transition == transition;
  }

  @override
  int get hashCode => Object.hash(look, blink, fromType, toType, transition);
}

/// 眼睛样式渲染器接口：任何视觉风格（灯珠点阵、卡通圆眼、像素方块……）
/// 实现本接口即可接入同一套表情/视线/眨眼逻辑。
abstract class EyeRenderer {
  const EyeRenderer();

  /// 风格显示名（右键菜单里展示）
  String get name;

  /// 绘制双眼。这是样式层唯一的入口，画布尺寸由逻辑层给出。
  void paint(Canvas canvas, Size size, EyeVisualState state);
}
