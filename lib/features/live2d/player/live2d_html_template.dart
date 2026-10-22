//! vendor: live2d 包的 player 模板（buildLive2DHtml）
//! 仅加了渲染完成钩子（_renderedAt/getRenderedAt）——画面真的上屏才标记
//! 来源 live2d-1.0.1/html_template.dart，勿整体重构

// Generated HTML template for Live2D WebGL Player using Pixi.js & pixi-live2d-display.

/// Generates the HTML player page for Live2D WebGL rendering.
String buildLive2DHtml({
  String? cubismCoreJsUrl,
  String? cubism2CoreJsUrl,
  String? pixiJsUrl,
  String? pixiLive2dJsUrl,
}) {
  final c4Url = cubismCoreJsUrl ??
      'https://cubism.live2d.com/sdk-web/cubismcore/live2dcubismcore.min.js';
  final c2Url = cubism2CoreJsUrl ??
      'https://cdn.jsdelivr.net/gh/dylanNew/live2d/webgl/Live2D/lib/live2d.min.js';
  final pixiUrl = pixiJsUrl ??
      'https://cdnjs.cloudflare.com/ajax/libs/pixi.js/7.4.2/pixi.min.js';
  final pLive2dUrl = pixiLive2dJsUrl ??
      'https://cdn.jsdelivr.net/npm/pixi-live2d-display@0.4.0/dist/index.min.js';

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Live2D Viewer</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: transparent !important;
      background-color: transparent !important;
    }
    #canvas {
      display: block;
      width: 100vw;
      height: 100vh;
      touch-action: none;
      background: transparent !important;
    }
  </style>

  <!-- Cubism Core 2.1 & 4/5 Runtimes -->
  <script src="$c2Url"></script>
  <script src="$c4Url"></script>

  <!-- Pixi.js -->
  <script src="$pixiUrl"></script>

  <!-- pixi-live2d-display -->
  <script src="$pLive2dUrl"></script>
