//! 指针视线源：鼠标/触摸拖动 → 视线方向（最高优先级，手动接管）
//!
//! 拖动中把指针位置归一化成 -1..1 投递给中枢；松手释放槽位，
//! 视线回落给其他源（无其他源时回正中）。
import 'package:flutter/material.dart';

import 'look_source.dart';

class PointerLookSource extends LookSource {
  PointerLookSource();

  LookSink? _sink;

  /// 手势区域尺寸（归一化用），由 build 内的 LayoutBuilder 维护
  Size _size = Size.zero;

  @override
  void start(LookSink sink) => _sink = sink;

  @override
  void stop() => _sink = null;

  @override
  Widget build(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onDrag,
          onPanUpdate: _onDrag,
          onPanEnd: (_) => _sink?.clear(), // 松手让位
          onPanCancel: () => _sink?.clear(),
          child: child,
        );
      },
    );
  }

  /// 拖动中：指针位置 → 视线目标（-1..1）
  void _onDrag(dynamic details) {
    final Offset local = details.localPosition as Offset;
    if (_size == Size.zero) return;
    _sink?.submit(Offset(
      (local.dx / _size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / _size.height * 2 - 1).clamp(-1.0, 1.0),
    ));
  }
}
