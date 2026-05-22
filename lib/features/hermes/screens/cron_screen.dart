import 'package:flutter/material.dart';
import 'package:my_app/rust/hermes/api.dart';

class CronScreen extends StatefulWidget {
  const CronScreen({super.key});

  @override
  State<CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen> {
  List<TaskInfoFrb>? _tasks;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() => _isLoading = true);
    try {
      final tasks = hermesGetTasks();
      setState(() => _tasks = tasks);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTask() async {
    final nameController = TextEditingController();
    final cronController = TextEditingController(text: '0 * * * *');
    final cmdController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建定时任务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cronController,
                decoration: const InputDecoration(
                  labelText: 'Cron 表达式',
                  border: OutlineInputBorder(),
                  hintText: '0 * * * *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cmdController,
                decoration: const InputDecoration(
                  labelText: '命令',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
      hermesCreateTask(
        name: nameController.text,
        cronExpression: cronController.text,
        command: cmdController.text,
      );
      _loadTasks();
    }
  }

  void _toggleTask(TaskInfoFrb task) {
    if (task.enabled) {
      hermesDisableTask(id: task.id);
    } else {
      hermesEnableTask(id: task.id);
    }
    _loadTasks();
  }

  void _executeTask(String id) {
    try {
      final output = hermesExecuteTask(id: id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '执行完成: ${output.substring(0, output.length.clamp(0, 100))}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('执行失败: $e')),
      );
    }
    _loadTasks();
  }

  void _deleteTask(String id) {
    hermesDeleteTask(id: id);
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时任务'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks == null || _tasks!.isEmpty) {
      return const Center(child: Text('没有定时任务，点击 + 创建'));
    }

    return ListView.builder(
      itemCount: _tasks!.length,
      itemBuilder: (context, index) {
        final task = _tasks![index];
        return ListTile(
          leading: Switch(
            value: task.enabled,
            onChanged: (_) => _toggleTask(task),
          ),
          title: Text(task.name),
          subtitle: Text(task.cronExpression),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _executeTask(task.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteTask(task.id),
              ),
            ],
          ),
        );
      },
    );
  }
}
