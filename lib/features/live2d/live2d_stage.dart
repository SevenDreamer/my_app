//! Live2D 跨平台舞台（容器抽象层）
//!
//! 同一套资产（Cubism Core JS + 模型）+ 同一套 player 页（live2d 包内
//! HttpServer 提供）+ 同一套 JS 协议（window.live2d.*）：
//! - Android/iOS：live2d 包的 Live2DViewer（webview_flutter 容器）
//! - Windows：webview_windows（WebView2 容器）——桌面宠物可直接 Live2D 化
//!
//! 差异只有"谁来执行 JS"：mobile 走包的 Live2DController，桌面用
//! WebviewController.executeScript 直调同款命令。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/logging/app_logger.dart';
import 'package:live2d/live2d.dart';

import 'player/live2d_player_server.dart';
import 'package:webview_windows/webview_windows.dart';

/// 创建平台对应的控制器（页面入口）
Live2dStageController createLive2dController() =>
    Platform.isWindows ? DesktopStageController() : MobileStageController();

/// 模型加载完成信息（mobile 全量；desktop 为可用子集）
class Live2dModelInfo {
  const Live2dModelInfo({
    required this.modelUrl,
    this.width = 0,
    this.height = 0,
    this.motionGroups = const [],
  });
  final String modelUrl;
  final double width;
  final double height;
  final List<String> motionGroups;
}

/// 平台无关的控制器接口（页面只依赖它）
abstract class Live2dStageController {
  /// 加载模型（[assetPath] 形如 assets/models/mao/mao_pro.model3.json）
  Future<void> loadModel(String assetPath, {bool autoInteract = true});
  Future<void> setExpression(String name);
  Future<void> startMotion(String group, int index);
  void dispose();

  /// 回调（mobile 全保真；desktop 为可用子集）
  void Function(Live2dModelInfo info)? get onModelLoaded;
  set onModelLoaded(void Function(Live2dModelInfo info)? f);
  void Function(String error)? get onError;
  set onError(void Function(String error)? f);
}

/// mobile 端：直接包装 live2d 包的控制器（行为与之前完全一致）
class MobileStageController implements Live2dStageController {
  MobileStageController() {
    inner.onModelLoaded = (info) => onModelLoaded?.call(Live2dModelInfo(
          modelUrl: info.modelUrl,
          width: info.width,
          height: info.height,
          motionGroups: info.motionGroups,
        ));
    inner.onError = (e) => onError?.call(e.toString());
  }

  final Live2DController inner = Live2DController();

  @override
  void Function(Live2dModelInfo info)? onModelLoaded;

  @override
  void Function(String error)? onError;

  @override
  Future<void> loadModel(String assetPath, {bool autoInteract = true}) =>
      inner.loadModel(assetPath, autoInteract: autoInteract);

  @override
  Future<void> setExpression(String name) => inner.setExpression(name);

  @override
  Future<void> startMotion(String group, int index) =>
      inner.startMotion(group, index: index);

  @override
  void dispose() => inner.dispose();
}

/// Windows 端：webview_windows 容器 + 同款 JS 协议直调
class DesktopStageController extends Live2dStageController {
  WebviewController? _wc;
  Live2dPlayerServer? _server;
  final _pendingJs = <(String Function(), Completer<void>)>[];
  bool _pageReady = false;

  @override
  void Function(Live2dModelInfo info)? onModelLoaded;

  @override
  void Function(String error)? onError;

  /// 由 [_DesktopLive2dView] 在就绪后绑定（stage 内部使用）
  void attach({required WebviewController wc, required Live2dPlayerServer server}) {
    _wc = wc;
    _server = server;
    // player 页加载完成前发出的 JS 命令会丢（首开不显示的根因）——排队等就绪
    wc.loadingState.listen((state) {
      if (!_pageReady && state == LoadingState.navigationCompleted) {
        // navigationCompleted 只是 HTML 完了——pixi/Core 还在异步加载，
        // 要等 window.live2d 定义后命令才有效（首开不显示的深层原因）
        _flushWhenPlayerReady();
      }
    });
  }

