import 'package:flutter/material.dart';
import 'package:my_app/features/hermes/screens/chat_screen.dart';
import 'package:my_app/rust/hermes/api.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionInfo>? _sessions;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = hermesGetSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createSession() async {
    final titleController = TextEditingController(text: '新会话');
    final modelController = TextEditingController(text: 'gpt-4');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建会话'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result ?? false) {
      try {
        hermesCreateSession(
          title: titleController.text,
          model: modelController.text,
        );
        await _loadSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        hermesDeleteSession(id: id);
        await _loadSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_sessions == null || _sessions!.isEmpty) {
      return const Center(child: Text('没有会话，点击 + 创建'));
    }

    return ListView.builder(
      itemCount: _sessions!.length,
      itemBuilder: (context, index) {
        final session = _sessions![index];
        return ListTile(
          title: Text(session.title),
          subtitle: Text('${session.model} · ${session.messageCount} 条消息'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteSession(session.id),
          ),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => ChatScreen(sessionId: session.id),
            ),
          ),
        );
      },
    );
  }
}
