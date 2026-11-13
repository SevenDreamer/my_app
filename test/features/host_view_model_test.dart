//! HostViewModel 单测（测试安全网扩面，2026-11-13）。
//!
//! 假 HidGamepad（本地包）驱动被控端流转：设备刷新/扫描/配对编排。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hid_gamepad/hid_gamepad.dart';
import 'package:my_app/features/gamepad/host_view_model.dart';

class FakeHid implements HidGamepad {
  final List<String> calls = [];
  final _scan = StreamController<HidScanEvent>.broadcast();

  @override
  Stream<HidGamepadState> get state => const Stream.empty();

  @override
  Stream<HidScanEvent> get scanEvents => _scan.stream;

  @override
  Future<void> start({String name = 'my_app Gamepad'}) async {
    calls.add('start');
  }

  @override
  Future<void> sendReport(Uint8List report) async {
    calls.add('sendReport');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> startScan() async {
    calls.add('startScan');
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
  }

  @override
  Future<bool> pair(String address) async {
    calls.add('pair:$address');
    return true;
  }

  @override
  Future<void> openBluetoothSettings() async {
    calls.add('openSettings');
  }

  @override
  Future<List<HidBtDevice>> connectedDevices() async => const [];

  @override
  Future<List<HidBtDevice>> pairedDevices() async => const [];
}

void main() {
  setUp(() {
    // 同 gamepad 测试：默认 android 平台会抢跑权限请求（MissingPlugin 被
    // catch 吞掉，链路命令到不了）
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('扫描编排：startScan/stopScan 顺序', () async {
    final hid = FakeHid();
    final vm = HostViewModel(hid);
    await vm.startScan();
    await vm.stopScan();
    expect(hid.calls, containsAllInOrder(['startScan', 'stopScan']));
    vm.dispose();
  });

  test('配对与设置入口：命令下发', () async {
    final hid = FakeHid();
    final vm = HostViewModel(hid);
    await vm.pair('AA:BB:CC');
    await vm.openBluetoothSettings();
    expect(hid.calls, containsAllInOrder(['pair:AA:BB:CC', 'openSettings']));
    vm.dispose();
  });

  test('refresh：设备清单采集（假数据面为空不炸）', () async {
    final hid = FakeHid();
    final vm = HostViewModel(hid);
    await vm.refresh();
    expect(vm.error, isNull);
    vm.dispose();
  });
}
