// 版权来源：DSHA（MIT）com.deepseekharness.app.util.{VirtualScreenRequestFence,VirtualScreenLifecycleState,ScreenActionResult,OneShotLaunchAuthority,VirtualScreenRoutes} + vscreen.VirtualScreenLauncher —— 现代化重构，行为契约不变。
//! Manager 契约面：快照栅栏、生命周期态、执行后标记、一次性 ADB 启动授权、路由表、受限启动命令。
library;

import '../util/shell_quote.dart';

/// 一次原生虚拟屏连接与显示代次的不可变身份（原版 `VirtualScreenRequestFence`）。
class VscreenRequestFence {
  const VscreenRequestFence(
      this.epoch, this.port, this.token, this.generation, this.revision);

  final int epoch;
  final int port;
  final String token;
  final String generation;
  final int revision;

  bool matches(int lifecycle, int active, int port, String token,
      String generation, int revision) {
    return epoch == lifecycle &&
        epoch == active &&
        this.port == port &&
        this.token == token &&
        this.generation == generation &&
        this.revision == revision;
  }
}

/// 生命周期态（原版 `VirtualScreenLifecycleState`）。
/// 本机授权失效与远端退出分开表示；三个未知状态都禁止重新派发启动。
enum VscreenLifecycleState {
  stopped,
  starting,
  ready,
  startUnknown,
  disconnected,
  closing,
  closeUnknown;

  /// 线格式大写名（原版 `name()`）。
  String get wireName => name.toUpperCase();

  bool cleanupPending() =>
      this == VscreenLifecycleState.startUnknown ||
      this == VscreenLifecycleState.disconnected ||
      this == VscreenLifecycleState.closing ||
      this == VscreenLifecycleState.closeUnknown;
}

/// 写操作响应契约（原版 `ScreenActionResult`）：
/// 「执行前被拒（动作没有落地）」与「执行后目标/运行状态已变（动作可能已经落地）」分开。
/// 带标记的结果不得当成失败直接重试。
abstract final class ScreenActionResult {
  /// 执行前拒绝：动作确定没有落地，保持历史错误码。
  static const String notExecutedError = 'SCREEN_TARGET_CHANGED';

  /// 主屏无障碍路径稳定回复前缀（不把 Java 异常类名当用户可见文本透出，#145）。
  static const String notExecutedReply = '[ERR] $notExecutedError';

  /// 动作已执行，但执行后目标身份（窗口）已变。
  static const String targetChangedAfterExecution = 'targetChangedAfterExecution';

  /// 动作已执行，但执行后运行代次、授权或停止状态已变。
  static const String runChangedAfterExecution = 'runChangedAfterExecution';

  /// 前置拒绝：动作未执行。
  static String notExecuted() =>
      '{"ok":false,"error":"$notExecutedError"}';

  /// 动作已执行：原样返回动作结果，只在执行后状态确实变了时追加标记。
  ///
  /// 只对顶层 `ok=true` 的 JSON 对象生效：动作本身失败或结果不是对象时原样返回，
  /// 绝不给一个没有落地的动作贴上「已执行」标记。标记已存在时不重复追加。
  static String executed(String? result, bool targetChanged, bool runChanged) {
    if (result == null || (!targetChanged && !runChanged)) return result as String;
    final ok = _topLevelValueStart(result, 'ok');
    if (ok < 0 || !result.startsWith('true', ok)) return result;
    final marks = StringBuffer();
    if (targetChanged && _topLevelValueStart(result, targetChangedAfterExecution) < 0) {
      marks.write(',"$targetChangedAfterExecution":true');
    }
    if (runChanged && _topLevelValueStart(result, runChangedAfterExecution) < 0) {
      marks.write(',"$runChangedAfterExecution":true');
    }
    final end = _topLevelEnd(result);
    if (marks.isEmpty || end < 0) return result;
    return result.substring(0, end) + marks.toString() + result.substring(end);
  }

  /// 顶层对象里 `key` 对应值的起始下标；键不存在、不是单个对象或 JSON 未闭合返回 -1。
  static int _topLevelValueStart(String json, String key) {
    var depth = 0;
    var index = 0;
    while (index < json.length) {
      final current = json[index];
      if (current == '"') {
        final close = _stringEnd(json, index);
        if (close < 0) return -1;
        if (depth == 1) {
          final colon = _skipSpace(json, close + 1);
          if (colon < json.length &&
              json[colon] == ':' &&
              close == index + 1 + key.length &&
              json.substring(index + 1, index + 1 + key.length) == key) {
            return _skipSpace(json, colon + 1);
          }
        }
        index = close + 1;
        continue;
      }
      if (current == '{' || current == '[') {
        depth++;
      } else if (current == '}' || current == ']') {
        depth--;
      }
      index++;
    }
    return -1;
  }

  static int _topLevelEnd(String json) {
    var depth = 0;
    for (var index = 0; index < json.length; index++) {
      final current = json[index];
      if (current == '"') {
        final close = _stringEnd(json, index);
        if (close < 0) return -1;
        index = close;
      } else if (current == '{') {
        depth++;
      } else if (current == '}') {
        depth--;
        if (depth == 0) return index;
      }
    }
    return -1;
  }

  static int _stringEnd(String json, int start) {
    for (var index = start + 1; index < json.length; index++) {
      if (json[index] == '\\') {
        index++;
        continue;
      }
      if (json[index] == '"') return index;
    }
    return -1;
  }

