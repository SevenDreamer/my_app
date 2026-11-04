//! 会话 API（端点词汇对齐官方 `dsh web` 协议：list/page/follow/fork/interrupt…；
//! 实现原创）。
import 'connection.dart';
import 'models.dart';

class DshSessionsApi {
  DshSessionsApi(this._connection);

  final DshConnection _connection;

  /// 会话列表。
  Future<List<DshSessionSummary>> list() async {
    final result = await _connection.exchange('GET', '/api/sessions/list');
    final items = result['sessions'] ?? result['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => DshSessionSummary.fromJson(e.cast<String, Object?>()))
        .whereType<DshSessionSummary>()
        .toList();
  }

  /// 会话消息分页（含过程折叠/轮次语义由 UI 层处理，这里只透传原始帧）。
  Future<Map<String, Object?>> page(String sessionId,
      {int? throughSeq, int? limit}) async {
    return _connection.exchange('GET', '/api/sessions/page', query: {
      'session': sessionId,
      if (throughSeq != null) 'throughSeq': '$throughSeq',
      if (limit != null) 'limit': '$limit',
    });
  }

  /// 跟随会话（流式消息——经 mux 的 session/follow 流）。
  String get followEndpoint => 'session/follow';

  /// 打断当前任务。
  Future<void> interrupt(String sessionId) async {
    await _connection.exchange('POST', '/api/sessions/interrupt',
        body: {'session': sessionId});
  }

  /// 在某轮 fork（分叉会话）。
  Future<Map<String, Object?>> fork(String sessionId, int atSeq,
      {String? sourceTitle}) async {
    return _connection.exchange('POST', '/api/sessions/fork', body: {
      'session': sessionId,
      'atSeq': atSeq,
      if (sourceTitle != null) 'sourceTitle': sourceTitle,
    });
  }
}
