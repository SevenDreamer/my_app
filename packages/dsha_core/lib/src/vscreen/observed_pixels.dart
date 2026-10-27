// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenObservedPixels —— 现代化重构，行为契约不变。
//! Agent-see-only 不可变原始快照；原生预览帧永不进入此属主。
//! 错误契约（逐字）：`FRAME_NOT_READY`/`OBSERVATION_IMAGE_BUDGET`/`STALE_GENERATION`/
//! `OBSERVATION_IMAGE_UNAVAILABLE`/`FRAME_ENCODE_FAILED`/`OBSERVATION_EXPIRED`/
//! `TOUCH_IN_PROGRESS`/`INVALID_ANCHOR_REGION`/`ANCHOR_REGION_CHANGED`。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'display_session.dart';
import 'support.dart';

/// 原版常量：字节上限 24MiB、TTL 30s、条目上限 2。
const int observedPixelsByteLimit = 24 * 1024 * 1024;
const int observedPixelsTtlMs = 30 * 1000;
const int observedPixelsCountLimit = 2;

class _Entry {
  _Entry(this.raw, this.sequence, this.generation, this.packageName, this.created)
      : bytes = raw.allocationByteCount;

  final String id = vscreenUuid();
  final RawFrame raw;
  final int sequence;
  final int created;
  final int bytes;
  final String generation;
  final String packageName;
}

/// 观察像素库（原版 `VirtualScreenObservedPixels`）。
class VscreenObservedPixels {
  VscreenObservedPixels({required VscreenClock clock}) : _clock = clock;

  final VscreenClock _clock;
  final Map<String, _Entry> _entries = <String, _Entry>{};
  int _allocated = 0;

  /// 原版 `capture(session, metadata)`（单 isolate 同步运行即临界区语义；
  /// `synchronized(session.lock)` 段在同步代码内天然不可分割）。
  Map<String, Object?> capture(
    VscreenDisplaySession session,
    Map<String, Object?> Function() metadata,
  ) {
    prune(_clock.millis());
    _Entry? entry;
    Map<String, Object?>? value;
    var published = false;
    try {
      if (!session.active || session.frame == null) {
        return vscreenFailure('FRAME_NOT_READY', false);
      }
      final required = session.frame!.allocationByteCount;
      if (required <= 0 || required > observedPixelsByteLimit) {
        return vscreenFailure('OBSERVATION_IMAGE_BUDGET', false);
      }
      while (_entries.isNotEmpty &&
          (_entries.length >= observedPixelsCountLimit ||
              _allocated + required > observedPixelsByteLimit)) {
        _remove(_entries.keys.first);
      }
      value = metadata();
      if (!value.optBoolean('ok') ||
          !value.optBoolean('active') ||
          value.optInt('displayId', -1) != session.id ||
          session.generation != value.optString('generation')) {
        return vscreenFailure('STALE_GENERATION', false);
      }
      final copy = session.frame!.copy();
      if (copy == null) {
        return vscreenFailure('OBSERVATION_IMAGE_UNAVAILABLE', false);
      }
      entry = _Entry(copy, session.sequence, session.generation,
          value.optString('package'), _clock.millis());
      if (entry.bytes <= 0 ||
          _allocated + entry.bytes > observedPixelsByteLimit) {
        copy.recycle();
        return vscreenFailure('OBSERVATION_IMAGE_BUDGET', false);
      }
      // Agent 坐标直接寻址这份保留的原始来源。这里放 720px 缩略图会让
      // 模型看到的按钮坐标与语义/原始锚点对不上；原生预览的缩略图
      // 路径在 VirtualScreenPixels 里，两者分离。
      final width = entry.raw.width, height = entry.raw.height;
      final encoded = entry.raw.encodeJpeg(65);
      if (encoded.isEmpty) {
        return vscreenFailure('FRAME_ENCODE_FAILED', false);
      }
      value
        ..put('frameSeq', entry.sequence)
        ..put('sourceFrameSeq', entry.sequence)
        ..put('observationId', entry.id)
        ..put('observationBytes', entry.bytes)
        ..put('observationCreatedElapsedMillis', entry.created)
        ..put('previewWidth', width)
        ..put('previewHeight', height)
        ..put('previewB64', base64Encode(encoded));
      if (!session.active || session.generation != entry.generation) {
        return vscreenFailure('STALE_GENERATION', false);
      }
      // 旧的不可变快照不续期：保持 legacy observed/latest 门精确。
      if (session.sequence == entry.sequence) {
        session.observed = entry.sequence;
        session.observedAt = _clock.millis();
      }
      _entries[entry.id] = entry;
      _allocated += entry.bytes;
      published = true;
      return value;
    } finally {
      if (!published && entry != null) {
        entry.raw.recycle();
      }
    }
  }

