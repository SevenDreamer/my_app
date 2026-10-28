// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenJournal / VirtualScreenSessionJournal —— 现代化重构，行为契约不变。
//! 本机秘密与清理凭据；不在 guest/用户备份中，旧代次落盘不能覆盖新代次。
//! 错误契约（逐字）：`VSCREEN_JOURNAL_ROOT_UNAVAILABLE`/`VSCREEN_JOURNAL_INVALID`/
//! `VSCREEN_JOURNAL_LIMIT`/`VSCREEN_JOURNAL_FOREIGN`/`VSCREEN_JOURNAL_LINK`/
//! `VSCREEN_JOURNAL_PERMISSIONS`。
library;

import 'dart:convert';
import 'dart:io';

import 'support.dart';

/// 日志契约（原版 `VirtualScreenJournal`；API23-safe 接口面）。
abstract class VscreenJournal {
  Map<String, Object?>? load();

  bool save(int revision, Map<String, Object?> value);
}

/// POSIX 权限缝（原版 `PosixFileAttributeView.setPermissions("rw-------")`）。
typedef SetPosixPermissions = bool Function(String path, String permissions);

/// 会话日志（原版 `VirtualScreenSessionJournal`）。
class VscreenSessionJournal implements VscreenJournal {
  VscreenSessionJournal({
    required Directory root,
    required String installation,
    required String applicationId,
    SetPosixPermissions? setPosixPermissions,
  })  : _installation = installation,
        _applicationId = applicationId,
        _setPermissions = setPosixPermissions ?? _unsupportedPermissions,
        _path = File('${root.path}${Platform.pathSeparator}vscreen-session-v1.json') {
    if (installation.isEmpty) throw ArgumentError('VSCREEN_JOURNAL_ROOT_UNAVAILABLE');
  }

  final File _path;
  final String _installation;
  final String _applicationId;
  final SetPosixPermissions _setPermissions;
  int _revision = -1;

  @override
  Map<String, Object?>? load() {
    if (!FileSystemEntity.isFileSync(_path.path)) {
      // 原版 NOFOLLOW 存在性判定：不存在返回 null；是链接/非常规文件才是 INVALID。
      if (FileSystemEntity.typeSync(_path.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return null;
      }
      throw const FileSystemException('VSCREEN_JOURNAL_INVALID');
    }
    final type = FileSystemEntity.typeSync(_path.path, followLinks: false);
    if (type != FileSystemEntityType.file ||
        FileSystemEntity.isLinkSync(_path.path) ||
        _path.lengthSync() > 8192) {
      throw const FileSystemException('VSCREEN_JOURNAL_INVALID');
    }
    final bytes = _path.readAsBytesSync();
    if (bytes.length > 8192) throw const FileSystemException('VSCREEN_JOURNAL_LIMIT');
    final value = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    if (value.optInt('schema') != 1 ||
        _installation != value.optString('installation') ||
        _applicationId != value.optString('applicationId')) {
      throw const FileSystemException('VSCREEN_JOURNAL_FOREIGN');
    }
    return value;
  }

  @override
  bool save(int next, Map<String, Object?> value) {
    if (next < _revision) return false;
    value
      ..put('schema', 1)
      ..put('installation', _installation)
      ..put('applicationId', _applicationId);
    final bytes = utf8.encode(jsonEncode(value));
    if (bytes.length > 8192) throw const FileSystemException('VSCREEN_JOURNAL_LIMIT');
    final temporary = File('${_path.path}.pending');
    if (FileSystemEntity.isLinkSync(temporary.path)) {
      throw const FileSystemException('VSCREEN_JOURNAL_LINK');
    }
    final raf = temporary.openSync(mode: FileMode.write);
    try {
      if (FileSystemEntity.typeSync(temporary.path, followLinks: false) !=
              FileSystemEntityType.notFound &&
          !_setPermissions(temporary.path, 'rw-------')) {
        // Windows host 检查只验字节与顺序，从不验 Android 权限接受度。
        if (!Platform.isWindows) throw const FileSystemException('VSCREEN_JOURNAL_PERMISSIONS');
      }
      raf.writeFromSync(bytes);
      raf.flushSync(); // 原版 `output.force(true)`
    } finally {
      raf.closeSync();
    }
    temporary.renameSync(_path.path); // 原版 ATOMIC_MOVE + REPLACE_EXISTING
    _revision = next;
    return true;
  }

  static bool _unsupportedPermissions(String path, String permissions) => false;
}
