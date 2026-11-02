//! 虚拟屏 ViewModel：绑 [VscreenManager] 状态机 + [PreviewTransform] 预览矩阵。
//!
//! MVVM：View 只读状态/帧 + 调手势命令。Manager 装配（semantics/launcher/
//! transport 等接缝）随 F2-3/F2-4 落地；未装 Manager 时如实显示未连接。
import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;

import '../../core/logging/sentry_bridge.dart';

import 'shizuku_channel.dart';
import 'vscreen_assembly.dart';

class VscreenViewModel extends ChangeNotifier {
  /// Manager 装配（semantics/launcher/transport 等接缝）随 F2-3/F2-4 落地；
  /// 本批只交预览几何/输入门骨架，未装 Manager 时如实显示未连接。
  VscreenViewModel({VscreenManager? manager}) : _manager = manager {
    _transform.resetForSize(0, 0);
  }

  VscreenManager? _manager;
  final PreviewTransform _transform = PreviewTransform();
  ui.Image? _frame;
  String _status = '未连接虚拟屏服务';
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

  Timer? _poll;

  /// 启动虚拟屏（原版流程：start core → 帧轮询预览）。
  ///
  /// Manager 未注入时按 [buildVscreenManager] 默认装配（HttpTransport +
  /// applicationId 包名）自建。失败如实进 status（安全消息码进文案）。
  Future<void> boot({
    required String sourceDir,
    required String packageName,
    required io.Directory root,
    required String installation,
  }) async {
    _manager ??= buildVscreenManager(
      sourceDir: sourceDir,
      packageName: packageName,
      root: root,
      installation: installation,
      applicationId: packageName,
      transport: HttpTransport(applicationId: packageName),
    );
    _status = '检查 Shizuku 通道…';
    notifyListeners();
    final ready = await ShizukuChannel.refreshReady();
    if (!ready) {
      _status = 'Shizuku 请求授权…';
      notifyListeners();
      final granted = await ShizukuChannel.requestPermission();
      final nowReady =
          granted ? await ShizukuChannel.refreshReady() : false;
      if (!nowReady) {
        final detail = await ShizukuChannel.status();
        // 文案契约（原版 userStatus）：授权态与连接态分开，不许把「没绑上」
        // 说成「未授权」（误导排障）。
        final permissionOk = detail.contains('permission=true');
        _status = permissionOk
            ? 'Shizuku 已授权，设备 Shell 连接未完成（$detail）'
            : 'Shizuku 未授权（$detail）';
        notifyListeners();
        await reportDiagnostics();
        return;
      }
    }
    _status = '启动虚拟屏…';
    notifyListeners();
    final outcome = await _manager!.start('portrait');
    final ok = outcome['ok'] == true;
    _status = ok ? '虚拟屏运行中' : '启动失败：${outcome['error'] ?? '未知'}';
    notifyListeners();
    if (!ok) {
      await reportDiagnostics(); // 失败自动上报（排障闭环）
      return;
    }
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _pullFrame());
    await _pullFrame();
  }

  /// 诊断上报（自动=boot 失败；手动=页面「上报诊断」按钮）。
  Future<bool> reportDiagnostics() {
    return SentryBridge.captureDiagnostics({
      'phase': 'vscreen-boot',
      'status': _status,
      'manager': _manager == null ? 'unassembled' : 'assembled',
    }, kind: 'vscreen-diagnostics');
  }

  Future<void> _pullFrame() async {
    final manager = _manager;
    if (manager == null) return;
    try {
      final value = await manager.preview();
      final bytes = VscreenManager.previewBytes(value);
      if (bytes == null || bytes.isEmpty) return;
      final image = await decodeImageFromList(Uint8List.fromList(bytes));
      offerFrame(image, '${value['generation'] ?? ''}');
    } catch (_) {
      // 轮询不停（缺帧保帧）；错误进 status 由 status() 语义面覆盖。
    }
  }

  /// 帧供给（帧流调用；缺口保帧语义在调用方判断）。
  void offerFrame(ui.Image image, String generation) {
    _frame?.dispose();
    _frame = image;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _frame?.dispose();
    super.dispose();
  }
}
