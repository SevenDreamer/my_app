// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ProcStat / VirtualScreenExitProofPolicy —— 现代化重构，行为契约不变。
//! 只读 Linux stat 读数；所有权/UID/信号权限仍是调用方策略。
//! 退出决策：平台读数与退出决策分开；不可读不是退出，端口状态不参与决策。
library;

import 'core_identity.dart';

/// /proc 解析（原版 `ProcStat`）。
class ProcStat {
  ProcStat._(this.pid, this.parent, this.group, this.session, this.started, this.state);

  final int pid, parent, group, session;
  final int started;
  final String state; // 单字符状态（原版 char）

  static ProcStat? parse(String? text, int expectedPid) {
    if (text == null || text.length > 8192 || expectedPid <= 1) return null;
    final open = text.indexOf(' ('), close = text.lastIndexOf(')');
    if (open < 1 || close <= open) return null;
    try {
      if (int.parse(text.substring(0, open)) != expectedPid) return null;
      final fields = text.substring(close + 1).trim().split(RegExp(r'\s+'));
      if (fields.length < 20 || fields[0].length != 1) return null;
      final started = int.parse(fields[19]);
      if (started <= 0) return null;
      return ProcStat._(expectedPid, int.parse(fields[1]), int.parse(fields[2]),
          int.parse(fields[3]), started, fields[0]);
    } on Exception {
      return null;
    }
  }

  static bool exitedState(String state) => state == 'Z' || state == 'X' || state == 'x';

  bool exited() => exitedState(state);
}

/// 退出证明策略（原版 `VirtualScreenExitProofPolicy.classify`）。
abstract final class VscreenExitProofPolicy {
  static VscreenExit classify(VscreenCoreIdentity? expected, String? boot,
      ProcStat? process, int? ownerUid, bool kernelEsrch) {
    if (expected == null ||
        boot == null ||
        !RegExp('^$vscreenUuidPattern\$').hasMatch(boot)) {
      return VscreenExit.unknown;
    }
    if (expected.boot != boot || kernelEsrch) return VscreenExit.exited;
    if (process == null || ownerUid == null || process.pid != expected.pid) {
      return VscreenExit.unknown;
    }
    return process.started != expected.started ||
            ownerUid != expected.uid ||
            process.exited()
        ? VscreenExit.exited
        : VscreenExit.alive;
  }
}
