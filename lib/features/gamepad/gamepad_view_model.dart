//! 手柄调试视图模型：按键/摇杆状态 → GamepadReport → GamepadLink 上报
//!
//! MVVM：View 只读快照 + 调命令方法，不触碰链路层。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'gamepad_link.dart';
import 'gamepad_report.dart';
import 'latency_probe.dart';

class GamepadViewModel extends ChangeNotifier {
  GamepadViewModel(this._link, {LatencyProbe? probe})
      : _probe = probe ?? LatencyProbe() {
    _sub = _link.state.listen((s) {
      _state = s;
      notifyListeners();
    });
  }

  final GamepadLink _link;
  final LatencyProbe _probe;
  StreamSubscription<GamepadLinkState>? _sub;

  GamepadLinkState _state = GamepadLinkState.idle;
  final Set<int> _buttons = {}; // 当前按下的按钮位
  final Set<int> _dpadDirs = {}; // 当前按下的十字键方向（_up/_right/_down/_left）
  int _lx = 128, _ly = 128, _rx = 128, _ry = 128;
  GamepadReport _report = const GamepadReport();
  int _frames = 0;
  Timer? _heartTimer;
  int _heartSeq = 0;

  /// 延迟测试（心跳模式）是否运行中
  bool latencyTestOn = false;

  /// 十字键方向内部位（组合出 hat 值用）
  static const int _up = 1, _right = 2, _down = 4, _left = 8;

  static const Map<int, int> _hatByMask = {
    0: GamepadDpad.centered,
    _up: GamepadDpad.up,
    _up | _right: GamepadDpad.upRight,
    _right: GamepadDpad.right,
    _right | _down: GamepadDpad.downRight,
    _down: GamepadDpad.down,
    _down | _left: GamepadDpad.downLeft,
    _left: GamepadDpad.left,
    _left | _up: GamepadDpad.upLeft,
  };

  GamepadLinkState get state => _state;

  /// 最近一帧（快照）
  GamepadReport get report => _report;

  /// 已上报帧数
  int get frames => _frames;

  /// 最近一帧的十六进制展示
  String get lastBytesHex => _report
      .encode()
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');

  /// 启动链路（假链路立即连上；真实现为 HID 广播）
  Future<void> connect({String name = 'my_app Gamepad'}) async {
    try {
      // HID 需要蓝牙运行时权限（31+ 为 BLUETOOTH_CONNECT/SCAN，以下自动映旧权限）
      if (defaultTargetPlatform == TargetPlatform.android) {
        await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
      }
      await _link.startAsGamepad(name: name);
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  /// 启动失败的错误信息（无则为 null）
  String? error;

  /// 停止广播（可再次 [connect] 重启）
  Future<void> stop() => _link.stop();

  /// 开关延迟测试（心跳模式）：每 [kBeatInterval] 翻转 A 键——
  /// 偶拍按下 / 奇拍抬起，节拍时间戳走 UDP 广播供被控端配对测延迟。
  Future<void> setLatencyTest(bool on) async {
    if (on == latencyTestOn) return;
    if (on) {
      await _probe.start();
      _heartSeq = 0;
      _heartTimer = Timer.periodic(kBeatInterval, (_) {
        setButton(GamepadButton.a, _heartSeq.isEven);
        _probe.beat();
        _heartSeq++;
      });
    } else {
      _heartTimer?.cancel();
      _heartTimer = null;
      setButton(GamepadButton.a, false);
      _probe.stop();
    }
    latencyTestOn = on;
    notifyListeners();
  }

  /// 按下/松开一个功能按钮（[GamepadButton] 位）
  void setButton(int mask, bool pressed) {
    if (pressed ? _buttons.add(mask) : _buttons.remove(mask)) _emit();
  }

  /// 按下/松开十字键方向（0=上、1=右、2=下、3=左）
  void setDpad(int dir, bool pressed) {
    const bits = [_up, _right, _down, _left];
    final bit = bits[dir];
    if (pressed ? _dpadDirs.add(bit) : _dpadDirs.remove(bit)) _emit();
  }

  /// 摇杆位移：[dx]/[dy] 取 -1..1（0=居中），松手回中调 moveStick(left, 0, 0)
  void moveStick({required bool left, required double dx, required double dy}) {
    final x = (dx * 127 + 128).round().clamp(0, 255);
    final y = (dy * 127 + 128).round().clamp(0, 255);
    if (left) {
      if (x == _lx && y == _ly) return;
      _lx = x;
      _ly = y;
    } else {
      if (x == _rx && y == _ry) return;
      _rx = x;
      _ry = y;
    }
    _emit();
  }

  void _emit() {
    final mask = _dpadDirs.fold<int>(0, (a, b) => a | b);
    _report = GamepadReport(
      buttons: _buttons.fold<int>(0, (a, b) => a | b),
      dpad: _hatByMask[mask] ?? GamepadDpad.centered,
      lx: _lx,
      ly: _ly,
      rx: _rx,
      ry: _ry,
    );
    _frames++;
    unawaited(_link.sendInputReport(_report));
    notifyListeners();
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    _probe.stop();
    unawaited(_sub?.cancel());
    unawaited(_link.stop());
    super.dispose();
  }
}
