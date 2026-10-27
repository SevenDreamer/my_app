// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.AdbBridge —— 现代化重构，行为契约不变。
//! ADB 无线配对桥编排（绕过 Shizuku，通道直连设备 adbd）。
//! 把 ADB 脚本注入 rootfs，在容器内用 TLS1.3-PSK + SPAKE2 完成
//! 「无线调试配对 → 直连 adbd」，拿到 uid=2000(shell)。
//!
//! 输出协议（宿主/UI 解析）逐字保留：`ENVIRONMENT_BUSY`/`ADB_ERROR`/`ADB_CANCELLED`/
//! `ADB_SCRIPTS_INSTALLED`/`SETTINGS_APPLIED`/`SETTINGS_PENDING`/`SCRIPTS_FAILED`/
//! `GLIBC_PY_INSTALL_FAIL`/`SETUP_DONE`/`SETUP_FAILED`/`SETUP_INCOMPLETE`/
//! `WHEELS_EXTRACT_FAIL`/`WHEELS_INJECT_FAIL`/`WHEELS_STAGE_CLEANUP_WARN`/
//! `ADB_CACHE_AUTHORITY`/`INVALID_CODE`/`PAIR_BUSY`/`PAIR_ERROR`/`CONNECT_WARN`/
//! `KEEPALIVE_OK`/`KEEPALIVE_WARN`/`ADB_DEPS_READY`/`ADB_DEPS_MISSING`/
//! `ADB_PROCESS_EXIT=`/`ADB_PROCESS_EXIT_UNCONFIRMED`/`[输出行过长，已隐藏]`。
//!
//! Android 耦合（NsdManager 发现、APK assets、Context）经 [AdbBridgeHost] /
//! [EndpointDiscovery] 接线缝注入，接线轮由 Android 实现提供。
import 'dart:io' as io;

import '../install/sensitive_data.dart' as sensitive;
import '../util/shell_quote.dart';

/// 一次容器内命令的结果（原版 `AdbVirtualScreenStart.HelperResult`）。
/// 事实来自原生进程所有权，绝不从 helper/远端文本解析。
class HelperResult {
  const HelperResult(this.output,
      {required this.localExitConfirmed, required this.outputComplete});

  final String output;

  /// 本地进程回收已确认（false = 结果未知）。
  final bool localExitConfirmed;

  /// false = 输出被截断/超长隐藏，结果不完整。
  final bool outputComplete;
}

/// 环境操作边界（proot/资产/维护门；接线轮由宿主实现）。
abstract interface class AdbBridgeHost {
  /// 在 rootfs 内执行命令（限时 + 有界逐行收集 + 进程回收）。
  /// [pipedInput] 仅用于 48 字节虚拟屏票据（一次性 stdin 管道）。
  Future<HelperResult> exec(String command,
      {int timeoutMs = 60000, List<int>? pipedInput});

  /// 环境任务单飞门（忙碌时抛 `ENVIRONMENT_BUSY` 语义，见 [runEnvironmentTask]）。
  Future<T> runEnvironmentTask<T>(String kind, Future<T> Function() operation);

  Future<bool> environmentReady();
  Future<bool> scriptsMatch();
  Future<void> installScripts();
  Future<bool> ensureGlibcPython();

  /// wheel 缓存缺失补齐（APK 归档 → 临时目录 → 按名补缺）。
  Future<String> fillWheelCache();

  /// 校验缓存 wheel 并解包安装（Java 解包，适配无 pip）。
  Future<String> installWheelCache();

  /// 一次完整 setup 的判定快照：key / deps / wrapper 三件。
  Future<bool> keyPresent();
  Future<bool> depsOk();
  Future<bool> wrapperPresent();

  Future<String> runSetup();
}

/// 端点发现（Android NsdManager 实现；每轮独立、串行解析、结束即停）。
abstract interface class EndpointDiscovery {
  Future<Endpoint?> discover(String type, int timeoutMs,
      {required void Function(String) progress});
}

class Endpoint {
  const Endpoint(this.host, this.port);

  final String host;
  final int port;
}

/// 配对桥编排（原版 `AdbBridge` 静态面 → 实例面，注入 host）。
class AdbBridge {
  AdbBridge(this.host);

  final AdbBridgeHost host;
  bool _pairing = false;

  bool isPairing() => _pairing;

  /// 完整配对/验证/后台探活的同步范围；维护期阻塞时返回 `ENVIRONMENT_BUSY`。
  Future<String> environmentResult(String kind, Future<String> Function() operation) async {
    try {
      return await host.runEnvironmentTask(kind, operation);
    } catch (error) {
      final text = error.toString();
      if (text.contains('Busy')) {
        return 'ENVIRONMENT_BUSY: $text';
      }
      return 'ADB_ERROR: ${sensitive.redact(text)}';
    }
  }

