//! 多路复用：一根 WebSocket 跑 N 条逻辑流（帧协议设计参考 dsh-go mux 形态，
//! 代码原创）。
//!
//! 帧（JSON 文本，一帧一 WS 消息）：
//! ```text
//! client→host  {"type":"open","streamId":"<uuid>","endpoint":"…","payload":{…}}
//!              {"type":"item","streamId":…,"value":…}
//!              {"type":"end"|"cancel","streamId":…}
//! host→client  {"type":"item"|"end"|"error","streamId":…,"error":{code,message,details}}
//! ```
//! 语义约定：断线期间的单向通知**不重放**（调用方自行补偿）；连接代
//! （generation）内 pending 请求记账，重连带 backoff；内部 `$events` 流
//! 每代首帧为 `ready` 握手。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'connection.dart';
import 'errors.dart';

/// 一条逻辑流的下行端（item/end/error 三态收尾）。
class DshStream {
  DshStream(this.id);

  final String id;
  final _items = StreamController<Object?>.broadcast();
  final _done = Completer<DshApiException?>();

  Stream<Object?> get items => _items.stream;

  /// 流收尾（error 为 null = 正常 end）。
  Future<DshApiException?> get done => _done.future;

  void _item(Object? value) => _items.add(value);

  void _finish(DshApiException? error) {
    if (_done.isCompleted) return;
    _done.complete(error);
    _items.close();
  }
}

class DshMux {
  DshMux(this.connection, {this.endpoint = '/api/remote.mux'});

  final DshConnection connection;
  final String endpoint;

  final _random = Random();
  final _streams = <String, DshStream>{};
  WebSocket? _socket;
  int _generation = 0;

  /// 当前连接代（每重连递增；上代流全部按「不重放」语义收尾）。
  int get generation => _generation;

  /// 连接（幂等；掉线自动重连，backoff 1s→30s）。
  Future<void> connect() async {
    if (_socket != null) return;
    var backoffMs = 1000;
    while (true) {
      try {
        final socket = await connection.openWebSocket(endpoint);
        _socket = socket;
        _generation++;
        socket.listen(_onFrame,
            onDone: _onDisconnect, onError: (_) => _onDisconnect());
        return;
      } catch (e) {
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
        backoffMs = (backoffMs * 2).clamp(1000, 30000);
      }
    }
  }

  /// 开一条逻辑流（endpoint + payload；返回上行/收尾句柄）。
  Future<DshStream> open(String endpoint, {Map<String, Object?>? payload}) async {
    await connect();
    final id = _uuid();
    final stream = DshStream(id);
    _streams[id] = stream;
    _send({
      'type': 'open',
      'streamId': id,
      'endpoint': endpoint,
      'payload': payload ?? const <String, Object?>{'args': <String, Object?>{}},
    });
    return stream;
  }

  /// 上行 item（流内继续发值）。
  void send(String streamId, Object? value) {
    _send({'type': 'item', 'streamId': streamId, 'value': value});
  }

  /// 半关（uplink end）。
  void closeStream(String streamId) {
    _send({'type': 'end', 'streamId': streamId});
  }

  /// 取消流。
  void cancel(String streamId) {
    _send({'type': 'cancel', 'streamId': streamId});
    _streams.remove(streamId)?._finish(null);
  }

  void _send(Map<String, Object?> frame) {
    final socket = _socket;
    if (socket == null) {
      throw const DshApiException('MUX_DISCONNECTED', '连接断开（不重放，调用方补偿）');
    }
    socket.add(jsonEncode(frame));
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    final Map<String, Object?> frame;
    try {
      frame = (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return; // 非法帧静默丢（协议容忍面）
    }
    final streamId = frame['streamId'];
    if (streamId is! String) return;
    switch (frame['type']) {
      case 'item':
        _streams[streamId]?._item(frame['value']);
      case 'end':
        _streams.remove(streamId)?._finish(null);
      case 'error':
        final err = frame['error'];
        final exception = err is Map
            ? DshApiException('${err['code'] ?? 'MUX_ERROR'}',
                '${err['message'] ?? ''}',
                details: err['details'])
            : const DshApiException('MUX_ERROR', '');
        _streams.remove(streamId)?._finish(exception);
    }
  }

  void _onDisconnect() {
    final socket = _socket;
    _socket = null;
    socket?.close();
    // 「不重放」语义：断线时在途流全部按错误收尾，调用方自行重开补偿。
    final pending = List<DshStream>.from(_streams.values);
    _streams.clear();
    for (final s in pending) {
      s._finish(const DshApiException(
          'MUX_DISCONNECTED', '连接断开（不重放，调用方补偿）'));
    }
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
        '-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  void dispose() {
    _onDisconnect();
  }
}
