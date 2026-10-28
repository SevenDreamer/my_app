// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenCoreIdentity —— 现代化重构，行为契约不变。
//! 只从可信启动结果取得的进程出生身份；端口和 PID 都不能单独充当退出证明。
//! 错误契约（逐字）：`VSCREEN_CORE_IDENTITY_INVALID`。
library;

/// 契约常量（原版 `Ids.UUID_PATTERN`）。
const String vscreenUuidPattern =
    '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}';

/// 出生身份（原版 `VirtualScreenCoreIdentity`）。
class VscreenCoreIdentity {
  VscreenCoreIdentity(this.pid, this.started, this.uid, this.boot, this.instance) {
    if (pid <= 1 ||
        started <= 0 ||
        uid < 0 ||
        !RegExp('^$vscreenUuidPattern\$').hasMatch(boot) ||
        !RegExp('^$vscreenUuidPattern\$').hasMatch(instance)) {
      throw ArgumentError('VSCREEN_CORE_IDENTITY_INVALID');
    }
  }

  final int pid, uid;
  final int started;
  final String boot, instance;

  String encode() => '$pid:$started:$uid:$boot:$instance';

  static VscreenCoreIdentity parse(String text) {
    if (text.length > 160) throw ArgumentError('VSCREEN_CORE_IDENTITY_INVALID');
    final fields = text.split(':');
    if (fields.length != 5 ||
        !RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(fields[0]) ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(fields[1]) ||
        !RegExp(r'^(0|[1-9][0-9]{0,9})$').hasMatch(fields[2])) {
      throw ArgumentError('VSCREEN_CORE_IDENTITY_INVALID');
    }
    return VscreenCoreIdentity(
        int.parse(fields[0]), int.parse(fields[1]), int.parse(fields[2]), fields[3], fields[4]);
  }

  /// 只读出生探测：读不出身份是 UNKNOWN；无终止信号。
  VscreenExit proof(String? output) {
    if (output == null || !output.contains('[EXIT=0]')) return VscreenExit.unknown;
    final prefix = 'DSHA_VSCREEN_EXIT_PROOF 1 ${encode()} ';
    VscreenExit? result;
    for (final line in output.split(RegExp(r'\r?\n'))) {
      if (!line.startsWith('DSHA_VSCREEN_EXIT_PROOF ')) continue;
      if (result != null || !line.startsWith(prefix)) return VscreenExit.unknown;
      // 原版 `Exit.valueOf` 大小写敏感。
      final parsed = _exitFromWire(line.substring(prefix.length));
      if (parsed == null) return VscreenExit.unknown;
      result = parsed;
    }
    return result ?? VscreenExit.unknown;
  }

  static VscreenExit? _exitFromWire(String suffix) {
    switch (suffix) {
      case 'EXITED':
        return VscreenExit.exited;
      case 'ALIVE':
        return VscreenExit.alive;
      case 'UNKNOWN':
        return VscreenExit.unknown;
      default:
        return null;
    }
  }
}

/// 退出证明结论（原版 `Exit`）。
enum VscreenExit {
  exited,
  alive,
  unknown;

  /// 线格式大写名（原版 `Exit.valueOf`/`toString`）。
  String get wireName => switch (this) {
        VscreenExit.exited => 'EXITED',
        VscreenExit.alive => 'ALIVE',
        VscreenExit.unknown => 'UNKNOWN',
      };
}
