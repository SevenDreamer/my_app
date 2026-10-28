// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenPolicy —— 现代化重构，行为契约不变。
//! 虚拟屏的纯尺寸、坐标和过期帧规则；不依赖 Android。
library;

/// 纯策略面（原版 `VirtualScreenPolicy`）。
abstract final class VscreenPolicy {
  static const int minApi = 30;

  /// 观察窗口：超过它就必须重新 see，避免用很久以前的画面决策。
  static const int observationWindowMs = 30 * 1000;

  static const String frameNotObserved = 'FRAME_NOT_OBSERVED';
  static const String frameExpired = 'FRAME_EXPIRED';
  static const String observationTimeout = 'OBSERVATION_TIMEOUT';

  static bool supported(int api) => api >= minApi;

  static List<int> phoneSize(int requestedWidth, int requestedHeight) {
    final landscape = requestedWidth > requestedHeight;
    final source = _min(_max(requestedWidth, 1), _max(requestedHeight, 1));
    final edge = _max(144, _min(1440, (source / 144).round() * 144));
    final longEdge = edge * 16 ~/ 9;
    return landscape ? [longEdge, edge] : [edge, longEdge];
  }

  static List<double> map(double x, double y, int viewWidth, int viewHeight,
      int screenWidth, int screenHeight) {
    if (viewWidth <= 0 || viewHeight <= 0 || screenWidth <= 0 || screenHeight <= 0) {
      return [0, 0];
    }
    return [
      _maxDouble(0, _minDouble(screenWidth.toDouble(), x * screenWidth / viewWidth)),
      _maxDouble(
          0, _minDouble(screenHeight.toDouble(), y * screenHeight / viewHeight)),
    ];
  }

  static bool fresh(int observed, int current) =>
      observed > 0 && observed == current;

  /// 帧号是否仍是最新帧；返回 null 表示放行，否则返回稳定的拒绝码。
  static String? frameRejection(int requested, int current) {
    if (requested <= 0) return frameNotObserved;
    return fresh(requested, current) ? null : frameExpired;
  }

  /// 坐标与文本输入还要求调用方确实看过这一帧（观察由 see/preview 写入，输入后复位）。
  static String? observationRejection(int requested, int observed, int ageMs) {
    if (requested <= 0 || observed != requested) return frameNotObserved;
    return ageMs > observationWindowMs ? observationTimeout : null;
  }

  /// 一次响应携带的帧号比已知状态更旧。只有查询类响应（status / preview）才据此拒绝 ——
  /// 输入可能已经真的执行过，它的结果必须保留，绝不能因为随后到来的旧预览被丢掉。
  static bool frameRegressed(int previous, int returned, bool queryRoute) =>
      queryRoute && returned >= 0 && returned < previous;

  /// 帧号只前进：不因为一次旧响应把观察元数据退回去。
  static int advanceFrameSequence(int previous, int returned) =>
      returned >= 0 ? _max(previous, returned) : previous;

  /// 输入帧门的完整判定：先问"这一帧是不是你刚看过的那一帧"，再问"它还是不是最新帧"。
  static String? inputRejection(
      int requested, int current, int observed, int ageMs) {
    final rejected = observationRejection(requested, observed, ageMs);
    return rejected ?? frameRejection(requested, current);
  }

  /// 权限探测结果；`UNKNOWN` 表示查不出来，一律按"不持有"处理。
  ///
  /// 该 flag 在 API 31+ 需要签名级 `ADD_TRUSTED_DISPLAY`，不持有却请求会被
  /// DisplayManagerService 直接抛 SecurityException（issue #123）。探测不出来时
  /// 宁可不要 TRUSTED：不请求它的创建仍然可以成功。
  static bool requestTrustedDisplay(int uid, TrustedDisplayPermission permission) =>
      uid == 0 || permission == TrustedDisplayPermission.held;

  static int _min(int a, int b) => a < b ? a : b;

  static int _max(int a, int b) => a > b ? a : b;

  static double _minDouble(double a, double b) => a < b ? a : b;

  static double _maxDouble(double a, double b) => a > b ? a : b;
}

/// 受信任显示权限探测（原版 `TrustedDisplayPermission`）。
enum TrustedDisplayPermission { held, notHeld, unknown }
