// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenPreviewView —— 现代化重构，行为契约不变。
//! 预览矩阵同时用于显示和逆向映射，黑边不能变成虚拟屏坐标。
//! 「A capture gap invalidates input immediately without flashing a live display black.」
library;

/// 预览矩阵（原版 `fit()/point()` 纯几何）：zoom ∈ [1,4]，偏移夹紧，逆映射拒黑边。
class PreviewTransform {
  double zoom = 1;
  double offsetX = 0, offsetY = 0;
  int screenW = 0, screenH = 0;

  /// 尺寸变化/换帧时的复位（原版 `frame()` 首段）。
  void resetForSize(int width, int height) {
    if (screenW != width || screenH != height) {
      zoom = 1;
      offsetX = 0;
      offsetY = 0;
    }
    screenW = width;
    screenH = height;
  }

  /// 缩放（原版 onScale）：clamp [1,4]。
  void scale(double factor) {
    final next = zoom * factor;
    zoom = next < 1 ? 1 : (next > 4 ? 4 : next);
  }

  /// 适配矩阵（原版 `fit()` 的数值部分）：返回 [factor, translateX, translateY]。
  List<double> fit(int viewW, int viewH, int bitmapW, int bitmapH) {
    if (bitmapW <= 0 || bitmapH <= 0) return const [1, 0, 0];
    final factor = (viewW / bitmapW < viewH / bitmapH ? viewW / bitmapW : viewH / bitmapH) * zoom;
    final maxX = _max(0, (bitmapW * factor - viewW) / 2);
    final maxY = _max(0, (bitmapH * factor - viewH) / 2);
    offsetX = offsetX < -maxX ? -maxX : (offsetX > maxX ? maxX : offsetX);
    offsetY = offsetY < -maxY ? -maxY : (offsetY > maxY ? maxY : offsetY);
    return [
      factor,
      (viewW - bitmapW * factor) / 2 + offsetX,
      (viewH - bitmapH * factor) / 2 + offsetY,
    ];
  }

  /// 逆映射到虚拟屏坐标（原版 `point()`）：黑边/界外返回 null——黑边不能变成虚拟屏坐标。
  List<double>? point(double x, double y, int viewW, int viewH, int bitmapW, int bitmapH) {
    if (bitmapW <= 0 || bitmapH <= 0) return null;
    final f = fit(viewW, viewH, bitmapW, bitmapH);
    final factor = f[0], tx = f[1], ty = f[2];
    if (factor == 0) return null;
    final bx = (x - tx) / factor;
    final by = (y - ty) / factor;
    if (bx < 0 || by < 0 || bx >= bitmapW || by >= bitmapH) return null;
    return [bx * screenW / bitmapW, by * screenH / bitmapH];
  }

  static double _max(double a, double b) => a > b ? a : b;
}

/// 采集缺口判定（原版 `unavailable()`）：缺口立即失效输入，但不把活画面闪黑。
/// 返回 true = 保留旧帧（frameGap 且同代次）。
bool previewUnavailableRetain(String code, String shownGeneration, String? activeGeneration,
    {required bool hasBitmap}) {
  final frameGap = code == 'STALE_FRAME' ||
      code == 'FRAME_NOT_READY' ||
      code == 'FRAME_ENCODE_FAILED';
  return frameGap &&
      hasBitmap &&
      activeGeneration != null &&
      activeGeneration.isNotEmpty &&
      activeGeneration == shownGeneration;
}

/// 触摸准入判定（原版 `onTouchEvent` ACTION_DOWN 语义）。
/// 返回 true = 交给 [admit] 门；false = 直接 cancelStream。
bool previewTouchEnabled({
  required bool hasListener,
  required bool pan,
  required int seq,
  required List<double>? start,
}) =>
    hasListener && !pan && seq > 0 && start != null;

/// 流节拍（原版 `lastStream > 24`）：24ms 最小流间隔。
const int previewStreamIntervalMs = 24;

/// UP 时长上限（原版 `Math.min(3000, elapsed - downAt)`）。
int previewUpDuration(int heldMs) => heldMs < 3000 ? heldMs : 3000;
