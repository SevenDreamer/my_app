// 版权来源：DSHA（MIT）——派生文件，汇总见 my_app THIRD_PARTY_NOTICES.md。
//! Rust 解包层的 dart:ffi 桥（`dsha_runtime` cdylib）。
//!
//! 契约：`dsha_extract_archive` 返回 0 成功；非 0 时错误文案（机器可读代号
//! `TAR_*` / `ARCHIVE_*` / `COLD_SPLIT_*` 等）在缓冲区内（UTF-8，NUL 结尾），
//! 逐字透传为 [InstallIoException] 消息——不改写、不本地化。
import 'dart:async';
import 'dart:convert' as convert;
import 'dart:ffi' as ffi;
import 'dart:io' as io;
import 'dart:isolate';

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
///
/// 注意：[RustUnpacker.extract] 是**同步** FFI 调用且逐文件 fsync（硬化
/// 语义）——在 UI 隔离岛直跑会冻界面（真机 ANR：Culprit `fsync`）。
/// 生产接线请用 [BackgroundRustArchiveExtractor]；本类保留给测试与
/// 后台隔离岛内部使用。
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

/// 后台隔离岛 Rust 解包器：解包任务全部下沉到常驻 helper 隔离岛
/// （dylib 在岛内加载，进度/结局经 SendPort 回灌），UI 隔离岛只收消息。
/// 错误文案（机器可读代号）逐字透传为 [InstallIoException]，跨岛不变。
class BackgroundRustArchiveExtractor implements ArchiveExtractor {
  BackgroundRustArchiveExtractor._(this._isolate, this._commands, this._events);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _events;
  final Map<int, _PendingExtract> _pending = <int, _PendingExtract>{};
  int _nextId = 1;
  bool _closed = false;

  /// 开岛并加载动态库；库缺位或开岛失败返回 null（调用方显式降级）。
  static Future<BackgroundRustArchiveExtractor?> open() async {
    final events = ReceivePort();
    final isolate = await Isolate.spawn(_extractServer, events.sendPort);
    // ReceivePort 的流只可听一次：单监听分发 ready 与后续事件。
    final ready = Completer<Map<Object?, Object?>>();
    BackgroundRustArchiveExtractor? extractor;
    events.listen((message) {
      if (message is! Map<Object?, Object?>) return;
      if (message['type'] == 'ready') {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      extractor?._onEvent(message);
    });
    final Map<Object?, Object?> first;
    try {
      first = await ready.future;
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      events.close();
      return null;
    }
    if (first['ok'] != true || first['port'] is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      events.close();
      return null;
    }
    extractor = BackgroundRustArchiveExtractor._(
        isolate, first['port']! as SendPort, events);
    return extractor;
  }

  @override
  String get name => 'Rust 硬化解包';

  @override
  Future<void> extract(
    String archivePath,
    String destPath, {
    void Function(int done, int total)? onProgress,
  }) {
    if (_closed) {
      throw const InstallIoException('解包器已关闭');
    }
    final id = _nextId++;
    final pending = _PendingExtract(onProgress);
    _pending[id] = pending;
    _commands.send(<Object, Object>{
      'type': 'extract',
      'id': id,
      'archive': archivePath,
      'dest': destPath,
    });
    return pending.done.future;
  }

  void _onEvent(Object? message) {
    if (message is! Map<Object?, Object?>) return;
    final id = message['id'];
    if (id is! int) return;
    final pending = _pending[id];
    if (pending == null) return;
    switch (message['type']) {
      case 'progress':
        final done = message['done'];
        final total = message['total'];
        if (done is int && total is int) {
          pending.onProgress?.call(done, total);
        }
      case 'done':
        _pending.remove(id);
        if (!pending.done.isCompleted) pending.done.complete();
      case 'error':
        _pending.remove(id);
        if (!pending.done.isCompleted) {
          pending.done.completeError(InstallIoException(
              (message['message'] ?? 'EXTRACT_UNKNOWN').toString()));
        }
    }
  }

  /// 关岛（安装任务收尾/VM 销毁时调用；未决任务以错误结局）。
  void close() {
    if (_closed) return;
    _closed = true;
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _events.close();
    for (final pending in _pending.values) {
      if (!pending.done.isCompleted) {
        pending.done.completeError(const InstallIoException('解包器已关闭'));
      }
    }
    _pending.clear();
  }
}

class _PendingExtract {
  _PendingExtract(this.onProgress);

  final void Function(int done, int total)? onProgress;
  final Completer<void> done = Completer<void>();
}

/// 后台解包服务：常驻 helper 隔离岛入口。岛内加载动态库（isolateLocal
/// 进度回调绑定本岛），命令经 [SendPort] 进、进度/结局回主岛。
Future<void> _extractServer(SendPort events) async {
  final commands = ReceivePort();
  final unpacker = RustUnpacker.load();
  events.send(<Object, Object>{
    'type': 'ready',
    'ok': unpacker != null,
    'port': commands.sendPort,
  });
  if (unpacker == null) {
    commands.close();
    return;
  }
  await for (final message in commands) {
    if (message is! Map<Object?, Object?>) continue;
    if (message['type'] != 'extract') continue;
    final id = message['id'] as int;
    final archive = message['archive'] as String;
    final dest = message['dest'] as String;
    try {
      // 进度节流 50ms：跨岛消息不被逐回调洪水冲击；终值必达。
      var lastSent = DateTime.fromMillisecondsSinceEpoch(0);
      unpacker.extract(archive, dest, onProgress: (done, total) {
        final now = DateTime.now();
        if (done != total &&
            now.difference(lastSent).inMilliseconds < 50) {
          return;
        }
        lastSent = now;
        events.send(<Object, Object>{
          'type': 'progress',
          'id': id,
          'done': done,
          'total': total,
        });
      });
      events.send(<Object, Object>{'type': 'done', 'id': id});
    } on InstallIoException catch (error) {
      events.send(<Object, Object>{
        'type': 'error',
        'id': id,
        'message': error.message,
      });
    } catch (error) {
      events.send(<Object, Object>{
        'type': 'error',
        'id': id,
        'message': error.toString(),
      });
    }
  }
}
