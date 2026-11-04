//! DSH 对话 ViewModel（MVVM：View 只读快照 + 调命令；dsh_api 协议层注入）。
import 'package:dsh_api/dsh_api.dart';
import 'package:flutter/foundation.dart';

/// 一条聊天消息（角色/文本/状态）。
class DshChatMessage {
  const DshChatMessage({required this.role, required this.text, this.pending = false});
  final String role; // user | assistant
  final String text;
  final bool pending;
}

class DshChatViewModel extends ChangeNotifier {
  DshChatViewModel({DshClient? client}) : _client = client;

  DshClient? _client;
  final List<DshChatMessage> _messages = [];
  String _status = '未连接';
  String? _sessionId;
  bool _sending = false;

  List<DshChatMessage> get messages => List.unmodifiable(_messages);
  String get status => _status;
  bool get sending => _sending;

  /// 连接（launch token → 登录 → 拉会话）。
  Future<void> connect(String baseUrl, String launchToken) async {
    _client ??= DshClient(baseUrl);
    _status = '连接中…';
    notifyListeners();
    try {
      await _client!.login(launchToken);
      final sessions = await _client!.sessions.list();
      _sessionId = sessions.isNotEmpty ? sessions.first.id : null;
      _status = '已连接';
    } on DshApiException catch (e) {
      _status = '连接失败：${e.code}';
    } catch (e) {
      _status = '连接失败：$e';
    }
    notifyListeners();
  }

  /// 发消息（排队语义；流式回执经 mux follow 流——下一批接）。
  Future<void> send(String text) async {
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null || text.trim().isEmpty) return;
    _messages.add(DshChatMessage(role: 'user', text: text));
    _messages.add(const DshChatMessage(role: 'assistant', text: '…', pending: true));
    _sending = true;
    notifyListeners();
    try {
      await client.messages.send(sessionId, text);
      // 流式回复经 mux（session/follow）——Phase C2 接；当前占位收尾。
      _messages[_messages.length - 1] =
          DshChatMessage(role: 'assistant', text: '（流式接收待接）');
    } on DshApiException catch (e) {
      _messages[_messages.length - 1] =
          DshChatMessage(role: 'assistant', text: '发送失败：${e.code}');
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
