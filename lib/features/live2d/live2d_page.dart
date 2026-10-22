//! Live2D 看板娘页（WebView + WebGL 方案：live2d 包 = PixiJS + pixi-live2d-display）
//!
//! 三模型切换、透明背景（看板娘浮在 UI 上）、内置触摸跟踪（眼/头跟手指）。
//! JS 引擎默认走 CDN（可经 Live2DViewer 的 cubismCoreJsUrl 等参数换本地资产）。
//! 模型资产经包内置的本地 HttpServer 喂给 WebView，Flutter assets 直接可用。
import 'package:flutter/material.dart';
import '../../design/widgets/app_spinner.dart';
import 'live2d_settings_page.dart';
import 'live2d_stage.dart';
import 'package:shadcn_ui/shadcn_ui.dart'; // LucideIcons 由它 re-export

import '../../core/logging/app_logger.dart';
import '../../data/live2d_models.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';

class Live2dPage extends StatefulWidget {
  const Live2dPage({super.key});

  @override
  State<Live2dPage> createState() => _Live2dPageState();
}



class _Live2dPageState extends State<Live2dPage> {
  final _ctrl = createLive2dController();
  int _idx = 0;
  String? _lastError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl.onModelLoaded = (info) {
      if (mounted) {
        setState(() => _loading = false);
      }
      AppLogger.instance.log('live2d',
          '模型加载完成：${info.modelUrl}（画布 ${info.width.toInt()}x${info.height.toInt()}，动作组 ${info.motionGroups.length} 个）');
    };
    _ctrl.onError = (error) {
      AppLogger.instance.log('live2d', '错误：$error');
      if (mounted) {
        setState(() {
          _lastError = error;
          _loading = false;
        });
      }
    };
    _load(_idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load(int idx) async {
    setState(() => _idx = idx);
    AppLogger.instance
        .log('live2d', '开始加载 ${live2dModels[idx].label}（${live2dModels[idx].assetPath}）');
    try {
      await _ctrl.loadModel(live2dModels[idx].assetPath);
      AppLogger.instance.log('live2d', 'loadModel 调用完成');
    } catch (e) {
      AppLogger.instance.log('live2d', '异常：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Live2D 看板娘',
        actions: [
          // 方案 B：汉堡按钮直达 Live2D 设置页（模型选择/导入管理）
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              icon: const Icon(LucideIcons.menu, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Live2dSettingsPage(
                      currentIndex: _idx,
                      onSelect: (i) => _load(i),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 模型舞台（透明背景——看板娘可浮在任意 UI 上；切换在右上角汉堡菜单）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Live2dStage(
                  controller: _ctrl,
                  // 本地 Core 运行时（assets/live2d/），已打 Cubism Core 6 兼容补丁。
                  //
                  // 为什么不用官方 CDN：Ren 的 .moc3 是 moc3 v6 格式，只有 Core 6.x 能
                  // 加载；但 Core 6.0.1 移除了 drawables.renderOrders（挪到 Model 上），
                  // 渲染库 pixi-live2d-display@0.4.0 仍读旧字段 → 取到 undefined 再 [0]
                  // → 每帧抛 "Cannot read properties of undefined (reading '0')" → 全员
                  // 空白。本地这份在 Core 定义后包了 Model.fromMoc，把该字段补回去。
                  // 详见 docs/PITFALLS.md #26 / #27。
                  //
                  // 相对路径：player 页由包内 HttpServer 提供，其 /assets/* 路由会剥掉
                  // 一层前缀后用 rootBundle 加载，而 Flutter 资产 key 本身要带 "assets/"，
                  // 因此这里是**双层** assets/（与模型 URL 同构：/assets/assets/models/…）。
                  cubismCoreJsUrl:
                      'assets/assets/live2d/live2dcubismcore.min.js',
                ),
                // 加载态转圈（首开 WebGL 冷启动可见的等待）
                if (_loading)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppSpinner(size: 24),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _idx == 0 ? '首次加载较慢（贴图解码中）…' : '加载中…',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                // 渲染状态调试条（controller 状态，排查空白用）
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Text(
                    _lastError != null ? '加载失败：$_lastError' : '舞台运行中（${live2dModels[_idx].label}）',
                    style: const TextStyle(fontSize: 10),
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