  static int _skipSpace(String json, int from) {
    var index = from;
    while (index < json.length && (json[index] == ' ' || json[index] == '\t' || json[index] == '\n' || json[index] == '\r')) {
      index++;
    }
    return index;
  }
}

/// 一次性受管 ADB 启动授权（原版 `OneShotLaunchAuthority`）：纯逻辑、代次绑定。
class OneShotLaunchAuthority {
  String _ticket = '';
  String _command = '';
  int _generation = -1;
  int _expiresAt = 0;
  bool _planIssued = false;

  bool issue(String value, String exactCommand, int ownerGeneration, int now, int ttlMillis) {
    if (_ticket.isNotEmpty ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(value) ||
        exactCommand.isEmpty ||
        ownerGeneration < 0 ||
        now < 0 ||
        ttlMillis <= 0) {
      return false;
    }
    _ticket = value;
    _command = exactCommand;
    _generation = ownerGeneration;
    _expiresAt = now + ttlMillis;
    _planIssued = false;
    return true;
  }

  String ticketFor(String exactCommand, int ownerGeneration, int now) =>
      _current(ownerGeneration, now) && _command == exactCommand ? _ticket : '';

  bool authorize(String value, String exactCommand, int ownerGeneration, int now) {
    if (!_current(ownerGeneration, now) ||
        _planIssued ||
        _ticket != value ||
        _command != exactCommand) {
      return false;
    }
    _planIssued = true;
    return true;
  }

  /// 唯一远端 shell 发送前一刻消费租约。
  bool commit(String value, int ownerGeneration, int now) {
    if (!_current(ownerGeneration, now) || !_planIssued || _ticket != value) return false;
    _clear();
    return true;
  }

  void cancel(int ownerGeneration) {
    if (_ticket.isNotEmpty && _generation == ownerGeneration) _clear();
  }

  /// 原子关闭一笔仍存活的精确许可（远端发送前）：已消费/过期/已取消/未知票据永不能给出此证明。
  bool withdrawUncommitted(String value, String exactCommand, int ownerGeneration, int now) {
    if (!_current(ownerGeneration, now) || _ticket != value || _command != exactCommand) {
      return false;
    }
    _clear();
    return true;
  }

  bool _current(int ownerGeneration, int now) {
    if (_ticket.isEmpty) return false;
    if (now >= _expiresAt) {
      _clear();
      return false;
    }
    return _generation == ownerGeneration;
  }

  void _clear() {
    _ticket = '';
    _command = '';
    _generation = -1;
    _expiresAt = 0;
    _planIssued = false;
  }
}

/// 桥路由表（原版 `VirtualScreenRoutes`）：仅接受完整精确端点，未知子路径不能借末尾名称执行动作。
abstract final class VscreenRoutes {
  static const Map<String, String> _operations = {
    '/app/vscreen/create': 'create',
    '/app/vscreen/status': 'status',
    '/app/vscreen/launch': 'launch',
    '/app/vscreen/tree': 'tree',
    '/app/vscreen/node': 'node',
    '/app/vscreen/editor': 'editor',
    '/app/vscreen/edit': 'edit',
    '/app/vscreen/submit': 'submit',
    '/app/vscreen/touch': 'touch',
    '/app/vscreen/preview': 'preview',
    '/app/vscreen/see': 'see',
    '/app/vscreen/anchor': 'anchor',
    '/app/vscreen/anchored-click': 'anchored-click',
    '/app/vscreen/tap': 'tap',
    '/app/vscreen/swipe': 'swipe',
    '/app/vscreen/key': 'key',
    '/app/vscreen/type': 'type',
    '/app/vscreen/close': 'close',
  };

  static String operation(String? route) =>
      route == null ? '' : (_operations[route] ?? '');

  /// 该端点会向目标应用注入输入或无障碍动作：「执行后校验失败」时动作可能已经落地。
  /// 权威动作路由表在核心进程侧；核心新增动作路由时这里必须同步。
  static bool mutates(String? operation) {
    if (operation == null) return false;
    switch (operation) {
      case 'anchored-click':
      case 'tap':
      case 'swipe':
      case 'key':
      case 'type':
      case 'touch':
      case 'node':
      case 'edit':
      case 'submit':
        return true;
      default:
        return false;
    }
  }

  /// 核心进程侧路由（`/vscreen/*`）是否注入输入或无障碍动作。
  static bool mutatesCore(String? route) {
    const prefix = '/vscreen/';
    if (route == null || !route.startsWith(prefix)) return false;
    return mutates(route.substring(prefix.length));
  }
}

/// 受限启动命令（原版 `VirtualScreenLauncher`）：只生成当前安装包的启动/只读退出探针。
class VscreenLauncher {
  const VscreenLauncher({required this.sourceDir, required this.packageName});

  /// 接线缝：`ApplicationInfo.sourceDir` / `getPackageName()`。
  final String sourceDir;
  final String packageName;

  String _prefix() =>
      '/system/bin/app_process ${shellQuoteArg('-Djava.class.path=$sourceDir')} '
      '/system/bin com.deepseekharness.app.vscreen.VirtualScreenCore ';

  String launchCommand() =>
      '${_prefix()}--launch --port 0 --package ${shellQuoteArg(packageName)}';

  String probeCommand(String identityEncode) =>
      '${_prefix()}--probe-exit --identity ${shellQuoteArg(identityEncode)} '
      '--package ${shellQuoteArg(packageName)}';
}
