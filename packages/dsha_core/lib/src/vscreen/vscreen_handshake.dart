// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenHandshake —— 现代化重构，行为契约不变。
//! 协议 1 握手，实际端口和出生身份与秘密一起由受管启动通道返回。
//! 错误契约（逐字）：`VSCREEN_HANDSHAKE_INVALID`。
library;

import 'core_identity.dart';

/// 握手载荷（原版 `VirtualScreenHandshake`）。
class VscreenHandshake {
  VscreenHandshake(this.port, this.token, this.identity) {
    if (port < 1 ||
        port > 65535 ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(token)) {
      throw ArgumentError('VSCREEN_HANDSHAKE_INVALID');
    }
  }

  final int port;
  final String token;
  final VscreenCoreIdentity identity;

  String payload() => '1 $port $token ${identity.encode()}';

  static VscreenHandshake parse(String payload) {
    final fields = payload.split(' ');
    if (fields.length != 4 ||
        fields[0] != '1' ||
        !RegExp(r'^[1-9][0-9]{0,4}$').hasMatch(fields[1])) {
      throw ArgumentError('VSCREEN_HANDSHAKE_INVALID');
    }
    return VscreenHandshake(
        int.parse(fields[1]), fields[2], VscreenCoreIdentity.parse(fields[3]));
  }

  /// 从启动输出认领 `DSHA_VSCREEN_STARTED` 行（0 条或多条都返回 null）。
  static VscreenHandshake? started(String? output) {
    if (output == null || !output.contains('[EXIT=0]')) return null;
    VscreenHandshake? found;
    for (final line in output.split(RegExp(r'\r?\n'))) {
      if (!line.startsWith('DSHA_VSCREEN_STARTED ')) continue;
      if (found != null) return null;
      try {
        found = parse(line.substring('DSHA_VSCREEN_STARTED '.length));
      } on Exception {
        return null;
      }
    }
    return found;
  }
}
