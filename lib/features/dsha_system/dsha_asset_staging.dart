//! DSHA 运行时资产暂存：Flutter 资产（pubspec `assets/dsha/`）→ 应用目录文件。
//!
//! 一次性、幂等：`.stamp` 记录「文件名:字节数」清单，磁盘大小一致即跳过
//! （不重复加载 rootBundle 大文件）；暂存完成后供 [FileGuestScriptSource] /
//! [ArchiveOfflineToolSource] 的 io.File 接缝消费（DesktopBootstrap 吃文件路径）。
import 'dart:io' as io;

import 'package:flutter/services.dart';

/// 暂存结果：目录 + 关键文件句柄。
class StagedDshaAssets {
  const StagedDshaAssets(this.dir);

  final io.Directory dir;

  String path(String name) => '${dir.path}/$name';

  io.File file(String name) => io.File(path(name));
}

class DshaAssetStaging {
  /// 资产清单（APK 内 `assets/dsha/` 逐件；子目录 licenses/ 单列——
  /// Flutter 目录声明不递归）。
  static const List<String> files = <String>[
    'offline-rootfs.bin',
    'glibc-python.tar.gz',
    'python-support.bin',
    'pnpm-runtime.bin',
    'ubuntu-tools.bin',
    'adb-wheels.bin',
    'ca-certificates.crt',
    'adb-setup.sh',
    'dsha-device-shell.sh',
    'dsha-plugin.sh',
    'dsha-runtime-env.sh',
    'install-basic-tools.sh',
    'install-ubuntu-tools.sh',
    'licenses/certifi-LICENSE.txt',
  ];

  static const String _assetRoot = 'assets/dsha';

  /// 暂存全部资产到 [target]（幂等；缺损件自动重拷）。
  static Future<StagedDshaAssets> stage(io.Directory target) async {
    target.createSync(recursive: true);
    final stamp = io.File('${target.path}/.stamp');
    final known = <String, int>{};
    if (stamp.existsSync()) {
      for (final line in (await stamp.readAsString()).split('\n')) {
        final sep = line.lastIndexOf(':');
        if (sep > 0) {
          final size = int.tryParse(line.substring(sep + 1));
          if (size != null) known[line.substring(0, sep)] = size;
        }
      }
    }
    final sizes = <String, int>{};
    for (final name in files) {
      final out = io.File('${target.path}/$name');
      if (out.existsSync() && known[name] == out.lengthSync()) {
        sizes[name] = out.lengthSync();
        continue;
      }
      final data = await rootBundle.load('$_assetRoot/$name');
      out.parent.createSync(recursive: true);
      await out.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true);
      sizes[name] = data.lengthInBytes;
    }
    await stamp.writeAsString(
        sizes.entries.map((e) => '${e.key}:${e.value}').join('\n'));
    return StagedDshaAssets(target);
  }
}
