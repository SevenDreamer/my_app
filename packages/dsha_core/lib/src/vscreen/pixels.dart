// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenPixels —— 现代化重构，行为契约不变。
//! 像素采集/观察不承担控件树授权；status 不会登记一次观察。
//! 错误契约（逐字）：`FRAME_NOT_READY`/`FRAME_ENCODE_FAILED`/`STALE_FRAME`/`STALE_GENERATION`。
library;

import 'dart:async';
import 'dart:convert';

import 'display_session.dart';
import 'support.dart';

/// 平台编码面（原版 `Encoder`；测试只替换编码结果）。
typedef VscreenEncoder = bool Function(RawFrame frame, List<int> output);

/// 元数据面（原版 `VirtualScreenPixels.Metadata.get()`）。
typedef VscreenMetadata = Map<String, Object?> Function();

/// 像素采集/预览（原版 `VirtualScreenPixels`）。
class VscreenPixels {
  /// 原版守护线程 "vscreen-frames"：33ms 节拍、同帧不计号。
  static void start(VscreenDisplaySession session) {
    unawaited(_pump(session));
  }

  static Future<void> _pump(VscreenDisplaySession session) async {
    while (session.active) {
      session.observations.prune(session.elapsed());
      RawFrame? next;
      try {
        next = session.reader!.acquireLatestFrame(session.width, session.height);
        if (next != null) {
          if (!session.active) {
            next.recycle();
            return;
          }
          final previous = session.frame;
          if (previous != null && previous.sameAs(next)) {
            next.recycle();
          } else {
            previous?.recycle();
            session.frame = next;
            session.sequence++;
          }
          session.capturedAt = session.elapsed();
        }
      } catch (e) {
        // 帧暂不可用不重建显示，也不伪造帧号。
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 33));
      } on Exception {
        return;
      }
    }
  }

  /// 生产预览（平台 JPEG 编码）。
  static Map<String, Object?> preview(VscreenDisplaySession session,
      int since, String generation, VscreenMetadata metadata) {
    return previewWith(session, since, generation, metadata,
        (frame, output) {
      final bytes = frame.encodeJpeg(65);
      if (bytes.isEmpty) {
        return false;
      }
      output.addAll(bytes);
      return true;
    });
  }

  /// 测试只替换平台编码结果；帧选择、发布与观察登记仍使用生产路径。
  static Map<String, Object?> previewWith(VscreenDisplaySession session,
      int since, String generation, VscreenMetadata metadata,
      VscreenEncoder encoder) {
    RawFrame? copy;
    RawFrame? scaled;
    late int sequence, captured;
    var encoded = '';
    var unchanged = false;
    late int width, height;
    if (!session.active || session.frame == null) {
      return vscreenFailure('FRAME_NOT_READY', false);
    }
    sequence = session.sequence;
    captured = session.capturedAt;
    width = session.frame!.width < 720 ? session.frame!.width : 720;
    // 原版 `Math.round(h * width / (float) w)`。
    height = (session.frame!.height * width / session.frame!.width).round();
    encoded = session.encodedSequence == sequence ? session.encoded : '';
    unchanged =
        encoded.isNotEmpty && since == sequence && session.generation == generation;
    if (encoded.isEmpty) {
      copy = session.frame!.copy();
    }
    try {
      if (encoded.isEmpty) {
        scaled = copy!.scaled(width, height);
        final output = <int>[];
        if (!encoder(scaled, output) || output.isEmpty) {
          return vscreenFailure('FRAME_ENCODE_FAILED', false);
        }
        encoded = base64Encode(output);
      }
      final value = metadata()
        ..put('frameSeq', sequence)
        ..put('frameAgeMs', session.elapsed() - captured);
      if (unchanged) {
        value.put('unchanged', true);
      } else {
        value
          ..put('previewWidth', width)
          ..put('previewHeight', height)
          ..put('previewB64', encoded);
      }
      if (!session.active ||
          session.frame == null ||
          session.sequence != sequence) {
        return vscreenFailure('STALE_FRAME', false);
      }
      if (!value.optBoolean('ok') ||
          !value.optBoolean('active') ||
          value.optInt('displayId', -1) != session.id ||
          session.generation != value.optString('generation')) {
        return vscreenFailure('STALE_GENERATION', false);
      }
      // 只在有效图片回包（或此前已发布的同帧缓存）完整生成后登记观察。
      session.encoded = encoded;
      session.encodedSequence = sequence;
      session.observed = sequence;
      session.observedAt = session.elapsed();
      return value;
    } finally {
      if (scaled != null && scaled != copy) {
        scaled.recycle();
      }
      copy?.recycle();
    }
  }
}
