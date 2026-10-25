//! 设备互联 ViewModel：页面状态与命令的唯一入口
//!
//! MVVM 分层（官方架构技能）：View 只读状态快照 + 调用命令方法，
//! 链路访问（LinkTransport）封装在此，View 不直接触碰传输层。
//! 权限申请也在此层（插件自带的权限方法会挂死，见 p2p_link_transport.dart）。

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/link_message.dart';
import '../../data/models/link_peer.dart';
import '../../data/services/link_transport.dart';
import '../../data/services/p2p_link_transport.dart';

class DeviceLinkViewModel extends ChangeNotifier {
  /// 链路服务经构造注入（官方：依赖通过构造函数进入 ViewModel）
  DeviceLinkViewModel({LinkTransport? transport})
      : _transport = transport ?? P2pLinkTransport() {
    _subs.add(_transport.status.listen((s) {
      _status = s;
      notifyListeners();
    }));
    _subs.add(_transport.discovered.listen((d) {
      _peers = List.unmodifiable(d.peers);
      notifyListeners();
    }));
    _subs.add(_transport.messages.listen((m) {
      _messages = List.unmodifiable([..._messages, m]);
      notifyListeners();
    }));
  }

  final LinkTransport _transport;
  final List<StreamSubscription<dynamic>> _subs = [];

  LinkStatus _status = LinkStatus.idle;
  List<LinkPeer> _peers = const [];
  List<LinkMessage> _messages = const [];
  String? _error;
  bool _busy = false;

  /// 不可变状态快照
  LinkRole get role => _transport.role;
  LinkStatus get status => _status;
  List<LinkPeer> get peers => _peers;
  List<LinkMessage> get messages => _messages;
  ({String ssid, String psk, String ip})? get groupInfo => _transport.groupInfo;
  String? get error => _error;
  bool get busy => _busy;

  /// 申请互联所需权限（按 Android 版本分层）
  ///
  /// 分层与 vendor 补丁同逻辑（PATCHES.md）：
  /// - 定位：全版本必需（WiFi Direct 发现）
  /// - 蓝牙运行时三件套：Android 12+（API 31+）才有
  /// - NEARBY_WIFI_DEVICES：Android 13+（API 33+）才有——低版本请求必然
  ///   denied（系统不认识该权限），就是 vendor 补丁修的同款雷，勿回退
  Future<bool> ensurePermissions() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final requests = await <Permission>[
      Permission.locationWhenInUse,
      if (sdk >= 31) ...[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ],
      if (sdk >= 33) Permission.nearbyWifiDevices,
    ].request();
    final denied =
        requests.entries.where((e) => !e.value.isGranted).map((e) => e.key);
    if (denied.isNotEmpty) {
      _error =
          '缺少权限：${denied.map((p) => p.toString().split('.').last).join('、')}';
      notifyListeners();
      return false;
    }
    return true;
  }

  /// 建组（host 角色）
  Future<void> createGroup() => _run(() async {
        await _transport.createGroup();
      });

  /// 解散组（host 角色）
  Future<void> removeGroup() => _run(() async {
        await _transport.removeGroup();
        _peers = const [];
      });

  /// 开始扫描（client 角色）
  Future<void> startScan() => _run(() async {
        _peers = const [];
        await _transport.startScan();
      });

  /// 停止扫描
  Future<void> stopScan() => _run(_transport.stopScan);

  /// 连接发现的对端
  Future<void> connect(LinkPeer peer) => _run(() async {
        await _transport.connect(peer);
      });

  /// 断开连接
  Future<void> disconnect() => _run(() async {
        await _transport.disconnect();
        _peers = const [];
      });

  /// 发送文本
  Future<void> sendText(String text) => _run(() async {
        if (text.trim().isEmpty) return;
        await _transport.sendText(text.trim());
      });

  /// 统一命令执行壳：忙态 + 错误捕获（View 不再 try/catch）
  Future<void> _run(Future<void> Function() op) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await op();
    } on LinkException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _transport.dispose();
    super.dispose();
  }
}
