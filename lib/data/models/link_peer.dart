//! 设备互联的对端设备模型：统一 BLE 发现结果与连接目标

/// 发现到的对端设备
class LinkPeer {
  const LinkPeer({
    required this.name,
    required this.address,
  });

  /// 设备名（如「K40 Pro+」）
  final String name;

  /// 设备地址（BLE MAC）
  final String address;

  @override
  bool operator ==(Object other) =>
      other is LinkPeer && other.address == address;

  @override
  int get hashCode => address.hashCode;
}