  /// 轮询 window.live2d 出现后才 flush 排队命令
  Future<void> _flushWhenPlayerReady() async {
    for (var i = 0; i < 25; i++) {
      // 最多 5s
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        // 就绪=app 已创建（DOMContentLoaded 后 initApp 才建 app——window.live2d
        // 对象本身在 IIFE 里同步定义，探测它不够！）。warmup 返回 true 同时
        // 完成 WebGL context 预热——探测与预热合一。
        final ok = await _wc?.executeScript(
            'window.live2d && window.live2d.warmup ? window.live2d.warmup() : false;');
        if (ok == true || ok?.toString() == 'true') {
          _pageReady = true;
          AppLogger.instance.log('live2d', 'player 就绪+WebGL 预热完成（探测 ${i + 1} 轮）');
          for (final (buildJs, done) in _pendingJs) {
            _wc?.executeScript(buildJs()).whenComplete(done.complete);
          }
          _pendingJs.clear();
          return;
        }
      } catch (_) {}
    }
    // 超时：拉取 JS 侧诊断时间线（看卡在哪一步）再放行
    try {
      final diag = await _wc
          ?.executeScript('JSON.stringify(window._live2dDiag || []);');
      AppLogger.instance.log('live2d', 'player 就绪探测超时——JS 诊断：$diag');
    } catch (_) {}
    _pageReady = true;
    for (final (buildJs, done) in _pendingJs) {
      _wc?.executeScript(buildJs()).whenComplete(done.complete);
    }
    _pendingJs.clear();
  }

  /// [buildJs] 延迟到 flush 时才调用——排队时 _server 可能还没 attach，
  /// 提前拼 URL 会退化成裸路径（404 的根因）
  Future<void> _eval(String Function() buildJs) {
    if (!_pageReady) {
      final completer = Completer<void>();
      _pendingJs.add((buildJs, completer));
      return completer.future;
    }
    return _wc?.executeScript(buildJs()) ?? Future<void>.value();
  }

  String _resolve(String assetPath) =>
      _server?.getAssetUrl(assetPath) ?? assetPath;

  @override
  Future<void> loadModel(String assetPath, {bool autoInteract = true}) async {
    try {
      await _eval(() =>
          'window.live2d.loadModel("${_resolve(assetPath)}", {"fit":"contain","scale":1,"autoInteract":$autoInteract});');
      // 轮询渲染完成钩子（vendor 模板的 getRenderedAt）——画面真的上屏才回调
      final elapsed = await _waitRendered();
      onModelLoaded?.call(Live2dModelInfo(modelUrl: assetPath));
      AppLogger.instance.log(
          'live2d', '画面已渲染：$assetPath（${elapsed}ms 后首帧上屏${elapsed < 0 ? '，5s 超时未确认' : ''}）');
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  /// 轮询 getRenderedAt：>0 表示 pixi 第一帧已绘制。返回等待毫秒（-1=超时）
  Future<int> _waitRendered() async {
    final sw = Stopwatch()..start();
    // 首开冷 IO/贴图解码可达数秒（热缓存后几百毫秒）
    while (sw.elapsedMilliseconds < 12000) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        final r = await _wc?.executeScript(
            'window.live2d.getRenderedAt && window.live2d.getRenderedAt();');
        if (r != null && r != 0 && r != '0') return sw.elapsedMilliseconds;
      } catch (_) {}
    }
    // 超时：拉 JS 诊断时间线（看 loadModel 卡在哪一步）
    try {
      final diag = await _wc
          ?.executeScript('JSON.stringify(window._live2dDiag || []);');
      AppLogger.instance.log('live2d', '渲染钩子 12s 未触发——JS 诊断：$diag');
    } catch (_) {}
    return -1;
  }

  @override
  Future<void> setExpression(String name) =>
      _eval(() => 'window.live2d.setExpression("$name");');

  @override
  Future<void> startMotion(String group, int index) =>
      _eval(() => 'window.live2d.startMotion("$group", $index, 2);');

  @override
  void dispose() {
    _wc?.dispose();
    _server?.stop();
    _wc = null;
    _server = null;
  }
}

/// 跨平台 Live2D 舞台：透明背景、触摸跟踪（player 页内置）
class Live2dStage extends StatefulWidget {
  const Live2dStage({
    super.key,
    required this.controller,
    this.cubismCoreJsUrl,
  });

  /// 统一控制器（MobileStageController 或 DesktopStageController）
  final Live2dStageController controller;

  /// 本地 Cubism Core JS（assets 路径；不传则 player 页用内置默认）
  final String? cubismCoreJsUrl;

  @override
  State<Live2dStage> createState() => _Live2dStageState();
}

class _Live2dStageState extends State<Live2dStage> {
  Live2dPlayerServer? _server;
  WebviewController? _wc;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) _initDesktop();
  }

  Future<void> _initDesktop() async {
    // cubismCoreJsUrl 走同一注入链（server→player 页）——Ren 的 moc3 v6
    // 需要 vendor 的 Core 6 补丁版，漏传就会只有旧格式模型能显示。
    // server 用 vendor 版（player 模板带渲染完成钩子 getRenderedAt）。
    final server = Live2dPlayerServer(cubismCoreJsUrl: widget.cubismCoreJsUrl);
    await server.start();
    final wc = WebviewController();
    await wc.initialize();
    if (!mounted) {
      server.stop();
      return;
    }
    setState(() {
      _server = server;
      _wc = wc;
      _ready = true;
    });
    (widget.controller as DesktopStageController)
        .attach(wc: wc, server: server);
    await wc.loadUrl(server.playerUrl);
  }

  @override
  void dispose() {
    // 控制器的 dispose 负责释放 webview/server；这里兜底停掉 server
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      // mobile：live2d 包的 viewer（webview_flutter + 包内 server 全自动）
      final ctrl = widget.controller as MobileStageController;
      return Live2DViewer(
        controller: ctrl.inner,
        cubismCoreJsUrl: widget.cubismCoreJsUrl,
      );
    }
    // Windows：WebView2 容器
    if (!_ready) return const Center(child: Text('Live2D 舞台启动中…'));
    return Webview(_wc!);
  }
}
