//! 机器人眼睛页面：纯黑背景 + 表情管理（右键菜单/键盘切换）+ 手势视线
//!
//! 职责：持有当前表情与视线目标两份状态——
//! 右键弹出表情菜单、键盘 1~8 直选、空格随机；
//! 拖动跟随手指，松手回到 idle 随机乱瞟（叠加在当前表情上）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expressions.dart';
import '../eyes/led_dot_renderer.dart';
import '../widgets/led_eyes.dart';

class RobotEyePage extends StatefulWidget {
  const RobotEyePage({super.key});

  @override
  State<RobotEyePage> createState() => _RobotEyePageState();
}

class _RobotEyePageState extends State<RobotEyePage> {
  /// 随机数源：idle 乱瞟与随机表情
  final math.Random _rand = math.Random();

  /// 当前表情类型（页面层管理，切换交由 LedEyes 做过渡动画）
  ExpressionType _type = ExpressionType.neutral;

  /// 视线目标，分量 -1..1
  Offset _lookTarget = Offset.zero;

  /// idle 状态下的随机瞟眼定时器（拖动时暂停，松手后恢复）
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _scheduleIdleLook();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// 切换表情并重绘
  void _setExpression(ExpressionType type) {
    setState(() => _type = type);
  }

  /// 随机挑一个表情（与当前不同的）
  void _randomExpression() {
    ExpressionType next;
    do {
      next = ExpressionType.values[_rand.nextInt(ExpressionType.values.length)];
    } while (next == _type && ExpressionType.values.length > 1);
    _setExpression(next);
  }

  /// 键盘：1~8 直选表情，空格随机
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _randomExpression();
      return KeyEventResult.handled;
    }
    // 数字键 1~8 与表情枚举按顺序对应
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
        _setExpression(ExpressionType.values[i]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// 右键：弹出表情选择菜单（-1=随机）
  Future<void> _showExprMenu(TapDownDetails details) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            details.globalPosition.dx, details.globalPosition.dy, 0, 0),
        Offset.zero & box.size,
      ),
      items: [
        for (final t in ExpressionType.values)
          PopupMenuItem<int>(
            value: t.index,
            child: Text('${t.index + 1}. ${t.label}'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: -1,
          child: Text('🎲 随机'),
        ),
      ],
    );
    if (selected == null || !mounted) return; // 点菜单外=取消
    if (selected == -1) {
      _randomExpression();
    } else {
      _setExpression(ExpressionType.values[selected]);
    }
  }

  /// 安排下一次随机瞟眼：间隔 2.5~5 秒，目标点限制在眼眶可移动范围内
  void _scheduleIdleLook() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      Duration(milliseconds: 2500 + _rand.nextInt(2500)),
      () {
        if (!mounted) return;
        setState(() {
          _lookTarget = Offset(
            (_rand.nextDouble() * 2 - 1) * 0.8,
            (_rand.nextDouble() * 2 - 1) * 0.5,
          );
        });
        _scheduleIdleLook();
      },
    );
  }

  /// 拖动中：把指针的屏幕坐标换算成视线目标（-1..1）
  void _onDragUpdate(DragUpdateDetails details, Size size) {
    _idleTimer?.cancel();
    setState(() {
      _lookTarget = Offset(
        (details.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (details.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  /// 松手：视线回到正中，恢复 idle 乱瞟
  void _onDragEnd(DragEndDetails details) {
    setState(() => _lookTarget = Offset.zero);
    _scheduleIdleLook();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: GestureDetector(
              // 左键拖动=眼珠跟随；右键=表情菜单
              onPanUpdate: (d) => _onDragUpdate(d, size),
              onPanEnd: _onDragEnd,
              onSecondaryTapDown: _showExprMenu,
              child: Center(
                child: SizedBox(
                  width: size.width * 0.86,
                  height: size.width * 0.34,
                  child: LedEyes(
                    lookTarget: _lookTarget,
                    type: _type,
                    // 眼睛样式在此注入：换风格=换这个 renderer 实例
                    renderer: const LedDotRenderer(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
