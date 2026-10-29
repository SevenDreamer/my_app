// 版权来源：DSHA（MIT）——派生文件，汇总见 my_app THIRD_PARTY_NOTICES.md。
//! Rust 解包层的 dart:ffi 桥（`dsha_runtime` cdylib）。
//!
//! 契约：`dsha_extract_archive` 返回 0 成功；非 0 时错误文案（机器可读代号
//! `TAR_*` / `ARCHIVE_*` / `COLD_SPLIT_*` 等）在缓冲区内（UTF-8，NUL 结尾），
//! 逐字透传为 [InstallIoException] 消息——不改写、不本地化。
import 'dart:convert' as convert;
import 'dart:ffi' as ffi;
import 'dart:io' as io;

import 'package:ffi/ffi.dart';

import 'install_process.dart';
import 'runtime_bootstrap.dart';

typedef _ExtractNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.NativeFunction<_ProgressNative>>,
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.IntPtr,
);
typedef _ProgressNative = ffi.Void Function(
    ffi.Int64, ffi.Int64, ffi.Pointer<ffi.Void>);
typedef _ExtractDart = int Function(
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.NativeFunction<_ProgressNative>>,
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  int,
);

/// Rust 硬化解包引擎（事务解包：限额/身份/NOFOLLOW 边界）。
///
/// 动态库缺位时 [available] 为 false——调用方**不得**静默降级，
/// 由引导层显式选择实现（桌面 tar 命令 vs Rust 引擎）。
class RustUnpacker {
  RustUnpacker._(this._library);

  final ffi.DynamicLibrary _library;
  late final _ExtractDart _extract =
      _library.lookupFunction<_ExtractNative, _ExtractDart>(
          'dsha_extract_archive');

  /// 加载动态库；找不到返回 null（Android 打包 .so、桌面构建 DLL）。
  static RustUnpacker? load({String? path}) {
    final candidates = <String>[
      if (path != null) path,
      if (io.Platform.isWindows) 'dsha_runtime.dll',
      if (io.Platform.isLinux) 'libdsha_runtime.so',
      if (io.Platform.isMacOS) 'libdsha_runtime.dylib',
      if (io.Platform.isAndroid) 'libdsha_runtime.so',
    ];
    for (final candidate in candidates) {
      try {
        return RustUnpacker._(ffi.DynamicLibrary.open(candidate));
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 解包 gzip 归档到 [dest]（全量投影）；进度回调 (done, total)。
  /// 失败抛 [InstallIoException]，消息 = Rust 侧错误代号原文。
  void extract(
    String archivePath,
    String destPath, {
    void Function(int done, int total)? onProgress,
  }) {
    final archive = _cstring(archivePath);
    final dest = _cstring(destPath);
    final error = malloc<ffi.Char>(1024);
    ffi.NativeCallable<_ProgressNative>? callable;
    // dart:ffi 不接受 null 函数指针：无回调时传 nullptr（Rust 侧 Option 语义）。
    var callback =
        ffi.nullptr as ffi.Pointer<ffi.NativeFunction<_ProgressNative>>;
    if (onProgress != null) {
      // 同步调用：isolateLocal 回调在同一线程回灌（close 于 finally）。
      callable = ffi.NativeCallable<_ProgressNative>.isolateLocal(
        (int done, int total, ffi.Pointer<ffi.Void> _) => onProgress(done, total),
      );
      callback = callable.nativeFunction;
    }
    try {
      final code = _extract(archive, dest, callback, ffi.nullptr, error, 1024);
      if (code != 0) {
        final message = error.cast<ffi.Uint8>();
        var end = 0;
        while (end < 1024 && message[end] != 0) {
          end++;
        }
        throw InstallIoException(
            convert.utf8.decode(message.asTypedList(end)));
      }
    } finally {
      callable?.close();
      malloc.free(archive);
      malloc.free(dest);
      malloc.free(error);
    }
  }
}

ffi.Pointer<ffi.Char> _cstring(String value) {
  final units = convert.utf8.encode(value);
  final pointer = malloc<ffi.Char>(units.length + 1);
  final bytes = pointer.cast<ffi.Uint8>().asTypedList(units.length + 1);
  bytes.setAll(0, units);
  bytes[units.length] = 0;
  return pointer;
}

/// Rust 硬化解包引擎的 [ArchiveExtractor] 适配（进度/错误契约同接缝）。
class RustArchiveExtractor implements ArchiveExtractor {
  RustArchiveExtractor(this.unpacker);

  final RustUnpacker unpacker;

  @override
  String get name => 'Rust 硬化解包';

  @override
  Future<void> extract(
    String archivePath,
    String destPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    unpacker.extract(archivePath, destPath, onProgress: onProgress);
  }
}
