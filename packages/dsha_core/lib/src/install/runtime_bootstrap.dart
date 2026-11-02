// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.ProotBootstrap /
// AndroidGroups / BasicToolsInstaller —— 现代化重构，行为契约不变。
//! 运行时引导接缝：环境就绪判定、离线解压、容器命令执行、工具修复。
//! 原版由 ProotBootstrap 委托 RuntimeInstallationState/RuntimeExecution/
//! ColdBundleTransaction/RootfsInstaller 协作完成；本层先给出可替换接缝
//! [RuntimeBootstrap] 与桌面实现 [DesktopBootstrap]（Android 原生实现随后接入，
//! 解压最终由 Rust 解包层（cold_split/archive）承担）。
library;

import 'dart:convert' as convert;
import 'dart:io' as io;

import 'install_probe.dart';
import 'install_process.dart';
import 'runtime_tools.dart';
import 'install_stage.dart';

/// 运行时引导接缝（原版 `ProotBootstrap` 被 LocalEnvironment 用到的表面）。
abstract interface class RuntimeBootstrap {
  /// 环境就绪（解压标记、版本与 bash 在位；原版
  /// `isOfflineExtracted && hasBash && rootfsVersionMatches`）。
  Future<bool> isEnvironmentReady();

  Future<bool> hasBash();

  Future<bool> rootfsVersionMatches();

  io.Directory getRootfsDir();

  /// 离线包在位（原版：APK 内 bundle 条目或资产存在）。
  Future<bool> hasOfflineBundle();

  /// 解压离线环境；onProgress(done, total) 按字节回报
  /// （原版 `extractOfflineBundle(BiConsumer<Long,Long>)`）。
  Future<void> extractOfflineBundle(void Function(int done, int total) onProgress);

  /// 补齐离线 pnpm（原版 `RootfsInstaller.ensurePnpm`）。
  Future<bool> ensureBundledPnpm();

  /// 补齐离线 Python（原版 `RootfsInstaller.ensurePython`）。
  Future<bool> ensureBundledPython();

  /// 补齐 Android 用户组（原版 `execution.prepareGroups` → AndroidGroups.prepare）。
  Future<void> ensureAndroidGroups();

  /// 在容器内执行安装命令（原版 `execution.install(command, false)`）。
  Future<io.Process> execRootfsForInstall(String command);

  /// 同上但保留 stdin 管道（原版 `execution.install(command, true)`）。
  Future<io.Process> execRootfsForInstallWithPipedInput(String command);

  /// 随包证书与命令入口（原版 `RuntimeTools.prepare(context, rootfsDir)`）。
  Future<void> prepareRuntimeTools();
}

/// Android 用户组映射（原版 `AndroidGroupMap` 逐表逐分支保真）：
/// 「Android groups derive app/user identities from the current UID,
/// never a development handset.」
class AndroidGroupMap {
  AndroidGroupMap._();

  static const Map<int, String> common = <int, String>{
    1004: 'input',
    1007: 'log',
    1011: 'adb',
    1015: 'sdcard_rw',
    1028: 'sdcard_r',
    1078: 'ext_data_rw',
    1079: 'ext_obb_rw',
    3001: 'net_bt_admin',
    3002: 'net_bt',
    3003: 'inet',
    3006: 'net_bw_stats',
    3009: 'readproc',
    3011: 'uhid',
    3012: 'readtracefs',
    9997: 'everybody',
  };

  /// 从 `/proc/self/status` 文本提取 Groups 行（正整数去重保序）。
  static List<int> groups(String procStatus) {
    final result = <int>[];
    for (final line in procStatus.split('\n')) {
      if (line.startsWith('Groups:')) {
        for (final value in line.substring(7).trim().split(RegExp(r'\s+'))) {
          final gid = int.tryParse(value);
          if (gid != null && gid > 0 && gid < 0x7fffffff && !result.contains(gid)) {
            result.add(gid);
          }
        }
        break;
      }
    }
    return List<int>.unmodifiable(result);
  }

