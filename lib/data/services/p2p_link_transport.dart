//! LinkTransport 的 flutter_p2p_connection 实现（WiFi Direct + BLE）
//!
//! 两个已知坑的规避（spike 002 实测，见技能 my-app-device-link）：
//! 1. 插件的 check/ask 权限方法会挂死 platform channel——**绝不调用**，
//!    权限由页面层用 permission_handler 自己申请；
//! 2. stream 会反复推同内容——一律去重后再转发，防日志/UI 刷屏。

import 'dart:async';

import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

import '../models/link_message.dart';
import '../models/link_peer.dart';
import 'link_transport.dart';

class P2pLinkTransport implements LinkTransport {
  P2pLinkTransport()
      : _host = FlutterP2pHost(),
        _client = FlutterP2pClient() {
    _init();
  }

  final FlutterP2pHost _host;
  final FlutterP2pClient _client;

  final _statusCtrl = StreamController<LinkStatus>.broadcast();
  final _discoveredCtrl = StreamController<LinkDiscovery>.broadcast();
  final _messagesCtrl = StreamController<LinkMessage>.broadcast();

  final List<StreamSubscription<dynamic>> _subs = [];

  LinkRole _role = LinkRole.idle;
  ({String ssid, String psk, String ip})? _groupInfo;

  // 去重记忆（坑 2）
  String _lastStatus = '';
  String _lastPeers = '';
  int _msgSeq = 0;

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

  Future<void> _init() async {
    await _host.initialize();
    await _client.initialize();

    _subs.add(_host.streamHotspotState().listen((s) {
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

    _subs.add(_client.streamReceivedTexts().listen(_emitMessage));
    _subs.add(_host.streamReceivedTexts().listen(_emitMessage));
  }

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
    _msgSeq++;
  }

  String _lastMsgKey = '';

  @override
  Future<({String ssid, String psk, String ip})> createGroup() async {
    _role = LinkRole.host;
    final s = await _host.createGroup(advertise: true);
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
    await _host.removeGroup();
    _groupInfo = null;
    _role = LinkRole.idle;
    _emitStatus(LinkStatus.idle, key: 'removed/${_msgSeq++}');
  }

  @override
  Future<void> startScan() async {
    _role = LinkRole.client;
    await _client.startScan((devices) {
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
  Future<void> stopScan() => _client.stopScan();

  @override
  Future<void> connect(LinkPeer peer) async {
    // connectWithDevice 需要扫描结果对象；用凭据连接等价路径：
    // 扫描回调的 deviceAddress 即可定位（插件 3.x 的 connectWithDevice
    // 接受 BleDiscoveredDevice，这里用扫描缓存重放）
    final cached = _lastDevices[peer.address];
    if (cached == null) {
      throw LinkException('设备 ${peer.name} 不在扫描结果里，请重新扫描');
    }
    _emitStatus(LinkStatus.working, key: 'connecting/${_msgSeq++}');
    await _client.connectWithDevice(cached);
    _emitStatus(LinkStatus.connected, key: 'connected/${_msgSeq++}');
  }

  final Map<String, BleDiscoveredDevice> _lastDevices = {};

  @override
  Future<void> disconnect() async {
    await _client.disconnect();
    _emitStatus(LinkStatus.idle, key: 'disc/${_msgSeq++}');
  }

  @override
  Future<void> sendText(String text) async {
    if (_role == LinkRole.host) {
      await _host.broadcastText(text);
    } else if (_role == LinkRole.client) {
      await _client.broadcastText(text);
    } else {
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
    await _host.dispose();
    await _client.dispose();
    await _statusCtrl.close();
    await _discoveredCtrl.close();
    await _messagesCtrl.close();
  }
}
