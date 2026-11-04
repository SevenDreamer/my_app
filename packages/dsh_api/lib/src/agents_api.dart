//! Agent/模型 API（模型与推理等级、子代理面）。
import 'connection.dart';

class DshAgentsApi {
  DshAgentsApi(this._connection);
  final DshConnection _connection;

  /// 可用模型列表（/模型 数据源）。
  Future<Map<String, Object?>> models() async {
    return _connection.exchange('GET', '/api/agents/models');
  }

  /// 设定会话模型与推理等级。
  Future<void> selectModel(String sessionId, String model, {String? reasoning}) async {
    await _connection.exchange('POST', '/api/agents/model', body: {
      'session': sessionId,
      'model': model,
      if (reasoning != null) 'reasoning': reasoning,
    });
  }
}