  /// 把缺失的组追加进 etc/group 内容（gid 冲突时名字退化 `aid_<gid>`，再冲突跳过）。
  static String appendMissing(String content, int uid, List<int> actual) {
    final present = <int>{};
    final names = <String>{};
    for (final line in content.split('\n')) {
      final fields = line.split(':');
      if (fields.length != 4) continue;
      names.add(fields[0]);
      final gid = int.tryParse(fields[2]);
      if (gid != null) present.add(gid);
    }
    final requested = <int, String>{...common};
    final app = uid % 100000;
    final user = uid ~/ 100000;
    if (uid > 0) {
      requested.putIfAbsent(
          uid,
          () => app >= 10000 && app <= 19999
              ? 'u${user}_a${app - 10000}'
              : 'aid_$uid');
    }
    for (final gid in actual) {
      if (gid > 0 && gid < 0x7fffffff) {
        requested.putIfAbsent(gid, () => 'aid_$gid');
      }
    }
    final keys = requested.keys.toList()..sort();
    final append = StringBuffer();
    for (final key in keys) {
      if (!present.contains(key)) {
        var name = requested[key]!;
        if (names.contains(name)) name = 'aid_$key';
        if (names.contains(name)) continue;
        names.add(name);
        append.write('$name:x:$key:\n');
      }
    }
    if (append.isEmpty) return content;
    return content +
        (content.isEmpty || content.endsWith('\n') ? '' : '\n') +
        append.toString();
  }
}

/// 客房脚本/资产来源（原版从 APK assets 读）。
abstract interface class GuestScriptSource {
  List<int> read(String assetName);
}

/// 离线工具源（原版 `RootfsInstaller` 从 APK 内离线包补齐 pnpm/Python）。
abstract interface class OfflineToolSource {
  /// pnpm 离线文件集：资产名 → 字节。
  Map<String, List<int>>? pnpmFiles();

  Map<String, List<int>>? pythonFiles();
}

/// 归档形态离线工具源：pnpm/python 以 .tar.gz 归档整包提供，
/// [DesktopBootstrap] 经解包接缝直接铺进 rootfs（原版 RootfsInstaller
/// 解包投递语义；映射形态见 [OfflineToolSource]）。
abstract interface class ArchiveToolSource implements OfflineToolSource {
  /// python 归档路径集（glibc-python.tar.gz + python-support.bin 顺序）。
  List<String> pythonArchives();

  /// pnpm 归档路径集（pnpm-runtime.bin）。
  List<String> pnpmArchives();

  /// dsh 运行时归档路径集（dsh-runtime.bin——cold_split 的 runtime 流）。
  List<String> dshArchives();
}

/// 归档形态实现（映射形态返回 null：本形态不提供文件映射）。
class ArchiveOfflineToolSource implements ArchiveToolSource {
  ArchiveOfflineToolSource(
      {required this.python, required this.pnpm, this.dsh = const <String>[]});

  final List<String> python;
  final List<String> pnpm;
  final List<String> dsh;

  @override
  Map<String, List<int>>? pnpmFiles() => null;

  @override
  Map<String, List<int>>? pythonFiles() => null;

  @override
  List<String> pythonArchives() => python;

  @override
  List<String> pnpmArchives() => pnpm;

  @override
  List<String> dshArchives() => dsh;
}

/// 文件系统 guest 脚本源（APK 资产暂存到本地后的同步读取面）。
class FileGuestScriptSource implements GuestScriptSource {
  FileGuestScriptSource(this.dir);

  final io.Directory dir;

  @override
  List<int> read(String assetName) =>
      io.File('${dir.path}/$assetName').readAsBytesSync();
}

/// 归档解包接缝（原版 ColdBundleTransaction 的解包投递面）。
/// 实现：[TarCommandExtractor]（桌面系统 tar）/ rust_unpack.dart 的
/// RustArchiveExtractor（硬化引擎：限额/身份/NOFOLLOW 边界）。
abstract interface class ArchiveExtractor {
  /// 解包 gzip 归档到 dest；onProgress(done, total) 逐字节回报。
  /// 失败抛 [InstallIoException]（机器代号/文案原样透传）。
  Future<void> extract(
    String archivePath,
    String destPath, {
    void Function(int done, int total)? onProgress,
  });

  /// 引擎名（UI 显示用——所用实现必须可见，不许静默降级）。
  String get name;
}

/// 系统 tar 解包（桌面引导模式；流式喂 stdin 逐字节报进度）。
class TarCommandExtractor implements ArchiveExtractor {
  const TarCommandExtractor();

  @override
  String get name => '系统 tar';

  @override
  Future<void> extract(
    String archivePath,
    String destPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final bundle = io.File(archivePath);
    if (!bundle.existsSync()) {
      throw const io.FileSystemException('离线包不存在');
    }
    final total = await bundle.length();
    io.Directory(destPath).createSync(recursive: true);
    // 流式喂给 tar：读多少报多少（原版 ColdBundleTransaction 的逐字节进度）。
    final process = await io.Process.start(
      'tar',
      ['-xzf', '-', '-C', destPath],
      environment: <String, String>{},
    );
    var done = 0;
    final sink = process.stdin;
    final source = bundle.openRead();
    final feeder = source.listen((chunk) {
      sink.add(chunk);
      done += chunk.length;
      onProgress?.call(done, total);
    }, onError: (Object error) {
      sink.addError(error);
    }, onDone: () {
      sink.close();
    }, cancelOnError: true);
    final code = await process.exitCode.timeout(
        const Duration(minutes: 10), onTimeout: () => -1);
    await feeder.cancel();
    if (code != 0) {
      throw io.FileSystemException('离线包解压失败（tar 退出码 $code）');
    }
  }
}

