// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.ContainerRuntime.Proot /
// RuntimeLauncher / RuntimeNativeFiles —— 现代化重构，行为契约不变。
//! proot 容器 runner 组装：argv 前缀 + 进程环境 + 依赖别名件准备。
//!
//! 契约逐字保留：argv `-L --kill-on-exit -0 --rootfs=… --cwd=/root` + 九条
//! 绑定（缺则跳过）；env `PATH=/root/dsh-bin:…`、`PROOT_TMP_DIR`、
//! `PROOT_LOADER(_32)`、`LD_LIBRARY_PATH=libDir:prootDir`；proot 依赖
//! `libtalloc.so.2` / `libandroid-shmem.so` 别名件（从 jniLibs 现货拷贝改名）。
//! 硬链接支持（Android app 私有目录 ext4/f2fs）时不启用 --link2symlink——
//! 该扩展会破坏 dsh write 工具。dataDomain 绑定（UserDataBindings）要求
//! rootfs 位于 files/linux/ubuntu 布局，随 RuntimeTools 批统一接，本批缺省
//! 不带（探针/安装命令不受影响）。
import 'dart:io' as io;

/// 组装结果：命令前缀 + 进程环境（交 DesktopBootstrap.runner/environment）。
class ProotRunnerPlan {
  const ProotRunnerPlan(this.argv, this.environment);

  /// 容器命令前缀（proot 本体 + 全部参数；命令由调用方追加）。
  final List<String> argv;

  /// 进程环境增量（合并语义：Process.start includeParentEnvironment）。
  final Map<String, String> environment;
}

class ProotRunner {
  ProotRunner._();

  /// 容器内 PATH（包装命令目录 /root/dsh-bin 在最前——部署契约）。
  static const String guestPath =
      '/root/dsh-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

  /// 九条绑定（原版 ContainerRuntime.binds() 逐字；宿主缺位时跳过）。
  static const List<List<String>> binds = <List<String>>[
    <String>['/dev', '/dev'],
    <String>['/dev/urandom', '/dev/random'],
    <String>['/proc', '/proc'],
    <String>['/sys', '/sys'],
    <String>['/system', '/system'],
    <String>['/apex', '/apex'],
    <String>['/proc/self/fd', '/dev/fd'],
    <String>['/storage/emulated/0', '/sdcard'],
    <String>['/storage/emulated/0', '/storage/emulated/0'],
  ];

  /// 准备依赖别名件（原版 RuntimeNativeFiles.prepare 的拷贝面）：
  /// jniLibs 现货 `libtalloc.so`/`libandroidshmem.so` → libDir 下
  /// `libtalloc.so.2`/`libandroid-shmem.so`（proot 的 DT_NEEDED 名）。
  /// 缺源或超限抛 [io.FileSystemException]（代号逐字）。
  static void prepareLibDir(String prootDir, String libDir) {
    final target = io.Directory(libDir)..createSync(recursive: true);
    const copies = <String, String>{
      'libtalloc.so': 'libtalloc.so.2',
      'libandroidshmem.so': 'libandroid-shmem.so',
    };
    for (final entry in copies.entries) {
      final source = io.File('$prootDir/${entry.key}');
      if (!source.existsSync() ||
          source.lengthSync() < 1 ||
          source.lengthSync() > 16 * 1024 * 1024) {
        throw io.FileSystemException(
            'NATIVE_LIBRARY_SOURCE_INVALID:${entry.key}', source.path);
      }
      final out = io.File('${target.path}/${entry.value}');
      if (!out.existsSync() || out.lengthSync() != source.lengthSync()) {
        source.copySync(out.path);
      }
    }
  }

  /// 组装 runner（不可用返回 null——调用方显式降级，不许静默）。
  ///
  /// [nativeLibDir] = APK jniLibs 提取目录（Android W^X：唯一可执行位）；
  /// [rootfsPath] / [tmpDir] / [libDir] 为容器运行目录。
  static ProotRunnerPlan? plan({
    required String nativeLibDir,
    required String rootfsPath,
    required String tmpDir,
    required String libDir,
    // 原版 RuntimeExecution.install() 的 launch(proot()) 未设 hardlinks →
    // LaunchSpec 默认 false → baseArgv 走 --link2symlink 分支（真机实测
    // link 裸跑被 hardlink 保护拒，dpkg 备份必炸）。
    bool hardlinkSupported = false,
  }) {
    final proot = io.File('$nativeLibDir/libproot.so');
    final loaderName = 'libprootloader.so';
    final loader = io.File('$nativeLibDir/$loaderName');
    if (!proot.existsSync() || proot.lengthSync() == 0) return null;
    if (!loader.existsSync()) return null;
    try {
      prepareLibDir(nativeLibDir, libDir);
    } catch (_) {
      return null;
    }
    io.Directory(tmpDir).createSync(recursive: true);

    final argv = <String>[proot.path];
    // 只有文件系统不支持硬链接时才需要 link2symlink 模拟（会破坏 dsh write 工具）。
    if (!hardlinkSupported) {
      argv.add('--link2symlink');
      final l2s = io.Directory('$rootfsPath/.l2s')..createSync(recursive: true);
      argv.add('-b');
      argv.add('${l2s.path}:${l2s.path}');
    }
    argv.addAll(<String>[
      '-L',
      '--kill-on-exit',
      '-0',
      '--rootfs=$rootfsPath',
      '--cwd=/root',
    ]);
    for (final pair in binds) {
      final host = io.File(pair[0]);
      if (!host.existsSync()) continue; // 缺位跳过（原版语义）
      argv.add('-b');
      argv.add(pair[0] == pair[1] ? pair[0] : '${pair[0]}:${pair[1]}');
    }

    final environment = <String, String>{
      'PATH': guestPath,
      'PROOT_TMP_DIR': tmpDir,
      'PROOT_LOADER': loader.path,
      'LD_LIBRARY_PATH': '$libDir:$nativeLibDir',
    };
    final loader32 = io.File('$nativeLibDir/libprootloader32.so');
    if (loader32.existsSync()) {
      environment['PROOT_LOADER_32'] = loader32.path;
    }
    return ProotRunnerPlan(argv, environment);
  }
}
