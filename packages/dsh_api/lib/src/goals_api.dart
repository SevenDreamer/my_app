//! 目标/计划 API（/目标 /计划 斜杠命令的底座）。
import 'connection.dart';

class DshGoalsApi {
  DshGoalsApi(this._connection);
  final DshConnection _connection;

  Future<Map<String, Object?>> list(String sessionId) async {
    return _connection.exchange('GET', '/api/goals/list', query: {'session': sessionId});
  }

  Future<Map<String, Object?>> set(String sessionId, String goal) async {
    return _connection.exchange('POST', '/api/goals/set',
        body: {'session': sessionId, 'goal': goal});
  }
}
