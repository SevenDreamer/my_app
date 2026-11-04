//! 聚合门面：一个 [DshClient] 装起连接与各 API 模块（模块按需扩展）。
import 'agents_api.dart';
import 'connection.dart';
import 'files_api.dart';
import 'goals_api.dart';
import 'messages_api.dart';
import 'mux.dart';
import 'sessions_api.dart';

class DshClient {
  DshClient(String baseUrl) : connection = DshConnection(baseUrl: baseUrl) {
    sessions = DshSessionsApi(connection);
    messages = DshMessagesApi(connection);
    files = DshFilesApi(connection);
    goals = DshGoalsApi(connection);
    agents = DshAgentsApi(connection);
    mux = DshMux(connection);
  }

  final DshConnection connection;
  late final DshSessionsApi sessions;
  late final DshMessagesApi messages;
  late final DshFilesApi files;
  late final DshGoalsApi goals;
  late final DshAgentsApi agents;
  late final DshMux mux;

  /// 登录（launch token）；后续 401 由调用方捕获重登。
  Future<void> login(String launchToken) => connection.login(launchToken);

  void dispose() {
    mux.dispose();
    connection.close();
  }
}
