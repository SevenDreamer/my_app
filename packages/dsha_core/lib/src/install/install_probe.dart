// 版权来源：DSHA（MIT）com.deepseekharness.app.util.InstallProbe —— 现代化重构，行为契约不变。
//! 安装六步的只读探测协议。成功必须有命令退出码，不能从版本输出的首行猜测。
//!
//! 协议（容器内 bash 输出行）：`DSHA_CHECK_BEGIN:<key>` … `DSHA_CHECK_RESULT:<key>:<code>`。
//! Results 只接受本次探测中的已知键；缺失、重复或无效结果均不能算成功。
import '../util/shell_quote.dart';
import 'install_stage.dart';

/// 会话/设置补丁的契约路径与标记（探测与修复共用，不得改动）。
const String sessionBase = '/usr/local/lib/node_modules/@deepseek-ai/';
const String sessionTop =
    '${sessionBase}dsh-session-persistence-jsonl/lib/index.js';
const String sessionNested =
    '${sessionBase}dsh/node_modules/@deepseek-ai/dsh-session-persistence-jsonl/lib/index.js';
const String sessionPublishImport =
    'import { publishSessionExclusive as link } from "dsha-runtime-fs";';

/// alpha.2 的会话后端用受管 cwd 直达提示，仍保留真实磁盘读取与格式校验。
const String sessionDirectHintMarker = 'DSHA_SESSION_DIRECT_HINTS_V1';

const String settingsPath =
    '${sessionBase}dsh/node_modules/@deepseek-ai/dsh-client-ui-settings/lib/client.js';

/// 单项探测（步骤 + 键 + 显示名 + 容器内命令）。
class InstallCheck {
  InstallCheck({required int step, required this.key, required this.label, required this.command})
      : stage = InstallStage.fromId(step);

  final InstallStage stage;
  final String key, label, command;
}

/// 探测协议。
final class InstallProbe {
  const InstallProbe._();

  /// 六步的全部探测项；selected != 0 时只留该步。
  static List<InstallCheck> checks(int selected) {
    final all = <InstallCheck>[
      InstallCheck(step: 2, key: 'curl', label: 'curl', command: 'curl --version'),
      InstallCheck(step: 2, key: 'git', label: 'git', command: 'git --version'),
      InstallCheck(
        step: 2,
        key: 'python',
        label: 'Python 与标准库',
        command:
            "python3 -B -c 'import ssl, sqlite3, readline, tarfile, zipfile, sys; print(sys.version); ssl.create_default_context()'",
      ),
      InstallCheck(step: 3, key: 'node', label: 'Node.js', command: 'node --version'),
      InstallCheck(step: 4, key: 'pnpm', label: 'pnpm', command: 'pnpm --version'),
      InstallCheck(
        step: 5,
        key: 'dsh',
        label: 'dsh 入口与版本',
        command: "test -x /usr/local/bin/dsh && node -e " +
            shellQuoteArg(
                r"const p=require('/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json'); if(!/^\d+\./.test(p.version))process.exit(1); console.log(p.version)"),
      ),
      InstallCheck(
        step: 6,
        key: 'dns',
        label: 'DNS 配置',
        command:
            "grep -Eq '^[[:space:]]*nameserver[[:space:]]+[^[:space:]#]+' /etc/resolv.conf || { echo '缺少 nameserver 配置'; exit 1; }",
      ),
      InstallCheck(
        step: 6,
        key: 'session',
        label: '会话写入补丁',
        command: "found=0; for f in " +
            shellQuoteArg(sessionTop) + " " + shellQuoteArg(sessionNested) +
            r'''; do [ -f "$f" ] || continue; found=1; if grep -Fq 'await link(tmp, finalPath)' "$f" && ! grep -Fq ''' +
            shellQuoteArg(sessionPublishImport) + r''' "$f" && ! grep -Fq ''' +
            shellQuoteArg(sessionDirectHintMarker) +
            r''' "$f"; then echo "会话写入补丁缺失：$f"; exit 1; fi; done; [ "$found" = 1 ] || { echo '会话模块缺失'; exit 1; }''',
      ),
      InstallCheck(
        step: 6,
        key: 'settings',
        label: '局域网设置补丁',
        command: "test -f " +
            shellQuoteArg(settingsPath) +
            " || { echo '设置模块缺失'; exit 1; }; if grep -Fq " +
            shellQuoteArg(
                'const persistence = ctx.remote.\$host.isLoopback ? "host" : "memory";') +
            " " + shellQuoteArg(settingsPath) + "; then echo '局域网设置补丁缺失'; exit 1; fi",
      ),
      InstallCheck(step: 6, key: 'groups', label: 'Android 用户组', command: 'id -Gn'),
    ];
    if (selected != 0) {
      all.removeWhere((check) => check.stage.id != selected);
    }
    return all;
  }

