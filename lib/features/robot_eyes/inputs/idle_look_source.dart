//! idle 视线源：随机乱瞟（最低优先级的兜底，让机器人"自己活着"）
//!
//! 每 2.5~5 秒随机挑一个视线目标投递；若被更高优先级遮蔽
//! （如用户正拖动屏幕/摄像头在跟踪），主动清空自己的槽位并静默，
//! 遮蔽解除后的下一个周期才恢复——与手动操作互不抢戏。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'look_source.dart';

class IdleLookSource extends LookSource {
  IdleLookSource();

  final math.Random _rand = math.Random();
  LookSink? _sink;
  Timer? _timer;

  @override
  void start(LookSink sink) {
    _sink = sink;
    _schedule();
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _sink = null;
  }

  /// 安排下一次随机瞟眼：间隔 2.5~5 秒
  void _schedule() {
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: 2500 + _rand.nextInt(2500)),
      _onTick,
    );
  }

  void _onTick() {
    final sink = _sink;
    if (sink == null) return;
    if (sink.isObscured) {
      // 被手动输入遮蔽：清空自己的槽位静默，稍后再探
      sink.clear();
    } else {
      sink.submit(Offset(
        (_rand.nextDouble() * 2 - 1) * 0.8,
        (_rand.nextDouble() * 2 - 1) * 0.5,
      ));
    }
    _schedule();
  }
}
