//! Live2D 看板娘演示页（flutter_live2d：Cubism Native SDK + GLES2）
//!
//! 三模型切换、透明背景（看板娘浮在 UI 上）、内置触摸跟踪（眼/头跟手指）。
//! 仅 Android/iOS（包的平台限制）——桌面端不可用，注册表已声明。
import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_app_bar.dart';

class Live2dPage extends StatefulWidget {
  const Live2dPage({super.key});

  @override
  State<Live2dPage> createState() => _Live2dPageState();
}

class _ModelDef {
  const _ModelDef(this.label, this.dir, this.file);
  final String label;
  final String dir;
  final String file;
}

const _models = <_ModelDef>[
  // Mao/Ren 打头：贴图 4096，兼容所有设备；IceGirl 是 8192 贴图，
  // 部分设备 GL_MAX_TEXTURE_SIZE=4096 会渲染空白
  _ModelDef('Mao', 'assets/models/mao/', 'mao_pro.model3.json'),
  _ModelDef('Ren', 'assets/models/ren/', 'ren.model3.json'),
  _ModelDef('IceGirl', 'assets/models/icegirl/', 'IceGirl.model3.json'),
];

class _Live2dPageState extends State<Live2dPage> {
  final _ctrl = Live2DViewController();
  int _idx = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(_idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load(int idx) async {
    setState(() {
      _idx = idx;
      _error = null;
    });
    try {
      await _ctrl.whenAttached;
      await _ctrl.loadModel(
        modelDir: _models[idx].dir,
        modelFileName: _models[idx].file,
      );
    } on Live2DException catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Live2D 看板娘'),
      body: Column(
        children: [
          // 模型切换
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _models.length; i++)
                  ButtonSegment(value: i, label: Text(_models[i].label)),
              ],
              selected: {_idx},
              onSelectionChanged: (s) => _load(s.first),
            ),
          ),
          // 模型舞台（透明背景——看板娘可浮在任意 UI 上）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Live2DView(controller: _ctrl),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('加载失败：$_error', textAlign: TextAlign.center),
                    ),
                  ),
                // 触摸跟踪提示（包内置：眼/头跟手指）
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.lg,
                  child: Text(
                    '用手指在画面上移动——她的眼睛和头会跟着你 👀',
                    textAlign: TextAlign.center,
                  ),
                ),
                // 渲染状态调试条（controller 状态，排查空白用）
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: ValueListenableBuilder<Live2DViewState>(
                    valueListenable: _ctrl,
                    builder: (_, st, __) => Text(
                      '$st',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
