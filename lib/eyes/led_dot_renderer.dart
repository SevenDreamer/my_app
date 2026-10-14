//! LED 点阵样式：EyeRenderer 的第一个实现
//!
//! 长相定义（模板位图、瞳孔参数）与画法（方形灯珠、柔光晕、
//! 灯珠随机翻转过渡）全部内聚在本文件——换样式时整文件替换即可，
//! 逻辑层与其他文件不需要知道灯珠的存在。
import 'package:flutter/material.dart';

import '../expressions.dart';
import 'eye_renderer.dart';

class LedDotRenderer extends EyeRenderer {
  const LedDotRenderer({this.color = const Color(0xFF00E5FF)});

  /// LED 主色，默认青色
  final Color color;

  /// 单眼点阵列数/行数
  static const int _cols = 15;
  static const int _rows = 11;

  /// 两眼之间空出的灯珠列数
  static const int _gapCols = 5;

  /// 每个表情的眼眶点阵模板：_rows 行、每行 _cols 个字符，'#'=点亮
  /// （右眼渲染时水平镜像，无需单独定义）
  static const Map<ExpressionType, List<String>> _outlines = {
    ExpressionType.neutral: [
      '.......#.......',
      '...#########...',
      '..###########..',
      '.#############.',
      '.#############.',
      '###############',
      '.#############.',
      '.#############.',
      '..###########..',
      '...#########...',
      '.......#.......',
    ],
    ExpressionType.happy: [
      // 月牙笑眼 ⌒：抛物弧线，两端下垂；自带形状故无瞳孔
      '...............',
      '...............',
      '...............',
      '...............',
      '...............',
      '......###......',
      '.....#####.....',
      '.....##.##.....',
      '....#.....#....',
      '....#.....#....',
      '...#.......#...',
    ],
    ExpressionType.surprised: [
      // 眼眶睁大
      '.....#####.....',
      '...#########...',
      '.#############.',
      '.#############.',
      '###############',
      '###############',
      '###############',
      '.#############.',
      '.#############.',
      '...#########...',
      '.....#####.....',
    ],
    ExpressionType.angry: [
      // 眼眶内侧下压（剪切倾斜），右眼镜像后自然形成皱眉 V 形
      '........######.',
      '......########.',
      '.....#########.',
      '....##########.',
      '...###########.',
      '..###########..',
      '.###########...',
      '.##########....',
      '.#########.....',
      '.########......',
      '.######........',
    ],
    ExpressionType.sleepy: [
      // 半闭眼
      '.......#.......',
      '...#########...',
      '..###########..',
      '.#############.',
      '.#############.',
      '###############',
      '.#############.',
      '...............',
      '...............',
      '...............',
      '...............',
    ],
    ExpressionType.love: [
      // 心形瞳孔（模板自带形状）
      '..###.....###..',
      '.#####...#####.',
      '###############',
      '###############',
      '###############',
      '.#############.',
      '..###########..',
      '...#########...',
      '....#######....',
      '.....#####.....',
      '......###......',
    ],
    ExpressionType.dead: [
      // ×_× 死机眼
      '.#...........#.',
      '.##.........##.',
      '..###.....###..',
      '...###...###...',
      '.....##.##.....',
      '......###......',
      '.....##.##.....',
      '...###...###...',
      '..###.....###..',
      '.##.........##.',
      '.#...........#.',
    ],
    ExpressionType.smug: [
      // 眯得更狠
      '.......#.......',
      '...#########...',
      '..###########..',
      '.#############.',
      '.#############.',
      '...............',
      '...............',
      '...............',
      '...............',
      '...............',
      '...............',
    ],
  };

  /// 每个表情的瞳孔参数：(半径, 固定偏置)，半径 0 = 不画瞳孔
  static const Map<ExpressionType, (double, Offset)> _pupils = {
    ExpressionType.neutral: (2.4, Offset.zero),
    ExpressionType.happy: (0, Offset.zero),
    ExpressionType.surprised: (1.6, Offset.zero),
    ExpressionType.angry: (1.8, Offset.zero),
    ExpressionType.sleepy: (2.2, Offset(0, 1.2)), // 瞳孔下垂
    ExpressionType.love: (0, Offset.zero),
    ExpressionType.dead: (0, Offset.zero),
    ExpressionType.smug: (2.2, Offset(2.2, -0.6)), // 瞳孔瞟向内侧
  };

