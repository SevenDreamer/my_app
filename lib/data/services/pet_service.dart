//! 桌宠（pet）生命周期服务——PET_INTEGRATION_PLAN P0（2026-11-13）。
//!
//! 形态 A（独立进程）：启动/停止/崩溃守护 pet.exe（gpui 桌宠，rust/pet）。
//! pet.exe 随包分发（与桌面 exe 同目录）；app 退出联动杀进程。
//! 通信（stdio 命令协议）是 P1——本服务只管生命周期。
import 'dart:async';
import 'dart:io';

import '../../core/logging/sentry_bridge.dart';

class PetService {
  Process? _process;
  bool _wantAlive = false;
  int _restartCount = 0;
  Timer? _restartTimer;

  /// 守护退避上限（连续崩溃 5 次后放弃，避免崩溃循环烧 CPU）
  static const int _maxRestarts = 5;

  bool get running => _process != null;

  /// pet.exe 路径：与主 exe 同目录（分发链把 pet.exe 放 exe 旁）
  String get _exePath {
    final dir = File(Platform.resolvedExecutable).parent.path;
    return Platform.isWindows ? '$dir\\pet.exe' : '$dir/pet';
  }

  /// 启动桌宠（幂等：已跑不重复启）。
  Future<bool> start() async {
    if (_process != null) return true;
    final exe = File(_exePath);
    if (!exe.existsSync()) {
      SentryBridge.breadcrumb('pet.start_missing', _exePath);
      return false;
    }
    _wantAlive = true;
    _restartCount = 0;
    return _spawn();
  }

  Future<bool> _spawn() async {
    try {
      _process = await Process.start(_exePath, const []);
      SentryBridge.action('pet.start', {'pid': _process!.pid});
      // 崩溃守护：进程退出且仍想活着 → 退避重启
      unawaited(_process!.exitCode.then((code) {
        _process = null;
        if (_wantAlive && code != 0) _scheduleRestart(code);
      }));
      return true;
    } catch (e) {
      SentryBridge.breadcrumb('pet.spawn_fail', '$e');
      _process = null;
      return false;
    }
  }

  void _scheduleRestart(int code) {
    if (_restartCount >= _maxRestarts) {
      SentryBridge.action(
          'pet.give_up', {'restarts': _restartCount, 'lastCode': code});
      _wantAlive = false;
      return;
    }
    _restartCount++;
    final delay = Duration(seconds: 2 * _restartCount); // 线性退避
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () {
      if (_wantAlive && _process == null) _spawn();
    });
    SentryBridge.breadcrumb('pet.restart_scheduled',
        'code=$code count=$_restartCount delay=${delay.inSeconds}s');
  }

  /// P1：发情绪命令（行协议 `mood:<name>`，pet stdout 回 `ok:mood:<name>`）。
  /// 未运行返回 false。
  bool sendMood(String mood) {
    final p = _process;
    if (p == null) return false;
    p.stdin.writeln('mood:$mood');
    return true;
  }

  /// P1：发原始命令行（扩展用）。
  bool sendRaw(String line) {
    final p = _process;
    if (p == null) return false;
    p.stdin.writeln(line);
    return true;
  }

  /// 停止桌宠（联动 app 退出调用）。
  Future<void> stop() async {
    _wantAlive = false;
    _restartTimer?.cancel();
    final p = _process;
    _process = null;
    if (p != null) {
      p.kill();
      await p.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1);
      SentryBridge.action('pet.stop', {'pid': p.pid});
    }
  }
}
