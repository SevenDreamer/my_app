//! 被控端 VM：扫描附近蓝牙设备、发起配对、维护已配对列表
//!
//! MVVM：View 只读快照 + 调命令方法；数据服务（HidGamepad 平台通道）
//! 经构造函数注入，默认真实现。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hid_gamepad/hid_gamepad.dart';
import 'package:permission_handler/permission_handler.dart';

import 'latency_probe.dart';

class HostViewModel extends ChangeNotifier {
  HostViewModel([HidGamepad? gamepad, LatencyMeter? meter])
      : _gamepad = gamepad ?? HidGamepad(),
        _meter = meter ?? LatencyMeter() {
    _scanSub = _gamepad.scanEvents.listen(_onScanEvent);
  }

  final HidGamepad _gamepad;
  final LatencyMeter _meter;
  StreamSubscription<HidScanEvent>? _scanSub;

  /// 当前已连接设备（ACL 跟踪 + 进入页面时查询）
  List<HidBtDevice> connected = [];

  /// 已配对设备
  List<HidBtDevice> paired = [];

  /// 扫描发现的设备（按地址去重，手柄类排前）
  List<HidBtDevice> found = [];

  /// 收到的手柄输入日志（最新在前，上限 30 条）
  List<String> inputLog = [];

  /// 是否扫描中
  bool scanning = false;

  /// 错误信息（无则为 null）
  String? error;

  /// 进入页面刷新：拉取已连接/已配对列表
  Future<void> refresh() async {
    try {
      paired = await _gamepad.pairedDevices();
      connected = await _gamepad.connectedDevices();
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  /// 开始搜索附近设备（结果走 [found]）
  Future<void> startScan() async {
    try {
      // 蓝牙运行时权限（31+ 为 BLUETOOTH_CONNECT/SCAN，以下自动映旧权限）
      if (defaultTargetPlatform == TargetPlatform.android) {
        await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
      }
      await _gamepad.startScan();
      scanning = true;
      error = null;
    } catch (e) {
      error = '$e';
      scanning = false;
    }
    notifyListeners();
  }

  /// 停止搜索
  Future<void> stopScan() async {
    await _gamepad.stopScan();
    scanning = false;
    notifyListeners();
  }

  /// 对指定设备发起配对（系统弹确认框）
  Future<void> pair(String address) async {
    try {
      await _gamepad.pair(address);
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  /// 打开系统蓝牙设置（兜底引导）
  Future<void> openBluetoothSettings() => _gamepad.openBluetoothSettings();

  DateTime? _lastKeyAt;
  final _deltas = <int>[];

  /// 手柄按键名映射（Flutter LogicalKeyboardKey 常量实测名；
  /// 不能用 const——该类重写了 ==/hashCode，const map 键要求原始相等）
  static final _keyNames = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.gameButtonA: 'A',
    LogicalKeyboardKey.gameButtonB: 'B',
    LogicalKeyboardKey.gameButtonX: 'X',
    LogicalKeyboardKey.gameButtonY: 'Y',
    LogicalKeyboardKey.gameButtonLeft1: 'L1',
    LogicalKeyboardKey.gameButtonLeft2: 'L2',
    LogicalKeyboardKey.gameButtonRight1: 'R1',
    LogicalKeyboardKey.gameButtonRight2: 'R2',
    LogicalKeyboardKey.gameButtonSelect: 'Select',
    LogicalKeyboardKey.gameButtonStart: 'Start',
    LogicalKeyboardKey.gameButtonMode: 'Mode',
    LogicalKeyboardKey.gameButtonThumbLeft: 'L3',
    LogicalKeyboardKey.gameButtonThumbRight: 'R3',
    LogicalKeyboardKey.arrowUp: 'Up',
    LogicalKeyboardKey.arrowDown: 'Down',
    LogicalKeyboardKey.arrowLeft: 'Left',
    LogicalKeyboardKey.arrowRight: 'Right',
  };

  /// 记录一次手柄按键（页面捕获后调用）：映射按键名 + 带上距上次的间隔；
  /// 同时喂延迟计（测试模式下按奇偶配对心跳节拍）
  void logKey(LogicalKeyboardKey key, {bool down = true}) {
    _meter.onKeyEvent(down: down);
    final name = _keyNames[key] ??
        (key.keyLabel.isNotEmpty ? key.keyLabel : null) ??
        key.debugName ??
        'Key(${key.keyId})';
    final now = DateTime.now();
    if (_lastKeyAt != null) {
      final delta = now.difference(_lastKeyAt!).inMilliseconds;
      _deltas.add(delta);
      if (_deltas.length > 20) _deltas.removeAt(0);
    }
    _lastKeyAt = now;
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    final t = '${p(now.hour)}:${p(now.minute)}:${p(now.second)}'
        '.${p(now.millisecond, 3)}';
    final label = down ? name : '$name↑';
    logInput(
        _deltas.isEmpty ? '$t  $label' : '$t  $label  (+${_deltas.last}ms)');
  }

  /// 最近按键节奏统计（样本 ≥3 才显示）：平均间隔 + 波动（max-min）
  String? get intervalStats {
    if (_deltas.length < 3) return null;
    var sum = 0, min = _deltas.first, max = _deltas.first;
    for (final d in _deltas) {
      sum += d;
      if (d < min) min = d;
      if (d > max) max = d;
    }
    return '最近 ${_deltas.length} 次 · 平均 ${sum ~/ _deltas.length}ms'
        ' · 波动 ${max - min}ms';
  }

  /// 记录一条收到的输入（[logKey] 的底层写入）
  void logInput(String line) {
    inputLog.insert(0, line);
    if (inputLog.length > 30) inputLog.removeRange(30, inputLog.length);
    notifyListeners();
  }

  /// 延迟测试（心跳测量）是否运行中
  bool latencyTesting = false;

  /// 端到端延迟统计文案（无样本为 null）
  String? get latencyStats => _meter.stats;

  /// 开关延迟测试：收心跳节拍、对时、与按键事件配对算端到端延迟
  Future<void> setLatencyTest(bool on) async {
    if (on == latencyTesting) return;
    if (on) {
      await _meter.start();
      latencyTesting = true;
    } else {
      _meter.stop();
      latencyTesting = false;
    }
    notifyListeners();
  }

  void _onScanEvent(HidScanEvent e) {
    switch (e.type) {
      case 'acl_in':
        if (!connected.any((d) => d.address == e.device.address)) {
          connected = [...connected, e.device];
        }
      case 'acl_out':
        connected =
            connected.where((d) => d.address != e.device.address).toList();
      case 'bond' || 'found':
        final i = found.indexWhere((d) => d.address == e.device.address);
        if (i >= 0) {
          found[i] = e.device;
        } else {
          found.add(e.device);
        }
        // 手柄类排前，其余按名称
        found.sort((a, b) {
          if (a.isGamepad != b.isGamepad) return a.isGamepad ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        if (e.device.paired &&
            !paired.any((d) => d.address == e.device.address)) {
          paired = [...paired, e.device];
        }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _meter.stop();
    unawaited(_scanSub?.cancel());
    unawaited(_gamepad.stopScan());
    super.dispose();
  }
}
