//! Hermes 客户端视图模型：连接 gateway、收发对话、聚合工具流
//!
//! MVVM：View 只读快照 + 调命令方法；gateway 客户端（hermes_gateway 包）
//! 经构造函数注入。事件语义见 docs/HERMES_GATEWAY_PROTOCOL.md §4/§6。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hermes_gateway/hermes_gateway.dart';

export 'package:hermes_gateway/hermes_gateway.dart' show GatewayStatus;

/// 会话里的一条记录（对话/工具/系统）
class ChatEntry {
  ChatEntry(this.kind, this.text, {this.streaming = false, this.meta});

  /// user / assistant / tool / system
  final String kind;
  String text;
  bool streaming;

  /// 工具卡原始载荷（展开时显示）
  final Map<String, dynamic>? meta;

  /// 工具卡是否展开
  bool expanded = false;

  /// 交互类条目（审批卡）是否已处理
  bool done = false;
}

/// 会话列表条目
class SessionInfo {
  SessionInfo({required this.id, required this.title, this.updatedAt});

  final String id;
  String title;
  final String? updatedAt;
}

class HermesViewModel extends ChangeNotifier {
  HermesViewModel([HermesGatewayClient? client]) : _client = client ?? HermesGatewayClient() {
    _sub = _client.events.listen(_onEvent);
  }

  final HermesGatewayClient _client;
  StreamSubscription<GatewayEvent>? _sub;

  /// 会话记录（时间序）
  final List<ChatEntry> entries = [];

  /// 会话列表（session.list）
  final List<SessionInfo> sessions = [];

  /// 当前会话 id（session.create 的结果）
  String? sessionId;

  /// 是否有任务在跑（用于显示「停止」）
  bool busy = false;

  /// 思考中指示
  bool thinking = false;

  /// 连接状态文案（含错误）
  String statusText = '未连接';

  GatewayStatus get status => _client.status;

  /// 连接 gateway 并建会话
  Future<void> connect(String url, String token) async {
    var uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      uri = Uri.tryParse('ws://${url.trim()}');
    }
    if (uri == null) {
      statusText = '地址无效';
      notifyListeners();
      return;
    }
    statusText = '连接中…';
    notifyListeners();
    try {
      await _client.connect(
          uri: uri, token: token.trim().isEmpty ? null : token.trim());
      await _client.ready
          .timeout(const Duration(seconds: 10), onTimeout: () {});
      statusText = '已连接';
      _add('system', '已连接 ${uri.host}（gateway.ready）');
      // 建一个会话拿 session_id（失败不阻塞聊天，prompt.submit 或可自建）
      try {
        final r = await _client.request('session.create', {});
        if (r is Map && r['id'] != null) sessionId = '${r['id']}';
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      statusText = '连接失败';
      _add('system', '$e');
      notifyListeners();
    }
  }

  /// 断开
  Future<void> disconnect() async {
    await _client.disconnect();
    statusText = '已断开';
    notifyListeners();
  }

  /// 探测本机（Termux）gateway：逐个候选端口试握手，返回第一个通的地址
  Future<String?> detectLocal() async {
    const candidates = [9120, 9006, 8765, 8080];
    for (final port in candidates) {
      final uri = Uri.parse('ws://127.0.0.1:$port/api/ws');
      try {
        final ws = await WebSocket.connect(uri.toString())
            .timeout(const Duration(seconds: 2));
        await ws.close();
        return uri.toString();
      } catch (_) {}
    }
    return null;
  }

  /// 一键：检测本机网关并连接（Termux 同机场景免手输）
  Future<void> detectAndConnect(String token) async {
    statusText = '检测本机网关…';
    notifyListeners();
    final url = await detectLocal();
    if (url == null) {
      statusText = '未检测到本机网关——请先在 Termux 启动 gateway（webapp.enabled true）';
      notifyListeners();
      return;
    }
    await connect(url, token);
  }

  /// 刷新会话列表
  Future<void> refreshSessions() async {
    try {
      final r = await _client.request('session.list', {});
      final list = switch (r) {
        final List l => l,
        final Map m when m['sessions'] is List => m['sessions'] as List,
        _ => const [],
      };
      sessions
        ..clear()
        ..addAll(list.whereType<Map>().map((m) {
          final map = m.cast<String, dynamic>();
          return SessionInfo(
            id: '${map['id'] ?? map['session_id'] ?? ''}',
            title: '${map['title'] ?? map['name'] ?? ''}',
            updatedAt: '${map['updated_at'] ?? map['updatedAt'] ?? map['timestamp'] ?? ''}',
          );
        }));
      notifyListeners();
    } catch (_) {
      // 列表失败不阻塞（字段契约未定，见协议清单 §7）
    }
  }

  /// 新建会话
  Future<void> newSession() async {
    entries.clear();
    sessionId = null;
    try {
      final r = await _client.request('session.create', {});
      if (r is Map && r['id'] != null) sessionId = '${r['id']}';
    } catch (_) {}
    notifyListeners();
  }

