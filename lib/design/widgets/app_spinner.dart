//! 加载转圈（纯 CustomPaint 自绘——去 Material 化的 CircularProgressIndicator）
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens.dart';

class AppSpinner extends StatefulWidget {
  const AppSpinner({super.key, this.size = 20, this.strokeWidth = 2});

  final double size;
  final double strokeWidth;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _ArcPainter(_ctrl.value, widget.strokeWidth),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.progress, this.strokeWidth);
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    canvas.drawArc(rect.deflate(strokeWidth / 2), progress * 2 * math.pi,
        1.8 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}
