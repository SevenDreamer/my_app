// RuntimeToolsLite 冒烟：命令入口 wrapper 字面、python3 链、版本标记、
// resolver 语义（空 = 不写）、证书落位。
// 用法：dart run tool/smoke_runtime_tools.dart
import 'dart:io';

import 'package:dsha_core/dsha_core.dart';

void main() {
  final tmp = Directory.systemTemp.createTempSync('runtime-tools-smoke');
  final rootfs = tmp.path;
  Directory('$rootfs/usr/bin').createSync(recursive: true);
  Directory('$rootfs/usr/local/lib/node_modules/npm/bin').createSync(recursive: true);
  Directory('$rootfs/usr/local/lib/dsha-pnpm/bin').createSync(recursive: true);
  File('$rootfs/usr/bin/python3.12').writeAsStringSync('#!/bin/sh\n');
  File('$rootfs/usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js')
    ..createSync(recursive: true)
    ..writeAsStringSync('// bin\n');

  final touched = RuntimeToolsLite.ensureCommandEntries(rootfs);
  void expect(bool ok, String what) {
    if (!ok) {
      stderr.writeln('SMOKE_FAIL: $what');
      exit(1);
    }
  }

  // wrapper 字面逐字（原版 DshEntrypoint / preparePackageCommands / pnpm）。
  expect(File('$rootfs/root/dsh-bin/dsh').readAsStringSync() ==
          '#!/bin/sh\nexec /usr/local/bin/node /usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js "\$@"\n',
      'dsh wrapper 字面');
  expect(File('$rootfs/root/dsh-bin/npm').readAsStringSync().contains(
      'exec /usr/local/bin/node /usr/local/lib/node_modules/npm/bin/npm-cli.js "\$@"'),
      'npm wrapper 字面');
  final pnpm = File('$rootfs/root/dsh-bin/pnpm').readAsStringSync();
  expect(
      pnpm.contains('npm_config_package_import_method') &&
          pnpm.contains('exec /usr/local/bin/node /usr/local/lib/dsha-pnpm/bin/pnpm.cjs "\$@"'),
      'pnpm wrapper 字面');
  // python3 链 + pnpm 版本标记。
  expect(File('$rootfs/usr/bin/python3').existsSync(), 'python3 链');
  expect(File('$rootfs/root/.dsha-pnpm-version').readAsStringSync().trim() ==
      RuntimeToolsLite.bundledPnpmVersion, 'pnpm 版本标记');
  // 幂等：第二次不动。
  expect(RuntimeToolsLite.ensureCommandEntries(rootfs) == 0, '幂等重入');
  // resolver：空不写；有值写 nameserver 行。
  expect(!RuntimeToolsLite.prepareResolver(rootfs, const []), '空 DNS 不写');
  expect(RuntimeToolsLite.prepareResolver(rootfs, const ['1.1.1.1', ' 8.8.8.8 ']),
      'DNS 写入');
  final resolv = File('$rootfs/etc/resolv.conf').readAsStringSync();
  expect(resolv == 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n', 'resolv 内容');
  // 证书落位。
  RuntimeToolsLite.ensureCertificates(rootfs, [1, 2, 3]);
  expect(File('$rootfs/${RuntimeToolsLite.certPath.substring(1)}').lengthSync() == 3,
      '证书落位');
  tmp.deleteSync(recursive: true);
  print('SMOKE_RUNTIME_TOOLS_PASS (touched=$touched)');
}
