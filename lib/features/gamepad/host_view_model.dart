//! 被控端 VM：扫描附近蓝牙设备、发起配对、维护已配对列表
//!
//! MVVM：View 只读快照 + 调命令方法；数据服务（HidGamepad 平台通道）
//! 经构造函数注入，默认真实现。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hid_gamepad/hid_gamepad.dart';
import 'package:permission_handler/permission_handler.dart';

class HostViewModel extends ChangeNotifier {
  HostViewModel([HidGamepad? gamepad]) : _gamepad = gamepad ?? HidGamepad() {
    _scanSub = _gamepad.scanEvents.listen(_onScanEvent);
  }

  final HidGamepad _gamepad;
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

  /// 记录一条收到的输入（页面捕获按键后调用）
  void logInput(String line) {
    inputLog.insert(0, line);
    if (inputLog.length > 30) inputLog.removeRange(30, inputLog.length);
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
    unawaited(_scanSub?.cancel());
    unawaited(_gamepad.stopScan());
    super.dispose();
  }
}
