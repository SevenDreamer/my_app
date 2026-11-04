//! DSH 对话 ViewModel（MVVM：View 只读快照 + 调命令；dsh_api 协议层注入）。
import 'dart:async';

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

  StreamSubscription<Object?>? _follow;

  /// 打开会话跟随流（mux session/follow——流式回执打字机效果）。
  Future<void> _openFollow() async {
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null) return;
    await client.mux.connect();
    final stream = await client.mux.open('session/follow',
        payload: {'args': {'session': sessionId}});
    _follow?.cancel();
    _follow = stream.items.listen(_onFollowItem,
        onError: (_) {}, onDone: () {});
    // 流终态：pending 消息收尾。
    stream.done.then((error) {
      if (_messages.isNotEmpty && _messages.last.pending) {
        _messages[_messages.length - 1] = DshChatMessage(
            role: 'assistant',
            text: error != null ? '接收中断：${error.code}' : _messages.last.text);
        notifyListeners();
      }
    });
  }

  /// 跟随流增量（帧形态：text 增量 / message 完成 / done）。
  void _onFollowItem(Object? item) {
    if (item is! Map) return;
    final frame = item.cast<String, Object?>();
    final pendingIndex = _messages.lastIndexWhere((m) => m.pending);
    switch (frame['type']) {
      case 'text': // 增量文本（打字机）
        final delta = '${frame['text'] ?? ''}';
        if (pendingIndex >= 0) {
          final prev = _messages[pendingIndex];
          _messages[pendingIndex] =
              DshChatMessage(role: 'assistant', text: prev.text + delta);
        } else {
          _messages.add(DshChatMessage(role: 'assistant', text: delta));
        }
      case 'message': // 轮次完成
        if (pendingIndex >= 0) {
          final prev = _messages[pendingIndex];
          _messages[pendingIndex] = DshChatMessage(
              role: 'assistant', text: '${frame['text'] ?? prev.text}');
        }
        _sending = false;
      case 'done':
        if (pendingIndex >= 0) {
          final prev = _messages[pendingIndex];
          _messages[pendingIndex] =
              DshChatMessage(role: 'assistant', text: prev.text);
        }
        _sending = false;
    }
    notifyListeners();
  }

  /// 发消息（排队语义；流式回执经 mux follow 流）。
  Future<void> send(String text) async {
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null || text.trim().isEmpty) return;
    _messages.add(DshChatMessage(role: 'user', text: text));
    _messages.add(const DshChatMessage(role: 'assistant', text: '', pending: true));
    _sending = true;
    notifyListeners();
    await _openFollow();
    try {
      await client.messages.send(sessionId, text);
    } on DshApiException catch (e) {
      final i = _messages.lastIndexWhere((m) => m.pending);
      if (i >= 0) {
        _messages[i] = DshChatMessage(role: 'assistant', text: '发送失败：${e.code}');
      }
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _follow?.cancel();
    _client?.dispose();
    super.dispose();
  }
}
