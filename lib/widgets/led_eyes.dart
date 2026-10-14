//! 眼睛逻辑层：驱动表情过渡、瞳孔插值与随机眨眼三组动画
//!
//! 本文件不含任何绘制细节：每帧把动画结果打包成 EyeVisualState，
//! 交给注入的 EyeRenderer 去画。眨眼节奏、瞳孔平滑、过渡计时都在这里，
//! 换眼睛样式不影响本文件。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../expressions.dart';
import '../eyes/eye_renderer.dart';

class LedEyes extends StatefulWidget {
  const LedEyes({
    super.key,
    required this.lookTarget,
    required this.type,
    required this.renderer,
  });

  /// 视线目标，分量 -1..1（由页面层给出：idle 随机或指针位置）
  final Offset lookTarget;

  /// 目标表情语义（变化时触发过渡动画）
  final ExpressionType type;

  /// 眼睛样式渲染器（灯珠点阵、卡通圆眼……可插拔）
  final EyeRenderer renderer;

  @override
  State<LedEyes> createState() => _LedEyesState();
}

class _LedEyesState extends State<LedEyes>
    with TickerProviderStateMixin {
  final math.Random _rand = math.Random();

  /// 持续循环的"心跳"：每帧回调一次，推进过渡与瞳孔插值
  late final AnimationController _tick;

  /// 眨眼动画：0=睁眼 1=全闭，一次闭合+张开约 320ms
  late final AnimationController _blinkAnim;

  /// 当前瞳孔实际位置（向 lookTarget 逼近，产生平滑跟随感）
  Offset _pupil = Offset.zero;

  /// 当前眨眼程度 0..1
  double _blink = 0;

  /// 下一次眨眼的随机定时器
  Timer? _blinkTimer;

  /// 表情过渡：fromType→toType，progress 0..1
  /// （声明期给默认值：热重载复用旧 State 实例时 late 字段会炸）
  ExpressionType _fromType = ExpressionType.neutral;
  ExpressionType _toType = ExpressionType.neutral;
  DateTime _transitionStart = DateTime.now();

  /// 表情过渡时长
  static const Duration _transitionDur = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _fromType = widget.type;
    _toType = widget.type;

    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _tick.addListener(_onTick);

    _blinkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(() {
        setState(() => _blink = _blinkAnim.value);
      });

    _scheduleBlink();
  }

  @override
  void didUpdateWidget(covariant LedEyes oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 目标表情变化：从当前表情重新开始过渡
    if (oldWidget.type != widget.type) {
      _fromType = oldWidget.type;
      _toType = widget.type;
      _transitionStart = DateTime.now();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _tick.dispose();
    _blinkAnim.dispose();
    super.dispose();
  }

  /// 每帧：把瞳孔向视线目标插值一小段（与帧率无关的观感）
  void _onTick() {
    setState(() {
      _pupil = Offset.lerp(_pupil, widget.lookTarget, 0.12)!;
    });
  }

  /// 安排下一次眨眼：间隔 1.8~6 秒随机
  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 1800 + _rand.nextInt(4200)),
      _doBlink,
    );
  }

  /// 眨一次眼：快速闭合再睁开，然后安排下一次
  Future<void> _doBlink() async {
    if (!mounted) return;
    await _blinkAnim.forward(); // 眼睑合拢
    await _blinkAnim.reverse(); // 眼睑张开
    _scheduleBlink();
  }

  @override
  Widget build(BuildContext context) {
    // 过渡进度：0=完全 fromType，1=完全 toType
    final double progress = DateTime.now()
        .difference(_transitionStart)
        .inMicroseconds
        .clamp(0, _transitionDur.inMicroseconds) /
        _transitionDur.inMicroseconds;

    // 打包演出指令，交给样式渲染器去画
    final state = EyeVisualState(
      look: _pupil,
      blink: _blink,
      fromType: _fromType,
      toType: _toType,
      transition: progress,
    );

    return CustomPaint(
      painter: _RendererAdapter(widget.renderer, state),
      size: Size.infinite,
    );
  }
}

/// 把 EyeRenderer 适配成 Flutter 的 CustomPainter，桥接两套协议
class _RendererAdapter extends CustomPainter {
  _RendererAdapter(this.renderer, this.state);

  final EyeRenderer renderer;
  final EyeVisualState state;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, state);

  @override
  bool shouldRepaint(_RendererAdapter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.renderer != renderer;
}