/// 桌面实现：rootfs 目录 + 归档解包 + bash 容器映射。
///
/// 刻意边界：解包经 [ArchiveExtractor] 接缝（系统 tar / Rust 硬化引擎）；
/// 容器映射为「rootfs 为工作目录的宿主 bash」（Android 轮为 proot argv）。
/// 所有行为真实，不存在假结果：缺件一律如实返回 false / 抛错。
class DesktopBootstrap implements RuntimeBootstrap {
  DesktopBootstrap({
    required this.baseDir,
    required this.offlineBundle,
    required this.expectedVersion,
    this.uid = 10000,
    this.statusSource = '/proc/self/status',
    this.guestScripts,
    this.offlineTools,
    this.runner,
    this.environment,
    this.deviceDns = const <String>[],
    this.extractor = const TarCommandExtractor(),
  });

  final io.Directory baseDir;
  final io.File? offlineBundle;

  /// 环境身份（原版 `offline-rootfs.version` 内容比对串：
  /// 离线资产版本 + versionCode + dsh 版本的组合）。
  final String expectedVersion;

  /// 宿主 UID（原版 `android.os.Process.myUid()`；Android 轮接真值）。
  final int uid;

  /// `/proc/self/status` 来源（桌面可注入；原版固定读 /proc/self/status）。
  final String statusSource;
  final GuestScriptSource? guestScripts;
  final OfflineToolSource? offlineTools;

  /// 容器命令前缀（默认宿主 bash；Android 轮为 proot 包装）。
  final List<String>? runner;

  /// 设备 DNS（原版 prepareResolver 的设备 nameserver 来源；空 = 拿不到
  /// 真值，resolver 如实跳过）。
  final List<String> deviceDns;

  /// 进程环境增量（proot 轮的 PATH/PROOT_LOADER/LD_LIBRARY_PATH 等；
  /// 合并语义：Process.start includeParentEnvironment）。
  final Map<String, String>? environment;

  /// 归档解包实现（缺省系统 tar；注入 RustArchiveExtractor 即硬化引擎）。
  final ArchiveExtractor extractor;

  /// 显式 shell（默认解析 git-bash；绝不落到 WSL System32\bash.exe——
  /// 其 argv 翻译会吃掉引号，实测把 `"$code"` 吞成空）。
  /// runner 非空 = 命令在容器内执行，用容器内 /bin/bash（原版
  /// RuntimeLauncher 固定 `/bin/bash` 字面）。
  static String resolveShell() {
    final override = io.Platform.environment['DSHA_BASH'];
    if (override != null && override.isNotEmpty) return override;
    final candidates = <String>[
      'C:/Program Files/Git/bin/bash.exe',
      'C:/Program Files/Git/usr/bin/bash.exe',
    ];
    for (final path in candidates) {
      if (io.File(path).existsSync()) return path;
    }
    return 'bash';
  }

  late final String shell = runner != null ? '/bin/bash' : resolveShell();

  io.Directory get rootfsDir => io.Directory('${baseDir.path}/rootfs');

  static const String versionMarker = 'offline-rootfs.version';

  Future<bool> _hasBash() async =>
      io.File('${rootfsDir.path}/bin/bash').existsSync();

  @override
  Future<bool> hasBash() => _hasBash();

  @override
  Future<bool> rootfsVersionMatches() async {
    final marker = io.File('${rootfsDir.path}/$versionMarker');
    if (!marker.existsSync()) return false;
    return (await marker.readAsString()).trim() == expectedVersion;
  }

  @override
  Future<bool> isEnvironmentReady() async =>
      await rootfsVersionMatches() && await _hasBash();

  @override
  io.Directory getRootfsDir() => rootfsDir;

  @override
  Future<bool> hasOfflineBundle() async {
    final bundle = offlineBundle;
    return bundle != null && bundle.existsSync();
  }

