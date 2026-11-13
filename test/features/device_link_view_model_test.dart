//! DeviceLinkViewModel 单测（测试安全网扩面，2026-11-13）。
//!
//! 假 LinkTransport 驱动 VM 流转：组网/扫描/连接/消息——验证 busy 编排与
//! 状态快照，不碰真实平台通道。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/link_message.dart';
import 'package:my_app/data/models/link_peer.dart';
import 'package:my_app/data/services/link_transport.dart';
import 'package:my_app/features/device_link/device_link_view_model.dart';

class FakeTransport implements LinkTransport {
  @override
  LinkRole role = LinkRole.host;
  final _status = StreamController<LinkStatus>.broadcast();
  final _discovered = StreamController<LinkDiscovery>.broadcast();
  final _messages = StreamController<LinkMessage>.broadcast();
  final List<String> calls = [];

  @override
  ({String ssid, String psk, String ip})? groupInfo;

  @override
  Stream<LinkStatus> get status => _status.stream;

  @override
  Stream<LinkDiscovery> get discovered => _discovered.stream;

  @override
  Stream<LinkMessage> get messages => _messages.stream;

  @override
  Future<({String ssid, String psk, String ip})> createGroup() async {
    calls.add('createGroup');
    groupInfo = (ssid: 'my_app-net', psk: '12345678', ip: '192.168.49.1');
    return groupInfo!;
  }

  @override
  Future<void> removeGroup() async {
    calls.add('removeGroup');
    groupInfo = null;
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
  Future<void> connect(LinkPeer peer) async {
    calls.add('connect:${peer.name}');
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
  }

  @override
  Future<void> sendText(String text) async {
    calls.add('sendText:$text');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _status.close();
    await _discovered.close();
    await _messages.close();
  }
}

void main() {
  test('createGroup：busy 流转 + groupInfo 落位', () async {
    final t = FakeTransport();
    final vm = DeviceLinkViewModel(transport: t);
    await vm.createGroup();
    expect(t.calls, contains('createGroup'));
    expect(vm.groupInfo?.ssid, 'my_app-net');
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('扫描编排：startScan/stopScan 顺序', () async {
    final t = FakeTransport();
    final vm = DeviceLinkViewModel(transport: t);
    await vm.startScan();
    await vm.stopScan();
    expect(t.calls, containsAllInOrder(['startScan', 'stopScan']));
    vm.dispose();
  });

  test('连接与断开：命令编排', () async {
    final t = FakeTransport();
    final vm = DeviceLinkViewModel(transport: t);
    await vm.connect(LinkPeer(name: 'p1', address: 'aa:bb'));
    await vm.disconnect();
    expect(t.calls, containsAllInOrder(['connect:p1', 'disconnect']));
    vm.dispose();
  });
}
