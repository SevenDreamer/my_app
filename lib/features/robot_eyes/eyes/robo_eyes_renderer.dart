//! RoboEyes 风格样式：EyeRenderer 的第二个实现（移植 FluxGarage/RoboEyes 的设计）
//!
//! 与 LED 点阵风格并列的另一种长相：实心圆角矩形"屏幕眼"（WALL-E 风），
//! 视线=整块眼睛平移，表情=眼形参数变化（圆角矩形/月牙/心形/叉），
//! 过渡=参数插值（异形之间用透明度交叉淡化）。
//! 换上它只需在页面层替换注入的 renderer，逻辑与输入层零改动。
//!
//! 设计参考：github.com/FluxGarage/RoboEyes（Arduino/OLED 库，MIT）
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../expressions.dart';
import 'eye_renderer.dart';

class RoboEyesRenderer extends EyeRenderer {
  const RoboEyesRenderer({this.color = const Color(0xFF00E5FF)});

  /// 眼睛主色
  final Color color;

  @override
  String get name => 'RoboEyes 屏幕眼';

  /// 每个表情的形状参数表
  static const Map<ExpressionType, _EyeShape> _shapes = {
    ExpressionType.neutral:
        _EyeShape(kind: _ShapeKind.rect, w: 1.0, h: 1.0, radius: 0.45),
    ExpressionType.happy: _EyeShape(kind: _ShapeKind.arc, w: 1.05, h: 1.05),
    ExpressionType.surprised:
        _EyeShape(kind: _ShapeKind.rect, w: 1.05, h: 1.15, radius: 0.5),
    ExpressionType.angry: _EyeShape(
        kind: _ShapeKind.rect, w: 1.0, h: 0.85, radius: 0.3, tilt: 0.28),
    ExpressionType.sleepy: _EyeShape(
        kind: _ShapeKind.rect,
        w: 1.0,
        h: 0.9,
        radius: 0.4,
        lidTop: 0.5,
        lookBias: Offset(0, 0.25)),
    ExpressionType.love: _EyeShape(kind: _ShapeKind.heart, w: 1.0, h: 1.0),
    ExpressionType.dead: _EyeShape(kind: _ShapeKind.cross, w: 0.95, h: 1.0),
    ExpressionType.smug: _EyeShape(
        kind: _ShapeKind.rect,
        w: 1.0,
        h: 0.6,
        radius: 0.5,
        lidTop: 0.25,
        lookBias: Offset(0.35, -0.1)),
  };

