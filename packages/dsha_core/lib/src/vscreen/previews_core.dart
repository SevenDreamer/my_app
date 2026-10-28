// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenPreviews —— 现代化重构，行为契约不变。
//! 三个 UI 属主共享一份预览请求；每个属主拥有自己的解码位图与一次主线程回调。
//! 「A consumer revokes its input identity on a frame gap. Even the same successful sequence
//!  must be delivered again before that identity can become usable.」
//! 错误契约（逐字）：`VSCREEN_UI_MAIN_REQUIRED`。
library;

import 'coalescing_poller.dart';
import 'preview_input_gate.dart';
import 'support.dart';

/// 帧图像面（缝：`Bitmap`）。
abstract class PreviewImage {
  void recycle();
}

/// 预览宿主面（缝：`VirtualScreenManager` 的 epoch/preview/frameCurrent）。
abstract class PreviewHost {
  int epoch();

  Map<String, Object?> preview();

  bool frameCurrent(Map<String, Object?> value);

  /// 解码（原版 `previewBitmap`）；失败返回 null。
  PreviewImage? decode(Map<String, Object?> value);
}

/// 主线程贴送面（缝：`Handler.post/removeCallbacks`）。
abstract class MainPoster {
  /// 返回 false = 贴送失败（原版 `posted == false` 分支）。
  bool post(void Function() action);

  void removeCallbacks(void Function() action);

  void assertMain();
}

class _Sample {
  _Sample(this.value, this.epoch, this.fetch);

  final Map<String, Object?> value;
  final int epoch;
  final FetchHold fetch;
}

/// 预览帧（原版 `Frame`）。
class PreviewFrame {
  PreviewFrame(this.value, this.image, this.epoch, this._hold);

  final Map<String, Object?> value;
  final PreviewImage? image;
  final int epoch;
  final AutoCloseHold? _hold;
  bool adopted = false;

  void adopt() {
    adopted = image != null;
  }

  void finished() {
    _hold?.close();
  }

  void release() {
    image?.recycle();
    finished();
  }
}

/// 预览租约（原版 `Lease`）。
class PreviewLease {
  PreviewLease._(this._host, this._main, this._listener);

  final PreviewHost _host;
  final MainPoster _main;
  final void Function(PreviewFrame frame) _listener;
  PollSubscription<_Sample>? subscription;
  PreviewFrame? _pending;
  bool _queued = false, _closed = false;
  int _drawnEpoch = -1, _drawnSequence = -1;
  String _drawnGeneration = '';

  late final void Function(_Sample sample) _offer = offer;

  void offer(_Sample? sample) {
    if (sample == null || sample.epoch != _host.epoch()) return;
    if (_closed) return;
    if (!sample.value.optBoolean('ok')) {
      // 帧缺口即撤回消费方的输入身份：同一成功帧号也必须重新送达才再可用。
      _drawnEpoch = _drawnSequence = -1;
      _drawnGeneration = '';
    } else if (_drawnEpoch == sample.epoch &&
        _drawnGeneration == sample.value.optString('generation') &&
        _drawnSequence == sample.value.optLong('frameSeq', -1)) {
      return;
    }
    final hold = sample.fetch.retain();
    if (hold == null) return;
    PreviewFrame next;
    try {
      next = PreviewFrame(sample.value, _host.decode(sample.value), sample.epoch, hold);
    } catch (failure) {
      hold.close();
      rethrow;
    }
    PreviewFrame? replaced;
    if (_closed) {
      replaced = next;
    } else {
      replaced = _pending;
      _pending = next;
      if (!_queued) {
        _queued = true;
        bool posted;
        try {
          posted = _main.post(deliver);
        } catch (unavailable) {
          _queued = false;
          _pending = null;
          next.release();
          replaced?.release();
          rethrow;
        }
        if (!posted) {
          _queued = false;
          _pending = null;
          next.release();
        }
      }
    }
    replaced?.release();
  }

  void deliver() {
    _main.assertMain();
    _queued = false;
    final frame = _pending;
    _pending = null;
    if (frame == null) return;
    if (_closed ||
        frame.epoch != _host.epoch() ||
        (frame.value.optBoolean('ok') && !_host.frameCurrent(frame.value))) {
      frame.release();
      return;
    }
    try {
      _listener(frame);
      if (frame.adopted &&
          !_closed &&
          frame.epoch == _host.epoch() &&
          _host.frameCurrent(frame.value)) {
        _drawnEpoch = frame.epoch;
        _drawnGeneration = frame.value.optString('generation');
        _drawnSequence = frame.value.optLong('frameSeq', -1);
      }
    } catch (failedConsumer) {
      frame.release();
    } finally {
      frame.finished();
    }
  }

  void close() {
    _main.assertMain();
    if (_closed) return;
    _closed = true;
    final old = _pending;
    _pending = null;
    _main.removeCallbacks(deliver);
    subscription?.close();
    old?.release();
  }
}

/// 预览订阅属主（原版 `VirtualScreenPreviews`）。
class VscreenPreviews {
  VscreenPreviews({
    required this.host,
    required this.main,
    required this.schedule,
  });

  final PreviewHost host;
  final MainPoster main;
  final Object Function(void Function() poll, int delayMs) schedule;

  CoalescingPoller<_Sample>? _poller;
  final PreviewInputGate inputGate = PreviewInputGate();

  /// 订阅（原版 `subscribe`）：CoalescingPoller(属主≤3, 250ms)。
  PreviewLease subscribe(Object owner, void Function(PreviewFrame frame) listener) {
    main.assertMain();
    _poller ??= CoalescingPoller<_Sample>(
      producer: _produce,
      maximumOwners: 3,
      delayMs: 250,
      schedule: schedule,
    );
    final lease = PreviewLease._(host, main, listener);
    lease.subscription = _poller!.subscribe(owner, lease._offer);
    return lease;
  }

  _Sample? _produce() {
    final fetch = inputGate.beginPreview();
    if (fetch == null) return null;
    try {
      final epoch = host.epoch();
      final value = host.preview();
      return epoch == host.epoch() ? _Sample(value, epoch, fetch) : null;
    } finally {
      // 生产者任务在 CoalescingPoller 完成全部 offer 后才释放；解码/待发帧各自持份到采纳或释放。
      fetch.offered();
    }
  }

  /// 手势准入（原版 `beginGesture`）：所见帧必须仍是当前帧。
  GestureHold? beginGesture(Map<String, Object?>? displayed) {
    main.assertMain();
    final gesture = inputGate.beginGesture();
    if (gesture == null) return null;
    if (displayed != null && host.frameCurrent(displayed)) return gesture;
    gesture.close();
    return null;
  }
}
