// 版权来源：DSHA（MIT）vscreen 域支撑面（VirtualScreenTransport.failure / Rect / UUID / JSON 读取）—— 现代化重构，行为契约不变。
//! vscreen 域支撑面：时钟、矩形、失败结果包、JSON 兼容层与接线缝接口。
//! `vscreenFailure` 契约（原版 `VirtualScreenTransport.failure(code, unknown)`）：
//! `{ok:false, error:<code>}`，unknown 时加 `executionUnknown:true`。
library;

import 'dart:math';

import 'target_evidence.dart' show VscreenTargetEvidence;

/// 单调时钟（原版 `SystemClock.elapsedRealtime` / `VirtualScreenCore.elapsed`）。
abstract class VscreenClock {
  int millis();
}

/// 屏幕矩形（原版 `android.graphics.Rect` 判定语义）。
class VscreenRect {
  const VscreenRect(this.left, this.top, this.right, this.bottom);

  final int left, top, right, bottom;

  int get width => right - left;

  int get height => bottom - top;

  bool isEmpty() => left >= right || top >= bottom;

  /// Java `Rect.contains(x, y)`：left ≤ x < right 且 top ≤ y < bottom。
  bool contains(int x, int y) =>
      x >= left && x < right && y >= top && y < bottom;

  /// Java `Rect.intersects`（严格不等）。
  bool intersects(VscreenRect other) =>
      left < other.right &&
      other.left < right &&
      top < other.bottom &&
      other.top < bottom;

  /// 余量 ±8 并夹到视口（原版 `VirtualScreenAnchorProof.region`）。
  VscreenRect regionClamped(int width, int height) => VscreenRect(
        max(0, left - 8),
        max(0, top - 8),
        min(width, right + 8),
        min(height, bottom + 8),
      );
}

/// 失败结果包（原版 `VirtualScreenTransport.failure`；完整 HTTP transport 于 D5 轮移植）。
Map<String, Object?> vscreenFailure(String code, bool unknown) {
  final value = <String, Object?>{'ok': false, 'error': code};
  if (unknown) {
    value['executionUnknown'] = true;
  }
  return value;
}

/// 区域几何（原版 `VirtualScreenAnchorProof.region` 静态面）。
VscreenRect vscreenRegion(VscreenRect node, int width, int height) =>
    node.regionClamped(width, height);

final Random _random = Random.secure();

/// UUID v4 小写 8-4-4-4-12（原版 `UUID.randomUUID().toString()`）。
String vscreenUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// org.json 读取语义兼容层（opt 缺省值/put 链与 `JSONObject` 对齐）。
extension JsonX on Map<String, Object?> {
  bool has(String key) => containsKey(key);

  String optString(String key, [String fallback = '']) {
    final value = this[key];
    return value == null ? fallback : value.toString();
  }

  int optInt(String key, [int fallback = -1]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  int optLong(String key, [int fallback = -1]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  bool optBoolean(String key, [bool fallback = false]) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  int getInt(String key) {
    final value = this[key];
    if (value is! int) throw ArgumentError('JSON_INT_MISSING:$key');
    return value;
  }

  int getLong(String key) {
    final value = this[key];
    if (value is! int) throw ArgumentError('JSON_LONG_MISSING:$key');
    return value;
  }

  String getString(String key) {
    final value = this[key];
    if (value == null) throw ArgumentError('JSON_STRING_MISSING:$key');
    return value.toString();
  }

  Map<String, Object?> put(String key, Object? value) {
    this[key] = value;
    return this;
  }
}

/// 无障碍节点句柄（缝：`AccessibilityNodeInfo`）。
abstract class A11yNodeHandle {
  /// 原版 `node.refresh()`：句柄仍指向活节点。
  bool refresh();
}

/// 锚点候选（原版 `VirtualScreenAnchorProof.Candidate` 句柄面）。
abstract class AnchorCandidateApi {
  VscreenRect get bounds;

  A11yNodeHandle get node;
}

/// 语义树证明句柄（缝：Rust `vscreen_anchor_proof::AnchorProof` 接线 FFI 化）。
abstract class AnchorProofApi {
  int get connectionEpoch;

  int get bytes;

  List<AnchorCandidateApi> get candidates;

  /// 原版 `proof.root`（`Click.perform` 的 root 参数；缝侧具体型）。
  Object? get root;

  bool sameAs(AnchorProofApi other);

  AnchorCandidateApi selectAnchor(int x, int y, int width, int height);

  AnchorCandidateApi? same(AnchorCandidateApi original);

  bool unobscured(VscreenRect region);

  void close();
}

/// 证明摘取失败（原版 `VirtualScreenAnchorProof.Unavailable`；`reason` 即错误代号）。
class AnchorUnavailable implements Exception {
  AnchorUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'AnchorUnavailable: $reason';
}

/// 到期句柄（原版 `ScheduledFuture.cancel(false)`）。
abstract class ExpiryHandle {
  void cancel();
}

/// 观察像素面（原版 `VirtualScreenAccessibility.ObservedPixels` 接口）。
abstract class ObservedPixelsApi {
  Map<String, Object?> capture(bool proofAvailable);

  void release(String id);

  Map<String, Object?> region(String id, VscreenRect bounds);

  ExpiryHandle expireAfter(void Function() callback, int delayMs);
}

/// 能力请求面（原版 `CapabilityRequest` 字段；D3 轮全量移植）。
abstract class CapabilityRequestApi {
  /// 实为 [VscreenTargetEvidence]（构造/匹配期断言）。
  Object? get target;

  /// 原版 `request.capability`（screen 能力门）。
  String get capability;

  String get runtime;

  String get installInstanceId;

  String get bridgeRunId;

  int get policyRevision;

  int get authorityEpoch;
}

/// 屏幕请求上下文面（原版 `ScreenRequestContext`；缝侧实现）。
abstract class VscreenContext {
  CapabilityRequestApi request();

  VscreenTargetEvidence get target;

  int serviceEpoch();

  bool current();

  bool claimDispatch();

  /// 原版 `validateRoot(displayId, root)`（root 为 `A11yNode` 句柄）。
  void validateRoot(int displayId, Object root);
}

/// 受管点击（原版 `VirtualScreenObservedControl.Click`）。
typedef VscreenClick = bool Function(
  A11yNodeHandle node,
  Object? root,
  VscreenContext context,
  List<bool> submitted,
  bool Function() leaseCurrent,
);