  /// 供 VirtualScreenManager 的受管 app_process 启动入口；票据只经 stdin 传递。
  Future<HelperResult> executeVirtualScreenTyped(String command, String ticket) {
    final bytes = ticket.codeUnits;
    return host.runEnvironmentTask('启动虚拟屏核心', () async {
      if (bytes.length != 48) {
        return const HelperResult(
            '[POLICY_BLOCKED] Invalid native virtual-screen ticket length\n[EXIT=126]',
            localExitConfirmed: true,
            outputComplete: true);
      }
      return host.exec(
        'python3 /root/.dsh/adb-shell.py --vscreen-launch --timeout 20 --connect-timeout 20 -- '
        '${shellQuoteArg(command)}',
        timeoutMs: 60000,
        pipedInput: bytes,
      );
    });
  }

  Future<bool> injected() async {
    return await environmentResult('检查 ADB 脚本', () async {
          return (await host.scriptsMatch()) ? 'YES' : 'NO';
        }) ==
        'YES';
  }

  /// 签名脚本经宿主 FS 发布；STABLE 文件绑定永不接收 guest mv 写入。
  Future<String> inject() {
    return environmentResult('更新 ADB 脚本', () async {
      await host.installScripts();
      return 'ADB_SCRIPTS_INSTALLED';
    });
  }

  /// 幂等准备：授权设置 → 脚本 → glibc python → wheels → setup → 验证。
  Future<String> ensureReady({void Function(String)? progress}) {
    return environmentResult('准备 ADB 环境', () => _ensureReadyOwned(progress));
  }

  Future<String> _ensureReadyOwned(void Function(String)? progress) async {
    final sb = StringBuffer();
    progress?.call('正在同步 ADB 授权设置…');
    final settings = await applySettingsOwned();
    if (!settings.contains('SETTINGS_APPLIED')) return settings;
    progress?.call('正在检查 ADB 脚本版本…');
    if (!await injected()) {
      sb.writeln(await inject());
      if (!await injected()) {
        return 'SCRIPTS_FAILED: ADB 脚本更新未完成\n$sb';
      }
    }
    progress?.call('正在检查 Ubuntu Python…');
    if (!await host.ensureGlibcPython()) {
      return 'GLIBC_PY_INSTALL_FAIL: 无法安装 Ubuntu Python3，请先修复基础环境\n$sb';
    }
    progress?.call('正在检查离线 ADB 依赖…');
    final dependencies = await _prepareDependencies(progress);
    sb.write(dependencies.output);
    if (!dependencies.continueSetup) return sb.toString();
    if (await host.keyPresent() && await host.depsOk() && await host.wrapperPresent()) {
      return (sb..write('SETUP_DONE\n')).toString();
    }
    progress?.call('正在安装离线依赖与新版 ADB 入口，最长等待 3 分钟…');
    sb.writeln(await host.runSetup());
    if (!await host.keyPresent() || !await host.depsOk() || !await host.wrapperPresent()) {
      return 'SETUP_FAILED: 安装后验证未通过，请检查以下输出\n'
          '${sb.toString().replaceAll('SETUP_DONE', 'SETUP_INCOMPLETE')}';
    }
    return sb.toString();
  }

  /// 离线依赖三步（原版 `AdbDependencyPreparation.Steps`）。
  Future<({String output, bool continueSetup})> _prepareDependencies(
      void Function(String)? progress) async {
    final sb = StringBuffer();
    if (await host.depsOk()) return (output: sb.toString(), continueSetup: true);
    progress?.call('正在从 APK 补齐缺少的 wheel，保留已恢复的修改版与额外文件…');
    final filled = await host.fillWheelCache();
    sb.writeln(filled);
    if (filled.contains('WHEELS_INJECT_FAIL') || filled.contains('WHEELS_EXTRACT_FAIL')) {
      return (output: sb.toString(), continueSetup: false);
    }
    progress?.call('正在校验所有缓存 wheel 并安装；损坏缓存会原样保留并报告…');
    final installed = await host.installWheelCache();
    sb.writeln(installed);
    final ok = await host.depsOk();
    return (output: sb.toString(), continueSetup: ok);
  }

  /// 保存配置后调用；仅同步授权标记，不启动命令、不读取任何密钥。
  Future<String> applySettings() {
    return environmentResult('同步 ADB 授权', applySettingsOwned);
  }

  Future<String> applySettingsOwned() async {
    if (!await host.environmentReady()) {
      return 'SETTINGS_PENDING: 环境未就绪，下次准备 ADB 时同步授权设置';
    }
    // 原生命令策略读取当前配置；三个旧 guest 标志已无读者。
    // 历史字节保留为数据，但配置变更期间永不创建/删除它们。
    return 'SETTINGS_APPLIED: ADB 授权设置已同步';
  }

  /// 单次配对。pairPort 为空时脚本内尝试 mDNS 发现；host 为 App 解析出的真实 IP。
  Future<String> pair(
      {required String code,
      String pairPort = '',
      String connectPort = '',
      String hostAddress = ''}) {
    return environmentResult('ADB 配对与连接验证',
        () => _pairOwned(code, pairPort, connectPort, hostAddress));
  }

