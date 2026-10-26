//! 视线输入抽象层：定义"外界输入如何变成视线方向"的契约与仲裁中枢
//!
//! 分层思想（与 eyes/ 的样式抽象对称）：
//!   输入源（PointerLookSource / IdleLookSource / 未来的 CameraGazeSource）
//!   只做一件事——把自己那种输入翻译成视线方向（-1..1）投递给 LookSink；
//!   LookInputHub 按优先级仲裁出唯一视线，喂给逻辑层。
//!   多源规则：手动拖动 > 摄像头眼动 > idle 乱瞟（数值大的优先级胜出）。
import 'package:flutter/widgets.dart';

/// 视线提交句柄：输入源通过它向中枢投递视线
abstract class LookSink {
  /// 投递视线目标（持续值：保持到下一次 submit/clear）
  void submit(Offset look);

  /// 释放视线（自己的槽清空，让位给其他源）
  void clear();

  /// 是否被更高优先级的输入遮蔽——源可据此暂停自己（省电/避免抢戏）
  bool get isObscured;
}

/// 视线输入源接口：鼠标/触摸、摄像头眼动、陀螺仪……都实现它
abstract class LookSource {
  const LookSource();

  /// 开始产出视线（通过 sink 投递）
  void start(LookSink sink);

  /// 停止产出并释放资源
  void stop();

  /// 需要挂进 widget 树的源（如手势识别）返回包装组件；纯逻辑源原样返回
  Widget build(Widget child) => child;
}

/// 视线输入中枢：每个源占一个优先级槽位，仲裁出唯一视线目标
class LookInputHub {
  LookInputHub({this.onChanged});

  /// 仲裁结果变化时回调（页面层据此刷新）
  final void Function()? onChanged;

  /// priority -> 该源最近一次提交的视线（持续值）
  final Map<int, Offset> _slots = {};

  Offset _current = Offset.zero;

  /// 当前生效的视线目标：最高优先级槽位的值，全空则回正中
  Offset get current => _current;

  /// 为某个优先级取一个提交句柄
  LookSink sink(int priority) => _HubSink(this, priority);

  void _submit(int priority, Offset look) {
    _slots[priority] = look;
    _recompute();
  }

  void _clear(int priority) {
    _slots.remove(priority);
    _recompute();
  }

  bool _isObscured(int priority) {
    for (final entry in _slots.entries) {
      if (entry.key > priority && entry.value != Offset.zero) return true;
    }
    return false;
  }

  /// 仲裁：数值大的优先级胜出；全空时回到正中
  void _recompute() {
    Offset best = Offset.zero;
    int bestPriority = -1;
    _slots.forEach((priority, look) {
      if (priority > bestPriority) {
        bestPriority = priority;
        best = look;
      }
    });
    if (best != _current) {
      _current = best;
      onChanged?.call();
    }
  }
}

/// LookSink 的内部实现：绑定一个优先级槽位
class _HubSink implements LookSink {
  _HubSink(this._hub, this._priority);

  final LookInputHub _hub;
  final int _priority;

  @override
  void submit(Offset look) => _hub._submit(_priority, look);

  @override
  void clear() => _hub._clear(_priority);

  @override
  bool get isObscured => _hub._isObscured(_priority);
}
