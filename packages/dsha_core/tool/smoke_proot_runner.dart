// ProotRunner 冒烟：argv/env 契约、依赖别名件、shell 语义、缺件降级。
// 用法：dart run tool/smoke_proot_runner.dart
import 'dart:io';

import 'package:dsha_core/dsha_core.dart';

void main() {
  final tmp = Directory.systemTemp.createTempSync('proot-runner-smoke');
  final nativeDir = Directory('${tmp.path}/lib')..createSync();
  final rootfs = Directory('${tmp.path}/rootfs')..createSync();
  // 合成 jniLibs 现货（假体仅验装配，不执行）。
  for (final name in [
    'libproot.so',
    'libprootloader.so',
    'libprootloader32.so',
    'libtalloc.so',
    'libandroidshmem.so',
  ]) {
    File('${nativeDir.path}/$name').writeAsBytesSync(List.filled(64, 1));
  }
  final plan = ProotRunner.plan(
    nativeLibDir: nativeDir.path,
    rootfsPath: rootfs.path,
    tmpDir: '${tmp.path}/proot-tmp',
    libDir: '${tmp.path}/dsha-lib',
    hardlinkSupported: true,
  );
  if (plan == null) {
    stderr.writeln('SMOKE_FAIL: plan 返回 null');
    exit(1);
  }
  // argv 契约逐字（Windows 无 /dev /proc 等 → 绑定应全部跳过）。
  final expected = <String>[
    '${nativeDir.path}/libproot.so',
    '-L',
    '--kill-on-exit',
    '-0',
    '--rootfs=${rootfs.path}',
    '--cwd=/root',
  ];
  final okArgv = plan.argv.length == expected.length &&
      List.generate(expected.length, (i) => plan.argv[i] == expected[i])
          .every((e) => e);
  if (!okArgv) {
    stderr.writeln('SMOKE_FAIL: argv 不符 → ${plan.argv}');
    exit(1);
  }
  // env 契约。
  final env = plan.environment;
  final okEnv = env['PATH'] == ProotRunner.guestPath &&
      env['PROOT_TMP_DIR'] == '${tmp.path}/proot-tmp' &&
      env['PROOT_LOADER'] == '${nativeDir.path}/libprootloader.so' &&
      env['PROOT_LOADER_32'] == '${nativeDir.path}/libprootloader32.so' &&
      env['LD_LIBRARY_PATH'] == '${tmp.path}/dsha-lib:${nativeDir.path}';
  if (!okEnv) {
    stderr.writeln('SMOKE_FAIL: env 不符 → $env');
    exit(1);
  }
  // 依赖别名件（改名拷贝）。
  final okLibs = File('${tmp.path}/dsha-lib/libtalloc.so.2').existsSync() &&
      File('${tmp.path}/dsha-lib/libandroid-shmem.so').existsSync();
  if (!okLibs) {
    stderr.writeln('SMOKE_FAIL: 别名件缺失');
    exit(1);
  }
  // shell 语义：runner 非空 → /bin/bash；缺 proot → null 降级。
  final boot = DesktopBootstrap(
    baseDir: tmp,
    offlineBundle: null,
    expectedVersion: '1.0.0',
    runner: plan.argv,
  );
  if (boot.shell != '/bin/bash') {
    stderr.writeln('SMOKE_FAIL: runner 非空 shell 应为 /bin/bash → ${boot.shell}');
    exit(1);
  }
  File('${nativeDir.path}/libproot.so').deleteSync();
  final degraded = ProotRunner.plan(
    nativeLibDir: nativeDir.path,
    rootfsPath: rootfs.path,
    tmpDir: '${tmp.path}/proot-tmp',
    libDir: '${tmp.path}/dsha-lib',
  );
  if (degraded != null) {
    stderr.writeln('SMOKE_FAIL: 缺 proot 应返回 null');
    exit(1);
  }
  tmp.deleteSync(recursive: true);
  print('SMOKE_PROOT_RUNNER_PASS');
}
