//! DSH 对话 ViewModel（MVVM：View 只读快照 + 调命令；dsh_client 协议层注入）。
//!
//! 协议层已切换 dsh-go 真件 `dsh_client`（AGPL 派生，批次 2）：
//! token→cookie 登录（[DshClient.connect]）、会话列表（[DshClient.listSessions]）、
//! 排队发信（[DshClient.prompt]）、打字机流（[DshClient.watch] 强类型事件）。
import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/foundation.dart';

import 'dsh_web_launcher.dart';

/// 一条聊天消息（角色/文本/状态）。
class DshChatMessage {
  const DshChatMessage({required this.role, required this.text, this.pending = false});
  final String role; // user | assistant
  final String text;
  final bool pending;
}

class DshChatViewModel extends ChangeNotifier {
  DshChatViewModel({this._client});

  DshClient? _client;
  final List<DshChatMessage> _messages = [];
  String _status = '未连接';
  String? _sessionId;
  bool _sending = false;

  List<DshChatMessage> get messages => List.unmodifiable(_messages);
  String get status => _status;
  bool get sending => _sending;

  DshWebLauncher? _launcher;

  /// 启动本机引擎（dsh web：起容器进程 → 扫 token → 自动连接）。
  Future<void> startEngine() async {
    _launcher ??= DshWebLauncher();
    _status = '启动 DSH 引擎…';
    notifyListeners();
    final status = await _launcher!.start();
    if (status.phase == DshWebPhase.running &&
        status.baseUrl != null &&
        status.token != null) {
      await connect(status.baseUrl!, status.token!);
    } else {
      _status = '引擎启动失败：${status.error ?? status.phase.name}';
      notifyListeners();
    }
  }

  /// 连接（launch token → 登录换 cookie → mux ready → 拉会话）。
  Future<void> connect(String baseUrl, String launchToken) async {
    _status = '连接中…';
    notifyListeners();
    try {
      _client = await DshClient.connect(
        baseUri: Uri.parse(baseUrl),
        token: launchToken,
      );
      final sessions = await _client!.listSessions();
      _sessionId = sessions.isNotEmpty ? sessions.first.sessionId : null;
      _status = '已连接';
    } catch (e) {
      _status = '连接失败：$e';
    }
    notifyListeners();
  }

  StreamSubscription<DshEvent>? _watch;

  /// 打开会话跟随流（watch()：强类型事件 + 断线重连/快照重同步由封装承担）。
  void _openWatch() {
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null) return;
    _watch?.cancel();
    _watch = client.watch(sessionId).listen(
      _onEvent,
      onError: (Object e) {
        _settlePending('接收中断：$e');
      },
      onDone: () {
        _settlePending(null);
      },
    );
  }

  /// 会话事件（打字机：AssistantChunkEvent 增量 → AssistantStreamEnded 收尾）。
  void _onEvent(DshEvent event) {
    switch (event) {
      case AssistantChunkEvent(:final chunk):
        if (chunk is TextDeltaChunk) {
          _appendDelta(chunk.text);
        }
      case AssistantStreamEnded(:final committed):
        _settlePending(committed ? null : '（本轮未提交）');
      default:
        // 快照/同步/连接态等事件不改对话面（V1 不回填历史）
        break;
    }
    notifyListeners();
  }

  void _appendDelta(String delta) {
    if (delta.isEmpty) return;
    final pendingIndex = _messages.lastIndexWhere((m) => m.pending);
    if (pendingIndex >= 0) {
      final prev = _messages[pendingIndex];
      _messages[pendingIndex] =
          DshChatMessage(role: 'assistant', text: prev.text + delta);
    } else {
      _messages.add(DshChatMessage(role: 'assistant', text: delta));
    }
    notifyListeners();
  }

  /// pending 消息收尾（error 为 null 保持现状文案，空文本显示省略号）。
  void _settlePending(String? error) {
    final i = _messages.lastIndexWhere((m) => m.pending);
    if (i >= 0) {
      final prev = _messages[i];
      _messages[i] = DshChatMessage(
          role: 'assistant', text: error ?? (prev.text.isEmpty ? '…' : prev.text));
    }
    _sending = false;
    notifyListeners();
  }

  /// 发消息（排队语义 prompt；流式回执经 watch 事件流）。
  Future<void> send(String text) async {
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null || text.trim().isEmpty) return;
    _messages.add(DshChatMessage(role: 'user', text: text));
    _messages.add(const DshChatMessage(role: 'assistant', text: '', pending: true));
    _sending = true;
    notifyListeners();
    _openWatch();
    try {
      await client.prompt(sessionId, text);
    } catch (e) {
      _settlePending('发送失败：$e');
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _client?.close();
    super.dispose();
  }
}
