//! LinkTransport 的 flutter_p2p_connection 实现（WiFi Direct + BLE）
//!
//! 三个已知坑的规避（spike 002 + 真机实测，见技能 my-app-device-link）：
//! 1. 插件的 check/ask 权限方法会挂死 platform channel——**绝不调用**；
//! 2. stream 会反复推同内容——一律去重后再转发；
//! 3. **Host/Client 必须按角色惰性实例化**——两实例同跑会互抢 WebSocket
//!    server/事件分发（建组端收不到消息的根因），spike 的单实例拓扑才稳。

import 'dart:async';

import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

import '../models/link_message.dart';
import '../models/link_peer.dart';
import 'link_transport.dart';

class P2pLinkTransport implements LinkTransport {
  P2pLinkTransport();

  /// 按角色惰性创建（坑 3）：选了哪个角色才实例化哪个
  FlutterP2pHost? _host;
  FlutterP2pClient? _client;

  final _statusCtrl = StreamController<LinkStatus>.broadcast();
  final _discoveredCtrl = StreamController<LinkDiscovery>.broadcast();
  final _messagesCtrl = StreamController<LinkMessage>.broadcast();

  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, BleDiscoveredDevice> _lastDevices = {};

  LinkRole _role = LinkRole.idle;
  ({String ssid, String psk, String ip})? _groupInfo;

  // 去重记忆（坑 2）
  String _lastStatus = '';
  String _lastPeers = '';
  String _lastMsgKey = '';
  int _seq = 0;

  @override
  LinkRole get role => _role;

  @override
  ({String ssid, String psk, String ip})? get groupInfo => _groupInfo;

  @override
  Stream<LinkStatus> get status => _statusCtrl.stream;

  @override
  Stream<LinkDiscovery> get discovered => _discoveredCtrl.stream;

  @override
  Stream<LinkMessage> get messages => _messagesCtrl.stream;

  void _emitStatus(LinkStatus s, {String key = ''}) {
    if (key.isNotEmpty && key == _lastStatus) return;
    _lastStatus = key;
    _statusCtrl.add(s);
  }

  void _emitMessage(String text) {
    // 消息流去重：同内容同秒视为重复推送
    final key = '$text/${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    if (key == _lastMsgKey) return;
    _lastMsgKey = key;
    _messagesCtrl.add(LinkMessage(
      text: text,
      fromSelf: false,
      at: DateTime.now(),
    ));
  }

  @override
  Future<({String ssid, String psk, String ip})> createGroup() async {
    _role = LinkRole.host;
    final host = _host ??= FlutterP2pHost();
    await host.initialize();
    _subs.add(host.streamHotspotState().listen((s) {
      if (s.isActive && s.ssid != null) {
        _groupInfo = (
          ssid: s.ssid!,
          psk: s.preSharedKey ?? '',
          ip: s.hostIpAddress ?? '',
        );
      }
      _emitStatus(
        s.isActive ? LinkStatus.working : LinkStatus.idle,
        key: '${s.isActive}/${s.ssid}/${s.failureReason}',
      );
    }));
    _subs.add(host.streamReceivedTexts().listen(_emitMessage));

    final s = await host.createGroup(advertise: true);
    if (!s.isActive || s.ssid == null) {
      throw LinkException('建组失败（failure=${s.failureReason}）');
    }
    _groupInfo = (
      ssid: s.ssid!,
      psk: s.preSharedKey ?? '',
      ip: s.hostIpAddress ?? '',
    );
    _emitStatus(LinkStatus.working);
    return _groupInfo!;
  }

  @override
  Future<void> removeGroup() async {
    await _host?.removeGroup();
    _groupInfo = null;
    _role = LinkRole.idle;
    _emitStatus(LinkStatus.idle, key: 'removed/${_seq++}');
  }

  @override
  Future<void> startScan() async {
    _role = LinkRole.client;
    final client = _client ??= FlutterP2pClient();
    await client.initialize();
    _subs.add(client.streamReceivedTexts().listen(_emitMessage));

    await client.startScan((devices) {
      final sig = devices.map((d) => d.deviceAddress).join(',');
      if (sig == _lastPeers) return;
      _lastPeers = sig;
      _lastDevices
        ..clear()
        ..addEntries(devices.map((d) => MapEntry(d.deviceAddress, d)));
      _discoveredCtrl.add(LinkDiscovery(
        peers: [
          for (final d in devices)
            LinkPeer(name: d.deviceName, address: d.deviceAddress),
        ],
      ));
    });
  }

  @override
  Future<void> stopScan() async => _client?.stopScan();

  @override
  Future<void> connect(LinkPeer peer) async {
    final client = _client;
    if (client == null) throw const LinkException('请先扫描设备');
    // connectWithDevice 需要扫描结果对象（spike 验证过的路径）：
    // 用扫描快照按地址重放
    final cached = _lastDevices[peer.address];
    if (cached == null) {
      throw LinkException('设备 ${peer.name} 不在扫描结果里，请重新扫描');
    }
    _emitStatus(LinkStatus.working, key: 'connecting/${_seq++}');
    await client.connectWithDevice(cached);
    _emitStatus(LinkStatus.connected, key: 'connected/${_seq++}');
  }

  @override
  Future<void> disconnect() async {
    await _client?.disconnect();
    _emitStatus(LinkStatus.idle, key: 'disc/${_seq++}');
  }

  @override
  Future<void> sendText(String text) async {
    switch (_role) {
      case LinkRole.host:
        await _host?.broadcastText(text);
      case LinkRole.client:
        await _client?.broadcastText(text);
      case LinkRole.idle:
        throw const LinkException('未连接，先建组或加入对端');
    }
    _messagesCtrl.add(LinkMessage(
      text: text,
      fromSelf: true,
      at: DateTime.now(),
    ));
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _host?.dispose();
    await _client?.dispose();
    await _statusCtrl.close();
    await _discoveredCtrl.close();
    await _messagesCtrl.close();
  }
}
