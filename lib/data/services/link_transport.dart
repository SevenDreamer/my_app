//! 链路抽象层：业务层只认「发现/连接/收发」，不认具体链路
//!
//! 对应 v0.1 方案稿的 Transport 接口设计：当前 flutter_p2p_connection
//! （WiFi Direct + BLE）一个实现，后续纯 Dart UDP/蓝牙兜底各实现一个，
//! 新增链路不影响业务代码（ViewModel 只依赖本接口）。

import '../models/link_message.dart';
import '../models/link_peer.dart';

/// 本机链路角色
enum LinkRole {
  /// 未选择
  idle,

  /// 主机：建组（WiFi Direct group owner）
  host,

  /// 客户端：扫描并加入对端的组
  client,
}

/// 连接状态
enum LinkStatus {
  /// 未连接
  idle,

  /// 建组/扫描中
  working,

  /// 已连接（组内有对端）
  connected,

  /// 出错
  error,
}

/// 一次发现结果
class LinkDiscovery {
  const LinkDiscovery({required this.peers});

  final List<LinkPeer> peers;
}

/// 链路事件总快照（流事件统一进 VM）
abstract class LinkTransport {
  /// 当前角色
  LinkRole get role;

  /// 建组信息（host 角色成功后非空）：SSID/PSK/网关 IP
  ({String ssid, String psk, String ip})? get groupInfo;

  /// 状态事件流
  Stream<LinkStatus> get status;

  /// 发现结果流（client 角色扫描时）
  Stream<LinkDiscovery> get discovered;

  /// 消息流（双向文本）
  Stream<LinkMessage> get messages;

  /// 建组（host）。返回组信息；失败抛 [LinkException]
  Future<({String ssid, String psk, String ip})> createGroup();

  /// 解散组（host）
  Future<void> removeGroup();

  /// 开始扫描（client）
  Future<void> startScan();

  /// 停止扫描（client）
  Future<void> stopScan();

  /// 连接发现的对端（client）
  Future<void> connect(LinkPeer peer);

  /// 断开当前连接
  Future<void> disconnect();

  /// 发送文本（双向）
  Future<void> sendText(String text);

  /// 释放资源
  Future<void> dispose();
}

/// 链路异常（带用户可读原因）
class LinkException implements Exception {
  const LinkException(this.message);

  final String message;

  @override
  String toString() => message;
}