  Future<String> _pairOwned(
      String code, String pairPort, String connectPort, String hostAddress) async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return 'INVALID_CODE: 配对码必须恰好为 6 位数字';
    }
    if (_pairing) return 'PAIR_BUSY: 已有配对正在进行，请等待结果';
    _pairing = true;
    try {
      final command = 'python3 -u /root/.dsh/adb-pair.py --code '
          '${shellQuoteArg(code)}${await pairOptions(pairPort, connectPort, hostAddress)}';
      var out = (await host.exec(command, timeoutMs: 120000)).output;
      if (out.contains('CONNECT_OK')) {
        out = '$out\n${await _grantSecureSettings()}';
      }
      return sensitive.redact(out.isEmpty ? 'PAIR_ERROR: 配对进程没有返回结果' : out);
    } catch (error) {
      return 'PAIR_ERROR: ${sensitive.redact(error.toString())}';
    } finally {
      _pairing = false;
    }
  }

  Future<String> verify({String connectPort = '', String hostAddress = ''}) {
    return environmentResult('验证 ADB 连接', () async {
      try {
        var out = (await host.exec(
                'python3 -u /root/.dsh/adb-pair.py --verify-only'
                '${await pairOptions('', connectPort, hostAddress)}',
                timeoutMs: 60000))
            .output;
        if (out.contains('CONNECT_OK')) {
          out = '$out\n${await _grantSecureSettings()}';
        }
        return sensitive.redact(out.isEmpty ? 'CONNECT_WARN: 验证没有返回结果' : out);
      } catch (error) {
        return 'CONNECT_WARN: ${sensitive.redact(error.toString())}';
      }
    });
  }

  Future<String> pairOptions(
      String pairPort, String connectPort, String hostAddress) async {
    final out = StringBuffer();
    final pp = _port(pairPort), cp = _port(connectPort);
    if (pp > 0) out.write(' --port $pp');
    if (cp > 0) out.write(' --connect-port $cp');
    final trimmed = hostAddress.trim();
    if (trimmed.isNotEmpty) {
      if (!await localAddresses().then((set) => set.contains(trimmed))) {
        throw ArgumentError('请填写本机无线调试页面的 IP 地址');
      }
      out.write(' --host ${shellQuoteArg(trimmed)}');
    }
    return out.toString();
  }

  /// 配对成功后经 adb shell（uid=2000）授予 WRITE_SECURE_SETTINGS（开机保活依赖）。
  Future<String> _grantSecureSettings() async {
    try {
      final r = (await host.exec('python3 /root/.dsh/adb-pair.py --grant-keepalive 2>&1',
              timeoutMs: 45000))
          .output;
      return r.trim().endsWith('[EXIT=0]')
          ? 'KEEPALIVE_OK: 已允许自动恢复无线调试'
          : 'KEEPALIVE_WARN: 连接已验证，但自动恢复授权未完成；重启后可能需手动打开无线调试\n'
              '${sensitive.redact(r)}';
    } catch (error) {
      return 'KEEPALIVE_WARN: 自动恢复授权未完成；重启后可能需手动打开无线调试';
    }
  }

  /// 状态快照：key/deps/connect_port（供 UI 展示）。
  Future<String> status() {
    return environmentResult('读取 ADB 状态', () async {
      const command = "K=\$(test -f /root/.dsh/adbkeys/adbkey && echo YES || echo NO); "
          "D=\$(python3 -c 'import adb_shell_wifi; from spake2.spake2 import Spake2_Alice, Spake2_Bob' 2>/dev/null && echo YES || echo NO); "
          "P=\$(test -f /root/.dsh/adbkeys/connect_port && cat /root/.dsh/adbkeys/connect_port || echo -); "
          "echo 'key='\$K' deps='\$D' port='\$P";
      return (await host.exec(command, timeoutMs: 60000)).output;
    });
  }

  /// 后台探测也使用同一进程回收与环境任务范围。
  Future<String> probe(Endpoint? endpoint) {
    return environmentResult('ADB 后台探活', () async {
      final options = endpoint == null
          ? ''
          : ' --host ${shellQuoteArg(endpoint.host)} --port ${endpoint.port}';
      return (await host.exec(
              'python3 /root/.dsh/adb-shell.py --connect-timeout 20 --timeout 10'
              '$options id 2>&1',
              timeoutMs: 60000))
          .output;
    });
  }

  /// 本机地址集合（host 校验用；原版枚举网卡）。
  static Future<Set<String>> localAddresses() async {
    final result = <String>{'127.0.0.1', '::1'};
    try {
      for (final interface in await io.NetworkInterface.list()) {
        for (final address in interface.addresses) {
          result.add(address.address);
        }
      }
    } catch (_) {}
    return result;
  }
}

int _port(String value) {
  final parsed = int.tryParse(value.trim());
  return (parsed != null && parsed > 0 && parsed <= 65535) ? parsed : 0;
}