  /// 生成一次探测脚本（环境变量 + BEGIN/RESULT 标记 + 单项 20s 上限）。
  /// 子检查上限避免一个坏命令吞掉其余步骤；容器总超时由调用方兜底。
  static String script(List<InstallCheck> checks) {
    final buffer = StringBuffer(
        'export PYTHONDONTWRITEBYTECODE=1 CI=1 NO_UPDATE_NOTIFIER=1 PNPM_DISABLE_SELF_UPDATE_CHECK=1\n');
    for (final check in checks) {
      buffer.write("printf '%s\\n' 'DSHA_CHECK_BEGIN:${check.key}'\n");
      buffer.write("if command -v timeout >/dev/null 2>&1; then timeout 20s /bin/bash -c ");
      buffer.write(shellQuoteArg(check.command));
      buffer.write("; else /bin/bash -c ");
      buffer.write(shellQuoteArg(check.command));
      buffer.write("; fi\n");
      buffer.write(
          "code=\$?; printf '\\nDSHA_CHECK_RESULT:${check.key}:%s\\n' \"\$code\"\n");
    }
    return (buffer..write('exit 0\n')).toString();
  }
}

/// 探测结果收集：只认已知键；缺失、重复或无效均记 -1（≠ 成功）。
class InstallProbeResults {
  InstallProbeResults(this.checks);

  final List<InstallCheck> checks;
  final Map<String, int> _codes = <String, int>{};

  /// BEGIN 行 → 对应检查项（未知键返回 null）。
  InstallCheck? beginning(String line) {
    if (!line.startsWith('DSHA_CHECK_BEGIN:')) return null;
    final key = line.substring('DSHA_CHECK_BEGIN:'.length);
    for (final check in checks) {
      if (check.key == key) return check;
    }
    return null;
  }

  /// RESULT 行；只接受 `DSHA_CHECK_RESULT:<key>:<code>` 三段。
  bool accept(String line) {
    if (!line.startsWith('DSHA_CHECK_RESULT:')) return false;
    final parts = line.split(':');
    if (parts.length != 3) return false;
    for (final check in checks) {
      if (check.key != parts[1]) continue;
      final code = int.tryParse(parts[2]);
      _codes[check.key] = (_codes.containsKey(check.key) ||
              code == null ||
              code < 0 ||
              code > 255)
          ? -1
          : code;
      return true;
    }
    return false;
  }

  bool ok(String key) => _codes[key] == 0;

  /// 一步内全部检查都通过才算通过；该步没有任何检查项 = 不通过。
  bool okStep(int step) {
    var found = false;
    for (final check in checks) {
      if (check.stage.id != step) continue;
      found = true;
      if (!ok(check.key)) return false;
    }
    return found;
  }

  /// 一步的明细文案（契约模板：`%s：未收到结果` / `%s：正常` / `%s：失败（退出码 %s）`）。
  String detail(int step) {
    final out = StringBuffer();
    for (final check in checks) {
      if (check.stage.id != step) continue;
      if (out.isNotEmpty) out.write('；');
      final code = _codes[check.key];
      out.write(code == null
          ? '${check.label}：未收到结果'
          : code == 0
              ? '${check.label}：正常'
              : '${check.label}：失败（退出码 $code）');
    }
    return out.toString();
  }
}
