//! 虚拟屏预览页（原版 WebPreviewActivity 的 Flutter 重写）。
//!
//! MVVM：ListenableBuilder 读 [VscreenViewModel] 快照 + 调手势命令；
//! 预览矩阵（fit/逆映射）与触摸准入走 dsha_core 逻辑层（行为契约逐字）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_scaffold.dart';
import 'vscreen_view_model.dart';

class VscreenPage extends StatefulWidget {
  const VscreenPage({super.key, this.viewModel});

  final VscreenViewModel? viewModel;

  @override
  State<VscreenPage> createState() => _VscreenPageState();
}

class _VscreenPageState extends State<VscreenPage> {
  late final VscreenViewModel _viewModel =
      widget.viewModel ?? VscreenViewModel();

  @override
  void dispose() {
    if (widget.viewModel == null) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_viewModel.status,
                    style: AppTypography.bodyMd.copyWith(
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                    )),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final viewW = constraints.maxWidth.toInt();
                  final viewH = constraints.maxHeight.toInt();
                  return GestureDetector(
                    onScaleStart: (_) {},
                    onScaleUpdate: (details) {
                      if (details.scale != 1.0) {
                        _viewModel.onScale(details.scale);
                      } else {
                        _viewModel.onPan(details.focalPointDelta.dx,
                            details.focalPointDelta.dy);
                      }
                    },
                    onTapDown: (details) => _viewModel.onTouchDown(
                        details.localPosition.dx,
                        details.localPosition.dy,
                        viewW,
                        viewH),
                    onTapUp: (_) => _viewModel.onTouchUp(),
                    child: CustomPaint(
                      painter: _FramePainter(
                        image: _viewModel.frame,
                        transform: _viewModel.transform,
                        viewW: viewW,
                        viewH: viewH,
                      ),
                      size: Size.infinite,
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 帧绘制（fit 矩阵 → 平移缩放；无帧画占位灰底，不闪黑——保帧语义）。
class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.image,
    required this.transform,
    required this.viewW,
    required this.viewH,
  });

  final dynamic image; // ui.Image?（避免此层依赖 dart:ui 具名导入差异）
  final dynamic transform; // PreviewTransform
  final int viewW;
  final int viewH;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final f = transform.fit(viewW, viewH, img.width, img.height) as List<double>;
    final matrix = Matrix4.identity()
      ..translateByDouble(f[1], f[2], 0, 1)
      ..scaleByDouble(f[0], f[0], f[0], 1);
    canvas.transform(matrix.storage);
    canvas.drawImage(img, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.image != image ||
      old.viewW != viewW ||
      old.viewH != viewH ||
      !listEquals(_sig(transform), _sig(old.transform));

  static List<double> _sig(dynamic t) =>
      <double>[t.zoom, t.offsetX, t.offsetY];

  static bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-9) return false;
    }
    return true;
  }
}
