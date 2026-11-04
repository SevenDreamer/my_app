//! 消息 API（发消息/待办/反馈——端点词汇对齐官方协议，实现原创）。
import 'connection.dart';

class DshMessagesApi {
  DshMessagesApi(this._connection);

  final DshConnection _connection;

  /// 发送消息（排队/插话语义由 args 表达，UI 层决定）。
  Future<Map<String, Object?>> send(
    String sessionId,
    String text, {
    String mode = 'queue', // queue | interrupt（排队/插话）
  }) async {
    return _connection.exchange('POST', '/api/messages/prompt', body: {
      'session': sessionId,
      'text': text,
      'mode': mode,
    });
  }

  /// 待办列表（Todo 条数据源）。
  Future<Map<String, Object?>> todos(String sessionId) async {
    return _connection.exchange('GET', '/api/sessions/todos',
        query: {'session': sessionId});
  }

  /// 消息反馈（👍/👎）。
  Future<void> feedback(
      String sessionId, String messageId, String verdict) async {
    await _connection.exchange('PUT', '/api/messages/feedback', body: {
      'session': sessionId,
      'message': messageId,
      'verdict': verdict,
    });
  }

  /// 导出会话日志（/export 语义）。
  Future<Map<String, Object?>> export(String sessionId) async {
    return _connection.exchange('GET', '/api/sessions/export',
        query: {'session': sessionId});
  }
}
