//! vendor: live2d 包的资产服务（改用带渲染钩子的 player 模板）
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'live2d_html_template.dart';

/// Lightweight embedded local HTTP server for serving the WebGL player and assets.
///
/// Binds to loopback IPv4 (`127.0.0.1`) on an ephemeral port. It serves:
/// - The generated WebGL HTML player (`/index.html`)
/// - Flutter assets from [rootBundle] (`/assets/*`)
/// - Local files from the device filesystem (`/file/*`)
///
/// Automatically adds permissive CORS headers to prevent canvas and WebGL fetch errors.
class Live2dPlayerServer {
  HttpServer? _server;
  int _port = 0;

  /// Custom URL for the Cubism 4/5 Core JavaScript runtime.
  final String? cubismCoreJsUrl;

  /// Custom URL for the Cubism 2.1 Core JavaScript runtime.
  final String? cubism2CoreJsUrl;

  /// Custom URL for the Pixi.js runtime.
  final String? pixiJsUrl;

  /// Custom URL for the pixi-live2d-display runtime.
  final String? pixiLive2dJsUrl;

  /// Creates a new [Live2DAssetServer].
  Live2dPlayerServer({
    this.cubismCoreJsUrl,
    this.cubism2CoreJsUrl,
    this.pixiJsUrl,
    this.pixiLive2dJsUrl,
  });

  /// The active loopback port of the local server.
  int get port => _port;

  /// The base URL of the local server (`http://127.0.0.1:<port>`).
  String get baseUrl => 'http://127.0.0.1:$_port';

  /// The URL pointing directly to the WebGL player entry point (`index.html`).
  String get playerUrl => '$baseUrl/index.html';

  /// Starts the embedded HTTP server on an available loopback port.
  Future<void> start() async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    _server!.listen(_handleRequest, onError: (Object error) {
      // Ignore background connection errors during shutdown
    });
  }

  /// Converts a Flutter asset path into a local HTTP URL.
  ///
  /// For example, `assets/models/hiyori/hiyori.model3.json` becomes
  /// `http://127.0.0.1:<port>/assets/models/hiyori/hiyori.model3.json`.
  String getAssetUrl(String assetPath) {
    var path = assetPath.trim();
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return '$baseUrl/assets/$path';
  }

  /// Converts a local filesystem path into a local HTTP URL.
  ///
  /// For example, `/sdcard/models/hiyori.model3.json` becomes
  /// `http://127.0.0.1:<port>/file/sdcard/models/hiyori.model3.json`.
  String getFileUrl(String filePath) {
    var path = filePath.trim();
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return '$baseUrl/file/$path';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Enable permissive CORS for WebGL fetches
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    final rawPath = Uri.decodeComponent(request.uri.path);

    // 1. Serve Player HTML
    if (rawPath == '/' || rawPath == '/index.html') {
      // 全部本地资产（CDN 是首开慢/渲染失败的来源——已 vendor 到 assets/live2d/）
      final html = buildLive2DHtml(
        cubismCoreJsUrl: cubismCoreJsUrl,
        cubism2CoreJsUrl: cubism2CoreJsUrl ??
            getAssetUrl('assets/assets/live2d/live2dcubism2core.min.js'),
        pixiJsUrl: pixiJsUrl ?? getAssetUrl('assets/assets/live2d/pixi.min.js'),
        pixiLive2dJsUrl: pixiLive2dJsUrl ??
            getAssetUrl('assets/assets/live2d/pixi-live2d-display.min.js'),
      );
      response.headers.contentType = ContentType.html;
      response.write(html);
      await response.close();
      return;
    }

    // 2. Serve Flutter Assets
    if (rawPath.startsWith('/assets/')) {
      final assetKey = rawPath.replaceFirst('/assets/', '');
      try {
        final byteData = await rootBundle.load(assetKey);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );

        _setContentType(response, assetKey);
        response.contentLength = bytes.length;
        response.add(bytes);
        await response.close();
        return;
      } catch (_) {
        response.statusCode = HttpStatus.notFound;
        response.write('Asset not found: $assetKey');
        await response.close();
        return;
      }
    }

    // 3. Serve Local Files
    if (rawPath.startsWith('/file/')) {
      final filePath = '/${rawPath.replaceFirst('/file/', '')}';
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _setContentType(response, filePath);
        response.contentLength = bytes.length;
        response.add(bytes);
        await response.close();
        return;
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('File not found: $filePath');
        await response.close();
        return;
      }
    }

    // Default 404
    response.statusCode = HttpStatus.notFound;
    response.write('Not found: $rawPath');
    await response.close();
  }

  void _setContentType(HttpResponse response, String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.moc3') || lower.endsWith('.moc')) {
      response.headers.contentType = ContentType.binary;
    } else if (lower.endsWith('.json') || lower.endsWith('.model3.json')) {
      response.headers.contentType = ContentType.json;
    } else if (lower.endsWith('.png')) {
      response.headers.set('Content-Type', 'image/png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      response.headers.set('Content-Type', 'image/jpeg');
    } else {
      final mimeType = lookupMimeType(path) ?? 'application/octet-stream';
      final parts = mimeType.split('/');
      if (parts.length == 2) {
        response.headers.contentType = ContentType(parts[0], parts[1]);
      } else {
        response.headers.contentType = ContentType.binary;
      }
    }
  }

  /// Stops the embedded server and frees resources.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
