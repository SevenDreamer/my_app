import 'package:flutter/material.dart';
import 'package:my_app/rust/hermes/api.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId;

  const ChatScreen({required this.sessionId, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageInfo> _messages = [];
  bool _isLoading = false;
  String _streamingText = '';
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = hermesGetMessages(sessionId: widget.sessionId);
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    _controller.clear();
    setState(() {
      _isLoading = true;
      _streamingText = '';
      _isStreaming = true;
    });

    try {
      // Use streaming API
      final stream = hermesStreamMessage(
        sessionId: widget.sessionId,
        message: text,
      );

      await for (final chunk in stream) {
        if (chunk == '[START]' || chunk == '[DONE]') continue;
        if (chunk.startsWith('[ERROR]')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(chunk)),
          );
          break;
        }
        setState(() {
          _streamingText += chunk;
        });
        _scrollToBottom();
      }

      setState(() {
        _isStreaming = false;
        _isLoading = false;
      });

      // Reload messages to get the final persisted version
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
      setState(() {
        _isStreaming = false;
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hermes')),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isStreaming) _buildStreamingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && !_isStreaming) {
      return const Center(child: Text('开始对话吧'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isStreaming && index == _messages.length) {
          return _MessageBubble(
            message: MessageInfo(
              id: '',
              role: 'assistant',
              content: _streamingText,
              timestamp: '',
            ),
          );
        }
        return _MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildStreamingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          const Text('正在生成...', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading || _isStreaming ? null : _sendMessage,
              icon: _isLoading || _isStreaming
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageInfo message;

  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content, style: TextStyle(color: fgColor)),
      ),
    );
  }
}
