//! 蓝牙 HID 手柄模拟（Android）：platform channel 封装
//!
//! 对上暴露两组能力：
//! 控制端——以手柄身份开始广播（注册 HID 应用）、发送输入报告、停止；
//! 被控端——扫描附近设备、发起配对、查询已配对列表、打开系统蓝牙设置。
//! 状态流上报「广播中/已连接/断开」。仅 Android（9+）有实现；
//! 报告格式与 features/gamepad/gamepad_report.dart 一致
//! （10 字节：reportId + 按钮 2 + hat 1 + 轴 4 + 扳机 2）。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// HID 手柄链路状态
enum HidGamepadState {
  idle,
  advertising,
  connected,
  disconnected,
}

/// 蓝牙设备条目（被控端扫描/配对用）
class HidBtDevice {
  const HidBtDevice({
    required this.name,
    required this.address,
    required this.paired,
    required this.bonding,
    required this.isGamepad,
  });

  factory HidBtDevice.fromMap(Map<Object?, Object?> m) => HidBtDevice(
        name: (m['name'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        paired: m['paired'] == true,
        bonding: m['bonding'] == true,
        isGamepad: m['isGamepad'] == true,
      );

  final String name;
  final String address;
  final bool paired;
  final bool bonding;

  /// 系统识别为游戏手柄类设备（或名称含 Gamepad）
  final bool isGamepad;
}

/// 扫描事件：type = found（发现设备）/ bond（配对状态变化）
class HidScanEvent {
  const HidScanEvent({required this.type, required this.device});

  final String type;
  final HidBtDevice device;
}

class HidGamepad {
  static const MethodChannel _method = MethodChannel('my_app/hid_gamepad');
  static const EventChannel _events = EventChannel('my_app/hid_gamepad/events');
  static const EventChannel _scanEvents =
      EventChannel('my_app/hid_gamepad/scan');

  Stream<HidGamepadState>? _state;
  Stream<HidScanEvent>? _scan;

  /// 链路状态流
  Stream<HidGamepadState> get state => _state ??=
      _events.receiveBroadcastStream().map((e) => switch (e as String) {
            'advertising' => HidGamepadState.advertising,
            'connected' => HidGamepadState.connected,
            'disconnected' => HidGamepadState.disconnected,
            _ => HidGamepadState.idle,
          });

  /// 以手柄身份开始广播（主机端搜索/配对 [name]）
  Future<void> start({String name = 'my_app Gamepad'}) =>
      _method.invokeMethod('start', {'name': name});

  /// 发送一帧输入报告（含 reportId 的完整报告字节）
  Future<void> sendReport(Uint8List report) =>
      _method.invokeMethod('sendReport', {'report': report});

  /// 停止广播并释放资源
  Future<void> stop() => _method.invokeMethod('stop');

  /// 扫描/连接事件流：found（发现设备）/ bond（配对状态）/
  /// acl_in · acl_out（ACL 连接/断开——被控端「已连接」列表用）
  Stream<HidScanEvent> get scanEvents =>
      _scan ??= _scanEvents.receiveBroadcastStream().map((e) {
        final m = (e as Map).cast<Object?, Object?>();
        return HidScanEvent(
          type: (m['type'] as String?) ?? 'found',
          device: HidBtDevice.fromMap(
              (m['device'] as Map).cast<Object?, Object?>()),
        );
      });

  /// 已配对设备列表（被控端显示）
  Future<List<HidBtDevice>> pairedDevices() async {
    final list =
        await _method.invokeListMethod<Map<Object?, Object?>>('pairedDevices');
    return (list ?? []).map(HidBtDevice.fromMap).toList();
  }

  /// 当前已连接设备列表（HID 主机角色；不可查时返回空，配合 acl 事件）
  Future<List<HidBtDevice>> connectedDevices() async {
    final list = await _method
        .invokeListMethod<Map<Object?, Object?>>('connectedDevices');
    return (list ?? []).map(HidBtDevice.fromMap).toList();
  }

  /// 开始扫描附近蓝牙设备（结果走 [scanEvents]）
  Future<void> startScan() => _method.invokeMethod('startScan');

  /// 停止扫描
  Future<void> stopScan() => _method.invokeMethod('stopScan');

  /// 发起配对（系统弹配对确认框，bond 状态走 [scanEvents]）
  Future<bool> pair(String address) async =>
      await _method.invokeMethod<bool>('pair', {'address': address}) ?? false;

  /// 打开系统蓝牙设置（兜底引导）
  Future<void> openBluetoothSettings() =>
      _method.invokeMethod('openBluetoothSettings');
}
