// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.RuntimeTools /
// RootfsInstaller.pnpm / com.deepseekharness.app.util.DshEntrypoint ——
// 现代化重构，行为契约不变。
//! RuntimeTools.prepare 核心面（第一批）：随包证书、命令入口、DNS 配置。
//!
//! 契约逐字保留：命令入口全部位于 `/root/dsh-bin/`（guest PATH 最前位），
//! wrapper 字面与原版一致；证书固定 `usr/local/share/dsha/ca-certificates.crt`；
//! resolver 只在能取得设备 nameserver 时写 `/etc/resolv.conf`（拿不到如实
//! 不写，不造假 DNS）。补丁链（applyPatchChain 四专项）随第二批移植。
import 'dart:io' as io;

class RuntimeToolsLite {
  RuntimeToolsLite._();

  /// 原版 RuntimeTools.CERT_PATH（容器内绝对路径）。
  static const String certPath = '/usr/local/share/dsha/ca-certificates.crt';

  /// 原版 BuildConfig.BUNDLED_PNPM_VERSION（pnpm 运行时版本标记内容）。
  static const String bundledPnpmVersion = '10.34.5';

  /// dsh 入口（原版 DshEntrypoint.wrapper() 逐字）。
  static String dshWrapper() =>
      '#!/bin/sh\nexec /usr/local/bin/node /usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js "\$@"\n';

  /// npm/npx 入口（原版 preparePackageCommands 逐字模板）。
  static String npmWrapper(String command) =>
      '#!/bin/sh\nexec /usr/local/bin/node /usr/local/lib/node_modules/npm/bin/$command-cli.js "\$@"\n';

  /// pnpm 入口（原版 RootfsInstaller.pnpm wrapper 逐字；copy 导入法为默认，
  /// 显式 env/CLI 选择优先）。
  static String pnpmWrapper() =>
      '#!/bin/sh\nexport npm_config_package_import_method="\${npm_config_package_import_method-\${NPM_CONFIG_PACKAGE_IMPORT_METHOD-copy}}"\n'
      'exec /usr/local/bin/node /usr/local/lib/dsha-pnpm/bin/pnpm.cjs "\$@"\n';

  /// 造全部命令入口（幂等：内容变化或可执行位丢失才重写）。
  /// 返回写入/修复的入口数（诊断用）。
  static int ensureCommandEntries(String rootfs) {
    var touched = 0;
    final bin = io.Directory('$rootfs/root/dsh-bin')..createSync(recursive: true);
    void write(String name, String content) {
      final file = io.File('${bin.path}/$name');
      final bytes = content.codeUnits; // ASCII 模板字面
      final same = file.existsSync() &&
          file.lengthSync() == bytes.length &&
          _executable(file);
      if (same) return;
      file.writeAsBytesSync(bytes);
      _setExecutable(file);
      touched++;
    }

    write('npm', npmWrapper('npm'));
    write('npx', npmWrapper('npx'));
    write('dsh', dshWrapper());
    write('pnpm', pnpmWrapper());

    // python3 → python3.12（原版 RootfsInstaller.python 末步的 Compat.symlink）。
    final python3 = io.File('$rootfs/usr/bin/python3');
    if (!python3.existsSync() && io.File('$rootfs/usr/bin/python3.12').existsSync()) {
      io.Link(python3.path).createSync('python3.12');
      touched++;
    }
    // dsh 入口 symlink 目标补可执行位（探针 test -x 语义；deb/npm 来料
    // mode 不一，幂等 chmod）。
    final binjs =
        io.File('$rootfs/usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js');
    if (binjs.existsSync() && !_executable(binjs)) {
      _setExecutable(binjs);
      touched++;
    }
    // pnpm 运行时版本标记（原版 RootfsInstaller.pnpm 的 marker 语义）。
    final marker = io.File('$rootfs/root/.dsha-pnpm-version');
    if (!marker.existsSync() ||
        marker.lengthSync() > 128 ||
        marker.readAsStringSync().trim() != bundledPnpmVersion) {
      marker.writeAsStringSync('$bundledPnpmVersion\n');
      touched++;
    }
    return touched;
  }

  /// 随包证书（原版 RuntimeTools.CERT_PATH 安装面）。
  static void ensureCertificates(String rootfs, List<int> caBytes) {
    // 容器绝对路径 → rootfs 内相对路径。
    final file = io.File('$rootfs/${certPath.substring(1)}');
    file.parent.createSync(recursive: true);
    if (!file.existsSync() || file.lengthSync() != caBytes.length) {
      file.writeAsBytesSync(caBytes);
    }
  }

  /// DNS 配置（原版 prepareResolver 的写入面）：只在取得设备 nameserver 时
  /// 写 `/etc/resolv.conf`；空列表 = 拿不到真值，如实跳过（不造假 DNS）。
  /// 返回是否写入。
  static bool prepareResolver(String rootfs, List<String> nameservers) {
    final servers = nameservers
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('#'))
        .toList();
    if (servers.isEmpty) return false;
    final file = io.File('$rootfs/etc/resolv.conf');
    file.parent.createSync(recursive: true);
    final content = servers.map((s) => 'nameserver $s\n').join();
    if (!file.existsSync() || file.readAsStringSync() != content) {
      file.writeAsStringSync(content);
    }
    return true;
  }

  static bool _executable(io.File file) {
    // Windows 文件系统无 POSIX 位：视为可执行（桌面探针不查 x 位）。
    if (io.Platform.isWindows) return true;
    try {
      return file.statSync().mode & 0x49 != 0; // 任一 x 位
    } catch (_) {
      return false;
    }
  }

  /// Windows 文件系统无 POSIX 位：如实跳过（桌面探针不查 x 位）。
  static void _setExecutable(io.File file) {
    if (io.Platform.isWindows) return;
    try {
      io.Process.runSync('chmod', ['755', file.path]);
    } catch (_) {}
  }
}