  @override
  void paint(Canvas canvas, Size size, EyeVisualState state) {
    // 基准眼形尺寸（与布局里眼睛区域的比例呼应）
    final double eyeW = size.width * 0.30;
    final double eyeH = size.width * 0.34;
    final double gap = size.width * 0.10; // 两眼间距

    final _EyeShape from = _shapes[state.fromType]!;
    final _EyeShape to = _shapes[state.toType]!;
    final double t = state.transition;

    for (int eye = 0; eye < 2; eye++) {
      final bool mirror = eye == 1; // 右眼参数镜像（tilt/偏置对称）
      final double cx =
          size.width / 2 + (eye == 0 ? -1 : 1) * (gap / 2 + eyeW / 2);
      final double cy = size.height / 2;

      // --- 眨眼 + 表情眼睑：裁剪可视高度（对所有形状通用） ---
      final double lidTop = _lerp(from.lidTop, to.lidTop, t) + state.blink;
      final double lidBottom =
          _lerp(from.lidBottom, to.lidBottom, t) + state.blink;
      final double clipTop = cy - eyeH / 2 + lidTop * eyeH;
      final double clipBottom = cy + eyeH / 2 - lidBottom * eyeH;

      // --- 视线：整块眼睛平移（表情固有偏置左右镜像） ---
      final Offset bias = Offset.lerp(
          mirror ? Offset(-from.lookBias.dx, from.lookBias.dy) : from.lookBias,
          mirror ? Offset(-to.lookBias.dx, to.lookBias.dy) : to.lookBias,
          t)!;
      final double dx = state.look.dx * eyeW * 0.18 + bias.dx * eyeW * 0.3;
      final double dy = state.look.dy * eyeH * 0.22 + bias.dy * eyeH * 0.3;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(cx - eyeW, clipTop, cx + eyeW, clipBottom));

      if (from.kind == to.kind) {
        // 同类形状：参数插值，平滑变形
        final s = _EyeShape.lerp(from, to, t, mirror: mirror);
        _paintShape(canvas, cx + dx, cy + dy, eyeW, eyeH, s, 1.0);
      } else {
        // 异类形状（如圆角矩形→心形）：透明度交叉淡化
        _paintShape(canvas, cx + dx, cy + dy, eyeW, eyeH,
            _EyeShape.lerp(from, from, t, mirror: mirror), 1.0 - t);
        _paintShape(canvas, cx + dx, cy + dy, eyeW, eyeH,
            _EyeShape.lerp(to, to, t, mirror: mirror), t);
      }
      canvas.restore();
    }
  }

  /// 按形状种类绘制一只眼（alpha 用于异形过渡的交叉淡化）
  void _paintShape(Canvas canvas, double cx, double cy, double eyeW,
      double eyeH, _EyeShape s, double alpha) {
    if (alpha <= 0.01) return;
    final Paint paint = Paint()..color = color.withAlpha((255 * alpha).round());
    final double w = eyeW * s.w;
    final double h = eyeH * s.h;

    switch (s.kind) {
      case _ShapeKind.rect:
        // 圆角矩形；tilt 用剪切变换把矩形压成平行四边形（生气压眉）
        canvas.save();
        canvas.translate(cx, cy);
        if (s.tilt != 0) {
          // 镜像已在参数插值里处理，这里只管剪切
          canvas.transform(Matrix4.skewY(s.tilt).storage);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(math.min(w, h) * s.radius),
          ),
          paint,
        );
        canvas.restore();
      case _ShapeKind.arc:
        // 月牙笑眼 ⌒：外弧 + 内弧闭合的实心月牙
        final Path path = Path()
          ..moveTo(cx - w / 2, cy + h / 2)
          ..quadraticBezierTo(cx, cy - h * 1.25, cx + w / 2, cy + h / 2)
          ..quadraticBezierTo(cx, cy - h * 0.35, cx - w / 2, cy + h / 2)
          ..close();
        canvas.drawPath(path, paint);
      case _ShapeKind.heart:
        // 心形：两圆瓣 + 贝塞尔下尖
        final Path path = Path()
          ..moveTo(cx, cy + h * 0.55)
          ..cubicTo(cx - w * 0.9, cy - h * 0.15, cx - w * 0.55, cy - h * 0.8,
              cx, cy - h * 0.25)
          ..cubicTo(cx + w * 0.55, cy - h * 0.8, cx + w * 0.9, cy - h * 0.15,
              cx, cy + h * 0.55)
          ..close();
        canvas.drawPath(path, paint);
      case _ShapeKind.cross:
        // ×_× 的叉：两条粗斜线
        final Paint line = paint..strokeWidth = eyeW * 0.16 * s.w;
        line.strokeCap = StrokeCap.round;
        final double r = math.min(w, h) / 2;
        canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), line);
        canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), line);
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 形状种类
enum _ShapeKind { rect, arc, heart, cross }

/// 单只眼的形状参数
class _EyeShape {
  const _EyeShape({
    required this.kind,
    required this.w,
    required this.h,
    this.radius = 0.4,
    this.tilt = 0,
    this.lidTop = 0,
    this.lidBottom = 0,
    this.lookBias = Offset.zero,
  });

  final _ShapeKind kind;

  /// 宽/高倍率（相对基准眼形）
  final double w;
  final double h;

  /// 圆角比例 0..1（仅 rect）
  final double radius;

  /// 剪切量（仅 rect）：内侧眉压低的倾斜
  final double tilt;

  /// 上/下眼睑压下量 0..1
  final double lidTop;
  final double lidBottom;

  /// 表情固有的视线偏置（如困=下垂、得意=瞟一侧）
  final Offset lookBias;

  /// 同类形状之间的参数插值；mirror 时 tilt/偏置取反（右眼对称）
  static _EyeShape lerp(_EyeShape a, _EyeShape b, double t,
      {required bool mirror}) {
    final double sign = mirror ? -1 : 1;
    return _EyeShape(
      kind: t < 0.5 ? a.kind : b.kind,
      w: a.w + (b.w - a.w) * t,
      h: a.h + (b.h - a.h) * t,
      radius: a.radius + (b.radius - a.radius) * t,
      tilt: (a.tilt + (b.tilt - a.tilt) * t) * sign,
      lidTop: a.lidTop + (b.lidTop - a.lidTop) * t,
      lidBottom: a.lidBottom + (b.lidBottom - a.lidBottom) * t,
      lookBias: Offset(a.lookBias.dx + (b.lookBias.dx - a.lookBias.dx) * t,
          a.lookBias.dy + (b.lookBias.dy - a.lookBias.dy) * t),
    );
  }
}
