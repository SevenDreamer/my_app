// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenDisplaySession —— 现代化重构，行为契约不变。
//! 一个显示代次独占显示、图像流和输入；宿主旋转只更换预览订阅。
library;

import 'input_policy.dart';
import 'observed_pixels.dart';
import 'support.dart';
import 'pixels.dart';

/// 帧图像（缝：`android.graphics.Bitmap`）。
abstract class RawFrame {
  int get width;

  int get height;

  int get allocationByteCount;

  bool sameAs(RawFrame other);

  /// 原版 `Bitmap.copy(ARGB_8888, false)`。
  RawFrame? copy();

  /// 原版 `Bitmap.createScaledBitmap`。
  RawFrame scaled(int width, int height);

  /// 原版 `compress(JPEG, quality, out)`；返回编码字节，空=失败。
  List<int> encodeJpeg(int quality);

  /// 原版 `getPixels`：区域 ARGB 行主序像素。
  List<int> regionPixels(VscreenRect region);

  void recycle();
}

/// 图像读取器（缝：`android.media.ImageReader`）。
abstract class FrameReader {
  /// 原版 `acquireLatestImage()` → `RgbaImagePlane.packed` → ARGB 帧。
  RawFrame? acquireLatestFrame(int width, int height);

  void close();
}

/// 显示句柄（缝：`android.hardware.display.VirtualDisplay`）。
abstract class DisplayHandle {
  void release();
}

/// 输入面（原版 `VirtualScreenInput`；D4 轮全量移植）。
abstract class VscreenInputApi {
  bool active();

  void cancel();

  /// 输入后端是否可用（原版 `available()`）。
  bool available();

  /// 后端名（原版 `backend()`：reflection / input-command / unavailable）。
  String backend();

  /// 不可用原因（原版 `unavailableReason()`：缺失成员清单）。
  String unavailableReason();

  /// 触摸（action: 0=down 1=up 2=move 3=cancel）。
  VscreenInputResult touch(String stroke, int action, double x, double y);

  VscreenInputResult key(int code);

  VscreenInputResult text(String value);

  /// 最近一次提交结果（原版 `lastResult()`）。
  VscreenInputResult lastResult();

  /// 看门狗到期清理（原版 `expire()`）。
  void expire();
}

/// 显示会话（原版 `VirtualScreenDisplaySession`）。
class VscreenDisplaySession {
  VscreenDisplaySession({
    required this.width,
    required this.height,
    required this.id,
    required this.input,
    required VscreenClock clock,
    this.display,
    this.reader,
  })  : generation = vscreenUuid(),
        observations = VscreenObservedPixels(clock: clock),
        _clock = clock;

  final DisplayHandle? display;
  final FrameReader? reader;
  final int width, height, id;
  final Object lock = Object();
  final String generation;
  bool active = true;
  int sequence = 0;
  int observed = -1;
  int observedAt = 0;
  int capturedAt = 0;
  int encodedSequence = -1;
  String packageName = '';
  String encoded = '';
  RawFrame? frame;
  final VscreenObservedPixels observations;
  final VscreenInputApi input;
  final VscreenClock _clock;

  int elapsed() => _clock.millis();

  void start() {
    if (reader != null) {
      VscreenPixels.start(this);
    }
  }

  /// 创建失败清理（原版 create 失败段：active=false + frame 回收；不走 input.cancel）。
  void abortCreate() {
    active = false;
    final held = frame;
    frame = null;
    held?.recycle();
  }

  void close() {
    active = false;
    try {
      input.cancel();
    } on Exception {
      // 原版忽略。
    }
    final held = frame;
    frame = null;
    held?.recycle();
    observations.clear();
    try {
      display?.release();
    } finally {
      reader?.close();
    }
  }
}