  /// 打开一个会话（尽力拉取历史）
  Future<void> openSession(String id) async {
    sessionId = id;
    entries.clear();
    notifyListeners();
    try {
      final r = await _client.request('session.history', {'session_id': id});
      final list = switch (r) {
        final List l => l,
        final Map m when m['messages'] is List => m['messages'] as List,
        _ => const [],
      };
      for (final item in list.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final role = '${m['role'] ?? m['kind'] ?? ''}';
        final text = '${m['content'] ?? m['text'] ?? ''}';
        if (text.isEmpty) continue;
        entries.add(ChatEntry(switch (role) {
          'user' => 'user',
          'assistant' || 'model' => 'assistant',
          'tool' => 'tool',
          _ => 'system',
        }, text));
      }
    } catch (_) {
      // 历史拉取失败（字段契约未定）：空列表进会话
    }
    notifyListeners();
  }

  /// 展开/收起工具卡
  void toggleEntry(ChatEntry entry) {
    entry.expanded = !entry.expanded;
    notifyListeners();
  }

  /// 回应审批卡（允许/拒绝）
  Future<void> respondApproval(ChatEntry entry, bool approved) async {
    final meta = entry.meta ?? const <String, dynamic>{};
    final id = meta['id'] ?? meta['approval_id'] ?? meta['request_id'];
    entry.done = true;
    entry.text += approved ? ' → 已允许' : ' → 已拒绝';
    notifyListeners();
    try {
      await _client.request('approval.respond', {
        if (id != null) 'id': id,
        'approved': approved,
      });
    } catch (e) {
      _add('system', '审批回应失败：$e');
      notifyListeners();
    }
  }

  /// 发送一条消息
  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    _add('user', body);
    final reply = ChatEntry('assistant', '', streaming: true);
    entries.add(reply);
    busy = true;
    thinking = true;
    notifyListeners();
    try {
      await _client.request('prompt.submit', {
        if (sessionId != null) 'session_id': sessionId,
        'text': body,
      });
    } catch (e) {
      reply.streaming = false;
      reply.text = '（发送失败：$e）';
      busy = false;
      thinking = false;
      notifyListeners();
    }
  }

  /// 停止当前生成
  Future<void> stop() async {
    try {
      await _client.request('prompt.cancel', {
        if (sessionId != null) 'session_id': sessionId,
      });
    } catch (_) {}
  }

  void _onEvent(GatewayEvent e) {
    switch (e.name) {
      case 'message.start':
        thinking = false;
        final entry = ChatEntry('assistant', '', streaming: true);
        entries.add(entry);
        busy = true;
      case 'message.delta':
        final t = _text(e.payload);
        if (t.isNotEmpty) _lastStreaming('assistant')?.text += t;
        thinking = false;
      case 'message.complete':
        _lastStreaming('assistant')?.streaming = false;
        busy = false;
        thinking = false;
      case 'thinking.delta':
        thinking = true;
      case 'tool.start':
        entries.add(ChatEntry('tool', '⚙ ${e.payload['name'] ?? 'tool'} 开始',
            meta: e.payload));
      case 'tool.progress':
        final last = _lastOfKind('tool');
        if (last != null && !last.text.endsWith('…')) last.text += ' …';
      case 'tool.complete':
        final last = _lastOfKind('tool');
        if (last != null) last.text += ' ✓';
      case 'sessions.changed':
        unawaited(refreshSessions());
      case 'session.title':
        final id = '${e.payload['session_id'] ?? e.payload['id'] ?? ''}';
        final t = _text(e.payload);
        for (final s in sessions) {
          if (s.id == id && t.isNotEmpty) s.title = t;
        }
      case 'approval.pending' || 'approval.received':
        entries.add(ChatEntry(
          'approval',
          '${e.payload['prompt'] ?? e.payload['question'] ?? e.payload['text'] ?? '批准一项操作？'}',
          meta: e.payload,
        ));
      case 'approval.cancelled':
        final last = _lastOfKind('approval');
        if (last != null && !last.done) {
          last.text += '（已取消）';
          last.done = true;
        }
      case 'status.update':
      case 'notice':
        final t = _text(e.payload);
        if (t.isNotEmpty) _add('system', t);
      case 'error':
        _add('system', '⚠ ${e.payload['error'] ?? e.payload['message'] ?? e.payload}');
      case 'connection.closed':
        statusText = '连接已断开';
        busy = false;
        _add('system', '连接已断开');
    }
    notifyListeners();
  }

  String _text(Map<String, dynamic> payload) =>
      (payload['delta'] ?? payload['text'] ?? payload['content'] ?? '')
          .toString();

  ChatEntry? _lastStreaming(String kind) {
    for (var i = entries.length - 1; i >= 0; i--) {
      final e = entries[i];
      if (e.kind == kind && e.streaming) return e;
    }
    return null;
  }

  ChatEntry? _lastOfKind(String kind) {
    for (var i = entries.length - 1; i >= 0; i--) {
      if (entries[i].kind == kind) return entries[i];
    }
    return null;
  }

  void _add(String kind, String text) => entries.add(ChatEntry(kind, text));

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_client.dispose());
    super.dispose();
  }
}