</head>
<body>
  <canvas id="canvas"></canvas>

  <script>
    (function() {
      let app = null;
      let currentModel = null;
      let fitMode = 'contain';
      let userScale = 1.0;
      let offsetX = 0;
      let offsetY = 0;
      let autoInteractEnabled = true;

      function notifyFlutter(action, data = {}) {
        try {
          if (window.Live2DChannel && window.Live2DChannel.postMessage) {
            window.Live2DChannel.postMessage(JSON.stringify({ action: action, data: data }));
          }
        } catch (e) {
          console.error("Failed to notify Flutter:", e);
        }
      }

      function initApp() {
        const canvas = document.getElementById('canvas');
        app = new PIXI.Application({
          view: canvas,
          autoStart: true,
          resizeTo: window,
          backgroundAlpha: 0,
          antialias: true,
          resolution: window.devicePixelRatio || 1,
          autoDensity: true
        });

        window.addEventListener('resize', () => {
          if (currentModel) {
            applyTransform();
          }
        });

        notifyFlutter('onReady', { version: '1.0.0' });
      }

      function applyTransform() {
        if (!currentModel) return;
        const screenW = window.innerWidth;
        const screenH = window.innerHeight;
        
        const internalW = currentModel.internalModel?.width || currentModel.width || 800;
        const internalH = currentModel.internalModel?.height || currentModel.height || 800;

        let baseScale = 1.0;
        if (fitMode === 'contain') {
          baseScale = Math.min(screenW / internalW, screenH / internalH) * 0.9;
        } else if (fitMode === 'cover') {
          baseScale = Math.max(screenW / internalW, screenH / internalH);
        } else if (fitMode === 'fitWidth') {
          baseScale = (screenW / internalW) * 0.95;
        } else if (fitMode === 'fitHeight') {
          baseScale = (screenH / internalH) * 0.95;
        } else if (fitMode === 'none') {
          baseScale = 1.0;
        }

        const finalScale = baseScale * userScale;
        currentModel.scale.set(finalScale);

        currentModel.anchor.set(0.5, 0.5);
        currentModel.x = (screenW / 2) + offsetX;
        currentModel.y = (screenH / 2) + offsetY;
      }

      // 诊断时间线（Dart 轮询拉取）——挂独立对象，勿挂 window.live2d
      // （它在本 IIFE 尾部才定义，提前挂属性会抛错毁掉整个 player 脚本）
      window._live2dDiag = [];
      const dlog = (m) => {
        window._live2dDiag.push('' + Date.now() + ': ' + m);
        console.log('[live2d]', m);
      };
      // XHR 包装（诊断）：pixi-live2d-display 用的是 XHR 而非 fetch——
      // 首开挂起时看最后一个 XHR 停在 open 还是 send
      const _origXhrOpen = XMLHttpRequest.prototype.open;
      const _origXhrSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function (m, u, ...rest) {
        this._diagUrl = u;
        dlog('XHR open ' + m + ' ' + u);
        return _origXhrOpen.call(this, m, u, ...rest);
      };
      XMLHttpRequest.prototype.send = function (...args) {
        dlog('XHR send ' + this._diagUrl);
        this.addEventListener('load', () => dlog('XHR ← ' + this._diagUrl + ' [' + this.status + ']'));
        this.addEventListener('error', () => dlog('XHR ✗ ' + this._diagUrl));
        return _origXhrSend.apply(this, args);
      };
      // fetch 包装（诊断）：Live2DModel.from 内部的每个请求都留痕——
      // "卡死"还是"慢"，看最后一个 fetch 有没有 ← 响应就一目了然
      const _origFetch = window.fetch.bind(window);
      window.fetch = async (...args) => {
        dlog('fetch → ' + args[0]);
        try {
          const r = await _origFetch(...args);
          dlog('fetch ← ' + args[0] + ' [' + r.status + ']');
          return r;
        } catch (e) {
          dlog('fetch ✗ ' + args[0] + '（' + e + '）');
          throw e;
        }
      };

      async function loadModel(modelUrl, options = {}) {
        dlog('loadModel 请求: ' + modelUrl);
        try {
          if (options.fit) fitMode = options.fit;
          if (options.scale !== undefined) userScale = options.scale;
          if (options.autoInteract !== undefined) autoInteractEnabled = options.autoInteract;

          if (currentModel) {
            app.stage.removeChild(currentModel);
            currentModel.destroy();
            currentModel = null;
          }

          dlog('Live2DModel.from 开始（含 .moc3 解析+贴图加载）URL=' + modelUrl);
          const _fromPromise = PIXI.live2d.Live2DModel.from(modelUrl, {

            autoInteract: autoInteractEnabled
          });
          _fromPromise.then(() => dlog('from resolve ✓')).catch((e) => dlog('from reject ✗: ' + e));
          const model = await _fromPromise;

          currentModel = model;
          dlog('模型 ready，加入 stage');
          app.stage.addChild(model);
          // 渲染完成钩子：下一帧真正绘制后标记——Dart 轮询它=画面已上屏
          app.ticker.addOnce(() => { window.live2d._renderedAt = Date.now(); });

          applyTransform();

          // Listen for hit area interactions
          model.on('hit', (hitAreas) => {
            notifyFlutter('onHit', { hitAreas: hitAreas });
          });

          // Extract motion groups and expressions
          let motionGroups = [];
          try {
            if (model.internalModel?.motionManager?.definitions) {
              motionGroups = Object.keys(model.internalModel.motionManager.definitions);
            }
          } catch (_) {}

          let expressions = [];
          try {
            if (model.internalModel?.motionManager?.expressionManager?.definitions) {
              expressions = model.internalModel.motionManager.expressionManager.definitions.map(
                (d, i) => d.name || d.id || i.toString()
              );
            }
          } catch (_) {}

          notifyFlutter('onModelLoaded', {
            modelUrl: modelUrl,
            width: model.width,
            height: model.height,
            motionGroups: motionGroups,
            expressions: expressions
          });
        } catch (err) {
          console.error("Live2D loadModel error:", err);
          notifyFlutter('onError', {
            message: err ? (err.message || err.toString()) : 'Unknown model load error'
          });
        }
      }

      function startMotion(group, index = 0, priority = 2) {
        if (!currentModel) return;
        try {
          const result = currentModel.motion(group, index, priority);
          if (result && typeof result.then === 'function') {
            result.then(() => {
              notifyFlutter('onMotionFinished', { group: group, index: index });
            }).catch((err) => {
              console.warn("Motion finished with error:", err);
            });
          }
        } catch (err) {
          console.error("startMotion error:", err);
        }
      }

      function setExpression(id) {
        if (!currentModel) return;
        try {
          currentModel.expression(id);
        } catch (err) {
          console.error("setExpression error:", err);
        }
      }

      function setParameter(id, value) {
        if (!currentModel) return;
        try {
          if (currentModel.internalModel?.coreModel?.setParameterValueById) {
            currentModel.internalModel.coreModel.setParameterValueById(id, value);
          } else if (currentModel.internalModel?.coreModel?.setParamFloat) {
            currentModel.internalModel.coreModel.setParamFloat(id, value);
          }
        } catch (err) {
          console.error("setParameter error:", err);
        }
      }

      function lookAt(x, y) {
        if (!currentModel) return;
        try {
          currentModel.focus(x, y);
        } catch (err) {
          console.error("lookAt error:", err);
        }
      }

      function setScale(scale) {
        userScale = scale;
        applyTransform();
      }

      function setPosition(x, y) {
        offsetX = x;
        offsetY = y;
        applyTransform();
      }

      function setFit(fit) {
        fitMode = fit;
        applyTransform();
      }

      function setInteractive(enabled) {
        autoInteractEnabled = enabled;
        if (currentModel) {
          currentModel.interactive = enabled;
        }
      }

      function reset() {
        userScale = 1.0;
        offsetX = 0;
        offsetY = 0;
        if (currentModel) {
          applyTransform();
        }
      }

      window.live2d = {
        loadModel: loadModel,
        startMotion: startMotion,
        setExpression: setExpression,
        setParameter: setParameter,
        lookAt: lookAt,
        setScale: setScale,
        setPosition: setPosition,
        setFit: setFit,
        setInteractive: setInteractive,
        reset: reset,
        getRenderedAt: () => window.live2d._renderedAt || 0,
        // 预热：强制渲染一帧（WebGL context 冷启动是首开慢/失败的来源）
        warmup: () => {
          try { app.renderer.render(app.stage); return true; }
          catch (e) { return false; }
        }
      };

      window.addEventListener('DOMContentLoaded', initApp);
    })();
  </script>
</body>
</html>''';
}
