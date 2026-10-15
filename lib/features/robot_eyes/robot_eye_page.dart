//! 机器人眼睛页面：纯组装层
//!
//! 职责只剩三件：把输入源注册进 LookInputHub（视线仲裁）、
//! 把表情命令接到状态上、把眼睛组件挂到布局里。
//! 拖动/键盘/idle 的具体翻译逻辑都在 inputs/，渲染在 eyes/。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'expressions.dart';
import 'eyes/eye_renderer.dart';
import 'eyes/led_dot_renderer.dart';
import 'eyes/robo_eyes_renderer.dart';
import 'inputs/idle_look_source.dart';
import 'inputs/keyboard_command_source.dart';
import 'inputs/look_source.dart';
import 'inputs/pointer_look_source.dart';
import 'widgets/expression_menu.dart';
import 'widgets/led_eyes.dart';

class RobotEyePage extends StatefulWidget {
  const RobotEyePage({super.key});

  @override
  State<RobotEyePage> createState() => _RobotEyePageState();
}

class _RobotEyePageState extends State<RobotEyePage> {
  final math.Random _rand = math.Random();

  /// 视线输入中枢与各输入源（拖动最高优先，idle 兜底）
  late final LookInputHub _hub;
  late final PointerLookSource _pointer;
  late final IdleLookSource _idle;
  late final KeyboardCommandSource _keyboard;

  /// 可用的眼睛风格表：右键菜单里"切换风格"循环切换
  static const List<EyeRenderer> _styles = [
    RoboEyesRenderer(), // RoboEyes 屏幕眼
    LedDotRenderer(), // LED 点阵风
  ];
  int _styleIndex = 0;

  /// 循环切换眼睛风格
  void _switchStyle() {
    setState(() {
      _styleIndex = (_styleIndex + 1) % _styles.length;
    });
  }

  /// 当前表情语义
  ExpressionType _type = ExpressionType.neutral;

  @override
  void initState() {
    super.initState();
    _hub = LookInputHub(onChanged: _onLookChanged);
    _pointer = PointerLookSource();
    _idle = IdleLookSource();
    _keyboard = KeyboardCommandSource();

    // 注册输入源：优先级数值大的胜出（拖动 > idle）
    _pointer.start(_hub.sink(100));
    _idle.start(_hub.sink(0));
    _keyboard.start(_applyCommand);
  }

  @override
  void dispose() {
    _pointer.stop();
    _idle.stop();
    _keyboard.stop();
    super.dispose();
  }

  /// 中枢仲裁出的视线变化时刷新
  void _onLookChanged() {
    if (mounted) setState(() {});
  }

  /// 表情命令（键盘/右键菜单共用入口）：null=随机挑一个不同的
  void _applyCommand(ExpressionType? command) {
    setState(() {
      if (command != null) {
        _type = command;
      } else {
        ExpressionType next;
        do {
          next = ExpressionType
              .values[_rand.nextInt(ExpressionType.values.length)];
        } while (next == _type && ExpressionType.values.length > 1);
        _type = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      // 输入源的 build 各自负责挂接手势/焦点，层层包裹即可
      body: _keyboard.build(
        _pointer.build(
          GestureDetector(
            // 右键 = 表情菜单（表情/随机/切换风格都走这里）
            onSecondaryTapDown: (d) => showExpressionMenu(
              context,
              d,
              onPick: _applyCommand,
              onSwitchStyle: _switchStyle,
              currentStyleName: _styles[_styleIndex].name,
            ),
            child: Center(
              child: SizedBox(
                width: screenW * 0.86,
                height: screenW * 0.34,
                child: LedEyes(
                  lookTarget: _hub.current,
                  type: _type,
                  // 眼睛样式在此注入：换风格=换 _styleIndex
                  renderer: _styles[_styleIndex],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
