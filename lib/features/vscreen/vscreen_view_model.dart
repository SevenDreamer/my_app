//! 虚拟屏 ViewModel：绑 [VscreenManager] 状态机 + [PreviewTransform] 预览矩阵。
//!
//! MVVM：View 只读状态/帧 + 调手势命令。Manager 装配（semantics/launcher/
//! transport 等接缝）随 F2-3/F2-4 落地；未装 Manager 时如实显示未连接。
import 'dart:ui' as ui;

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/foundation.dart';

class VscreenViewModel extends ChangeNotifier {
  /// Manager 装配（semantics/launcher/transport 等接缝）随 F2-3/F2-4 落地；
  /// 本批只交预览几何/输入门骨架，未装 Manager 时如实显示未连接。
  VscreenViewModel({VscreenManager? manager}) : _manager = manager {
    _transform.resetForSize(0, 0);
  }

  final VscreenManager? _manager;
  final PreviewTransform _transform = PreviewTransform();
  ui.Image? _frame;
  final String _status = '未连接虚拟屏服务（Manager 装配随 F2-3/F2-4 落地）';
  int _downAt = 0;
  List<double>? _touchStart;

  /// Manager（测试/上层透传用；未装配为 null）。
  VscreenManager? get manager => _manager;

  /// 预览矩阵（View 绘制/逆映射直接读）。
  PreviewTransform get transform => _transform;

  /// 当前帧（无帧为 null）。
  ui.Image? get frame => _frame;

  /// 状态文案（诚实显示连接态）。
  String get status => _status;

  /// 尺寸变化/换帧复位（原版 frame() 首段语义）。
  void onViewport(int width, int height) {
    _transform.resetForSize(width, height);
    notifyListeners();
  }

  /// 双指缩放（原版 onScale：clamp [1,4]）。
  void onScale(double factor) {
    _transform.scale(factor);
    notifyListeners();
  }

  /// 平移（偏移夹紧在 fit() 内生效）。
  void onPan(double dx, double dy) {
    _transform.offsetX += dx;
    _transform.offsetY += dy;
    notifyListeners();
  }

  /// 触摸按下（原版 ACTION_DOWN 语义：准入判定 + 逆映射拒黑边）。
  /// 返回虚拟屏坐标；null = 黑边/界外/未准入。
  List<double>? onTouchDown(double x, double y, int viewW, int viewH) {
    final bitmap = _frame;
    final start = bitmap == null
        ? null
        : _transform.point(x, y, viewW, viewH, bitmap.width, bitmap.height);
    final admitted = previewTouchEnabled(
      hasListener: true,
      pan: false,
      seq: _manager?.frameSequence ?? (_frame == null ? -1 : 1),
      start: start,
    );
    if (!admitted || start == null) return null;
    _downAt = DateTime.now().millisecondsSinceEpoch;
    _touchStart = start;
    return start;
  }

  /// 触摸抬起：UP 时长上限 3000ms（原版 min 语义）。
  int? onTouchUp() {
    final start = _touchStart;
    if (start == null) return null;
    _touchStart = null;
    return previewUpDuration(DateTime.now().millisecondsSinceEpoch - _downAt);
  }

  /// 帧供给（F2-4 Transport 落地后由帧流调用；缺口保帧语义在调用方判断）。
  void offerFrame(ui.Image image, String generation) {
    _frame?.dispose();
    _frame = image;
    notifyListeners();
  }

  @override
  void dispose() {
    _frame?.dispose();
    super.dispose();
  }
}