  @override
  Future<void> extractOfflineBundle(
      void Function(int done, int total) onProgress) async {
    final bundle = offlineBundle;
    if (bundle == null || !bundle.existsSync()) {
      throw const io.FileSystemException('离线包不存在');
    }
    rootfsDir.createSync(recursive: true);
    await extractor.extract(
      bundle.path,
      rootfsDir.path,
      onProgress: onProgress,
    );
    // cold_split 双流合成（原版 ColdBundleTransaction）：base 流（offline-
    // rootfs）之后叠 runtime 流（dsh 全家桶）——初装一步到位。
    final source = offlineTools;
    if (source is ArchiveToolSource) {
      await _extractToolArchives(source.dshArchives());
    }
    await io.File('${rootfsDir.path}/$versionMarker')
        .writeAsString('$expectedVersion\n');
  }

  @override
  Future<bool> ensureBundledPnpm() async {
    final source = offlineTools;
    if (source is ArchiveToolSource) {
      final archives = source.pnpmArchives();
      if (archives.isEmpty) return false;
      await _extractToolArchives(archives);
      return true;
    }
    final files = source?.pnpmFiles();
    if (files == null || files.isEmpty) return false;
    _writeToolFiles(files);
    return true;
  }

  @override
  Future<bool> ensureBundledPython() async {
    final source = offlineTools;
    if (source is ArchiveToolSource) {
      final archives = source.pythonArchives();
      if (archives.isEmpty) return false;
      await _extractToolArchives(archives);
      return true;
    }
    final files = source?.pythonFiles();
    if (files == null || files.isEmpty) return false;
    _writeToolFiles(files);
    return true;
  }

  /// 归档形态：逐个解包进 rootfs（glibc-python 先、python-support 后补
  /// soname——RootfsInstaller.python 的顺序语义由调用方列表次序保证）。
  Future<void> _extractToolArchives(List<String> archives) async {
    for (final path in archives) {
      final archive = io.File(path);
      if (!archive.existsSync()) {
        throw io.FileSystemException('离线工具归档不存在', path);
      }
      rootfsDir.createSync(recursive: true);
      await extractor.extract(archive.path, rootfsDir.path);
    }
  }

  void _writeToolFiles(Map<String, List<int>> files) {
    for (final entry in files.entries) {
      final target = io.File('${rootfsDir.path}/${entry.key}');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(entry.value);
    }
  }

  @override
  Future<void> ensureAndroidGroups() async {
    // 原版 AndroidGroups.prepare：组文件 1 MiB 上限 + 拒绝符号链接；
    // bashrc 里 `$(groups) ` 加 stderr 屏蔽。
    final root = rootfsDir.path;
    final group = io.File('$root/etc/group');
    if (!group.existsSync() ||
        _isLink(group) ||
        (group.lengthSync() > 1024 * 1024)) {
      throw const io.FileSystemException('ANDROID_GROUP_FILE_UNAVAILABLE');
    }
    final current = await group.readAsString();
    final status = await io.File(statusSource).readAsString();
    final updated =
        AndroidGroupMap.appendMissing(current, uid, AndroidGroupMap.groups(status));
    if (updated != current) {
      await group.writeAsString(updated);
    }
    final bashrc = io.File('$root/etc/bash.bashrc');
    if (!bashrc.existsSync() ||
        _isLink(bashrc) ||
        (bashrc.lengthSync() > 1024 * 1024)) {
      throw const io.FileSystemException('ANDROID_BASHRC_UNAVAILABLE');
    }
    final before = await bashrc.readAsString();
    final after = before.replaceAll('\$(groups) ', '\$(groups 2>/dev/null) ');
    if (before != after) {
      await bashrc.writeAsString(after);
    }
  }

  bool _isLink(io.File file) {
    try {
      return io.Link(file.path).existsSync();
    } catch (_) {
      return false;
    }
  }

  List<String> _argv(String command) =>
      <String>[...?runner, shell, '-c', command];

  @override
  Future<io.Process> execRootfsForInstall(String command) async {
    // 脚本走 stdin（bash -s）：绕开 argv 引号翻译（WSL bash.exe 会吞 `"..."`）。
    final r = runner;
    final process = await io.Process.start(
      r?.first ?? shell,
      <String>[
        if (r != null) ...r.skip(1),
        if (r != null) shell,
        '-s',
      ],
      workingDirectory: rootfsDir.path,
      environment: environment,
    );
    process.stdin.add(convert.utf8.encode(command));
    await process.stdin.close();
    return process;
  }

  @override
  Future<io.Process> execRootfsForInstallWithPipedInput(String command) =>
      io.Process.start(_argv(command).first, _argv(command).sublist(1),
          workingDirectory: rootfsDir.path, environment: environment);