  @override
  void paint(Canvas canvas, Size size, EyeVisualState state) {
    final double gap = size.width / (_cols * 2 + _gapCols);
    final double radius = gap * 0.34;
    final double gridH = _rows * gap;
    final double top = (size.height - gridH) / 2;

    // 单眼几何中心（小数坐标，便于瞳孔平滑移动）
    const double cx = (_cols - 1) / 2;
    const double cy = (_rows - 1) / 2;

    // 瞳孔参数随过渡插值
    final (double rFrom, Offset bFrom) = _pupils[state.fromType]!;
    final (double rTo, Offset bTo) = _pupils[state.toType]!;
    final double pupilRadius =
        rFrom + (rTo - rFrom) * state.transition;
    final Offset pupilBias =
        Offset.lerp(bFrom, bTo, state.transition)!;

    for (int eye = 0; eye < 2; eye++) {
      final bool mirror = eye == 1; // 右眼模板水平镜像
      final double originX = eye * (_cols + _gapCols) * gap;
      final List<String> fromMap = _outlines[state.fromType]!;
      final List<String> toMap = _outlines[state.toType]!;

      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          final double x = originX + (c + 0.5) * gap;
          final double y = top + (r + 0.5) * gap;

          // --- 眨眼裁剪：亮区向中线收缩 ---
          final double half = (_rows / 2) * (1 - state.blink);
          final bool blinkOff = (r - cy).abs() > half + 0.5;

          // --- 模板采样：右眼用镜像列号 ---
          final int sc = mirror ? _cols - 1 - c : c;
          final bool onFrom = fromMap[r][sc] == '#';
          final bool onTo = toMap[r][sc] == '#';
          // 随机灯珠翻转过渡：同一格每次用固定 hash 决定何时翻，
          // 切换时呈现 LED 屏"颗粒闪变"的质感，而非整块跳变
          final double h = ((sc * 31 + r * 17) % 97) / 97.0;
          final bool on = h < state.transition ? onTo : onFrom;

          // --- 瞳孔叠加：屏幕坐标不镜像（两眼视线同向），
          //     表情固有偏置则左右对称镜像 ---
          final double px = cx +
              state.look.dx * _cols * 0.30 +
              (mirror ? -pupilBias.dx : pupilBias.dx);
          final double py = cy + state.look.dy * _rows * 0.30 + pupilBias.dy;
          final double pdx = c - px;
          final double pdy = r - py;
          final bool inPupil = pupilRadius > 0 &&
              !blinkOff &&
              pdx * pdx + pdy * pdy <= pupilRadius * pupilRadius;

          // --- 分级亮度绘制：方形灯珠 + 圆形柔光晕 ---
          if (on && !blinkOff && inPupil) {
            // 光晕用柔和的圆形扩散，灯珠本体是方形（像素 LED 观感）
            canvas.drawCircle(
                Offset(x, y), radius * 2.6, Paint()..color = color.withAlpha(36));
            canvas.drawCircle(
                Offset(x, y), radius * 1.7, Paint()..color = color.withAlpha(90));
            _drawSquare(canvas, x, y, radius, color.withAlpha(255));
          } else if (on && !blinkOff) {
            _drawSquare(canvas, x, y, radius, color.withAlpha(105));
          } else {
            // 熄灭的灯珠底座：极暗的方块，保留面板颗粒感
            _drawSquare(canvas, x, y, radius, color.withAlpha(14));
          }
        }
      }
    }
  }

  /// 画一颗方形灯珠：以 (x,y) 为中心、边长 2*radius 的正方形
  void _drawSquare(
      Canvas canvas, double x, double y, double radius, Color color) {
    final double side = radius * 2.05;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: side, height: side),
      Paint()..color = color,
    );
  }
}