  /// 原版 `region(session, id, bounds)`：锚点区域哈希比对。
  Map<String, Object?> region(
      VscreenDisplaySession session, String id, VscreenRect bounds) {
    prune(_clock.millis());
    final entry = _entries[id];
    if (entry == null) {
      return vscreenFailure('OBSERVATION_EXPIRED', false);
    }
    if (!session.active ||
        session.frame == null ||
        entry.generation != session.generation ||
        entry.raw.width != session.frame!.width ||
        entry.raw.height != session.frame!.height) {
      return vscreenFailure('STALE_GENERATION', false);
    }
    if (session.input.active()) {
      return vscreenFailure('TOUCH_IN_PROGRESS', false);
    }
    if (bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right > entry.raw.width ||
        bounds.bottom > entry.raw.height ||
        bounds.isEmpty()) {
      return vscreenFailure('INVALID_ANCHOR_REGION', false);
    }
    final equal = _constantTimeBytesEqual(
      hashRegion(entry.raw, bounds),
      hashRegion(session.frame!, bounds),
    );
    return (equal
        ? <String, Object?>{'ok': true}
        : vscreenFailure('ANCHOR_REGION_CHANGED', false))
      ..put('sourceFrameSeq', entry.sequence)
      ..put('validatedCurrentSeq', session.sequence)
      ..put('generation', entry.generation)
      ..put('displayId', session.id);
  }

  /// 区域像素摘要（原版 `hash(Bitmap, Rect)`：逐行取像素，ARGB 大端 4 字节进
  /// SHA-256）。哈希引擎接线轮迁 dsha_runtime；打包字节序契约在此钉死。
  static List<int> hashRegion(RawFrame image, VscreenRect region) {
    final packed = BytesBuilder();
    for (var y = region.top; y < region.bottom; y++) {
      final row =
          image.regionPixels(VscreenRect(region.left, y, region.right, y + 1));
      for (final pixel in row) {
        packed.add([
          (pixel >>> 24) & 0xff,
          (pixel >>> 16) & 0xff,
          (pixel >>> 8) & 0xff,
          pixel & 0xff,
        ]);
      }
    }
    return sha256.convert(packed.toBytes()).bytes;
  }

  void prune(int now) {
    final expired = <String>[];
    for (final entry in _entries.values) {
      if (now < entry.created || now - entry.created > observedPixelsTtlMs) {
        expired.add(entry.id);
      }
    }
    for (final id in expired) {
      _remove(id);
    }
  }

  void remove(String id) => _remove(id);

  void clear() {
    for (final entry in _entries.values) {
      entry.raw.recycle();
    }
    _entries.clear();
    _allocated = 0;
  }

  int allocatedBytes() => _allocated;

  int retainedCount() => _entries.length;

  void _remove(String id) {
    final entry = _entries.remove(id);
    if (entry != null) {
      _allocated -= entry.bytes;
      entry.raw.recycle();
    }
  }
}

/// 字节常时比较（原版 `MessageDigest.isEqual`）。
bool _constantTimeBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