  @override
  Future<void> prepareRuntimeTools() async {
    // dsh 缺失补装先行（后续入口 chmod 能碰到 bin.js 的 x 位）：
    // 只补缺，不覆盖已存在的用户升级件（「不覆盖用户升级的 Node/dsh」语义）。
    await ensureBundledDsh();
    // 原版 RuntimeTools.prepare 第一批：随包证书 + 命令入口 + DNS。
    // 补丁链（applyPatchChain 四专项）与托管资产 overlay 随第二批。
    RuntimeToolsLite.ensureCommandEntries(rootfsDir.path);
    final scripts = guestScripts;
    if (scripts != null) {
      RuntimeToolsLite.ensureCertificates(
          rootfsDir.path, scripts.read('ca-certificates.crt'));
    }
    RuntimeToolsLite.prepareResolver(rootfsDir.path, deviceDns);
  }

  /// dsh 运行时缺失补装：包目录不存在才解 dsh-runtime 归档。
  Future<void> ensureBundledDsh() async {
    final source = offlineTools;
    if (source is! ArchiveToolSource) return;
    final archives = source.dshArchives();
    if (archives.isEmpty) return;
    final pkg = io.Directory(
        '${rootfsDir.path}/usr/local/lib/node_modules/@deepseek-ai/dsh');
    if (pkg.existsSync()) return; // 在位即不覆盖（用户升级件受保护）
    await _extractToolArchives(archives);
  }
}

/// 基础工具修复（原版 `BasicToolsInstaller.repair` 逐句保真）。
class BasicToolsInstaller {
  BasicToolsInstaller(this.bootstrap, this.guestScripts);

  final RuntimeBootstrap bootstrap;
  final GuestScriptSource? guestScripts;

  Future<void> repair(InstallProbeResults checked, InstallTask task) async {
    if (checked.okStep(2)) return;
    task.stage(2, '修复第 2 步：准备随包证书与命令入口', cancellable: false);
    await bootstrap.prepareRuntimeTools();
    task.append('随包证书与命令入口已核对');
    task.checkCancelled();
    if (!checked.ok('python')) {
      task.stage(2, '修复第 2 步：补齐离线 Python', cancellable: false);
      if (!await bootstrap.ensureBundledPython()) {
        throw const io.FileSystemException(
            '离线 Python 修复失败；请检查可用空间与安装包完整性');
      }
      task.append('离线 Python 文件已补齐，稍后验证实际运行结果');
    }
    task.checkCancelled();
    if (checked.ok('curl') && checked.ok('git')) return;
    final source = guestScripts;
    if (source == null) {
      throw const io.FileSystemException('install-basic-tools.sh 资产未配置');
    }
    final script = source.read('install-basic-tools.sh');
    // dpkg 中断自愈（官方恢复法 `dpkg --configure -a`；幂等）：apt 断流
    // 死在半截会留「E: dpkg was interrupted」残留。真机发现 configure 自身
    // 写 status-old 报 Permission denied——先取现场（属主/id/可写性）再试
    // 自愈（删 status-old 让 dpkg 重建），失败信息全留日志定真因。
    final heal = await bootstrap.execRootfsForInstall(
        'echo "--- dpkg 自愈现场 ---"; ls -la /var/lib/dpkg/ 2>&1; id; '
        'ls -la /var/lib/ 2>&1 | head -5; '
        'rm -f /var/lib/dpkg/status-old 2>&1; '
        'dpkg --configure -a 2>&1; echo "dpkg-heal-exit:\$?"');
    await InstallProcess.read(heal,
        timeoutMs: 120000,
        cancellable: false,
        cancelled: task.cancellationRequested,
        output: task.append,
        destroy: (proc) => proc.kill(io.ProcessSignal.sigkill));
    task.checkCancelled();
    task.stage(2, '修复第 2 步：联网补齐 curl / git（取消将在本轮软件包操作后生效）',
        cancellable: false);
    final process =
        await bootstrap.execRootfsForInstallWithPipedInput('bash');
    process.stdin.add(script);
    await process.stdin.close();
    // apt/dpkg 写入期间不响应取消；结束后再到安全点。
    final code = await InstallProcess.read(process,
        timeoutMs: 900000,
        cancellable: false,
        cancelled: task.cancellationRequested,
        output: (line) {
          if (line != 'DSHA_TOOLS_OK') task.append(line);
        },
        destroy: (proc) => proc.kill(io.ProcessSignal.sigkill));
    if (code != 0) {
      throw io.FileSystemException(
          '基础工具安装失败（退出码 $code），请查看上方软件源/网络输出');
    }
  }
}
