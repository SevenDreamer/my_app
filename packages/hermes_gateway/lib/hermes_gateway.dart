//! Hermes gateway 客户端：`/api/ws` 上的换行分隔 JSON-RPC 2.0
//!
//! 协议依据 docs/HERMES_GATEWAY_PROTOCOL.md（源码实证）：
//! - accept 后服务端推 `gateway.ready`；
//! - 事件帧形 `{"method":"event","params":{"event":<name>,"payload":{...}}}`
//!   （对 `method` 即事件名的旧形态做了兼容解析）；
//! - 客户端每 15s 发一次 ping（兼作 scale-to-zero 存活标记）；
//! - 鉴权：Authorization: Bearer <token>（同时附 query token 兜底）。
//! 字段级不确定处见协议清单 §7——以真机 gateway 实测为准。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 网关事件（事件名 + 载荷）
class GatewayEvent {
  const GatewayEvent(this.name, this.payload);

  final String name;
  final Map<String, dynamic> payload;

  @override
  String toString() => 'GatewayEvent($name)';
}

/// 连接状态
enum GatewayStatus { disconnected, connecting, connected }

class HermesGatewayClient {
  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  final _pending = <int, Completer<Object?>>{};
  final _events = StreamController<GatewayEvent>.broadcast();
  Completer<void>? _ready;
  int _nextId = 1;

  /// 事件流（message.* / tool.* / approval.* …）
  Stream<GatewayEvent> get events => _events.stream;

  /// 当前状态
  GatewayStatus status = GatewayStatus.disconnected;

  /// 等待 `gateway.ready`（握手完成）
  Future<void> get ready => (_ready ?? Completer<void>()).future;

  /// 连接 gateway。[uri] 形如 ws://host:port/api/ws；[token] 可空（本地 ticket 模式）。
  Future<void> connect({required Uri uri, String? token}) async {
    await disconnect();
    status = GatewayStatus.connecting;
    _ready = Completer<void>();
    final headers = <String, String>{};
    var target = uri;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      // 兜底：部分反代只放行 query 形态
      target = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
      });
    }
    try {
      _ws = await WebSocket.connect(target.toString(), headers: headers);
    } catch (e) {
      status = GatewayStatus.disconnected;
      _ready = null;
      throw GatewayException('连接失败：$e');
    }
    status = GatewayStatus.connected;
    _sub = _ws!.listen(
      _onData,
      onDone: _onDone,
      onError: (Object e) => _events.add(GatewayEvent('error', {'error': '$e'})),
      cancelOnError: false,
    );
    // 客户端 ping：兼作 scale-to-zero 存活标记（协议要求 ~15s）
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _sendRaw({'jsonrpc': '2.0', 'method': 'ping'});
    });
  }

  /// 断开并释放
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (_) {}
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(GatewayException('连接已断开'));
    }
    _pending.clear();
    status = GatewayStatus.disconnected;
  }

  /// 发起 RPC，返回 `result`
  Future<Object?> request(String method,
      [Map<String, dynamic>? params]) async {
    final ws = _ws;
    if (ws == null) throw GatewayException('未连接');
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _sendRaw({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });
    return completer.future;
  }

  void _sendRaw(Map<String, dynamic> frame) {
    final ws = _ws;
    if (ws == null) return;
    // 换行分隔 JSON-RPC：一帧一行
    ws.add('${jsonEncode(frame)}\n');
  }

  void _onData(dynamic data) {
    for (final line in '$data'.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final frame = jsonDecode(trimmed);
        if (frame is Map<String, dynamic>) _onFrame(frame);
      } catch (_) {
        // 非法帧：忽略（协议另有 legacy fallback，见 §7）
      }
    }
  }

  void _onFrame(Map<String, dynamic> frame) {
    // 响应帧：带 id 且含 result/error
    final id = frame['id'];
    if (id is int && (frame.containsKey('result') || frame.containsKey('error'))) {
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      if (frame.containsKey('error')) {
        completer.completeError(
            GatewayException('RPC 失败：${jsonEncode(frame['error'])}'));
      } else {
        completer.complete(frame['result']);
      }
      return;
    }
    // 事件帧
    final method = frame['method'];
    if (method is! String || method == 'ping' || method == 'pong') return;
    if (method == 'event') {
      final params = (frame['params'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final name = (params['event'] ?? params['name'] ?? '') as String;
      final payload =
          (params['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      _emit(name, payload);
    } else {
      // 兼容形态：method 即事件名
      final payload = (frame['params'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      _emit(method, payload);
    }
  }

  void _emit(String name, Map<String, dynamic> payload) {
    if (name == 'gateway.ready') {
      final ready = _ready;
      if (ready != null && !ready.isCompleted) ready.complete();
    }
    _events.add(GatewayEvent(name, payload));
  }

  void _onDone() {
    status = GatewayStatus.disconnected;
    _events.add(const GatewayEvent('connection.closed', {}));
  }

  /// 释放事件流（页面销毁时）
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}

/// 客户端异常
class GatewayException implements Exception {
  GatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}
