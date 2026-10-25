//! 设备互联的消息模型：文本互通的最小单元（里程碑①）

/// 一条互通消息
class LinkMessage {
  const LinkMessage({
    required this.text,
    required this.fromSelf,
    required this.at,
  });

  /// 消息文本
  final String text;

  /// 是否本机发出（false = 对端发来）
  final bool fromSelf;

  /// 时间戳（兼去重标识：流可能重复推送同内容）
  final DateTime at;
}
