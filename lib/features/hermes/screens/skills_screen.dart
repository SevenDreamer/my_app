import 'package:flutter/material.dart';
import 'package:my_app/rust/hermes/api.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<SkillInfoFrb>? _skills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  void _loadSkills() {
    setState(() => _isLoading = true);
    try {
      final skills = hermesGetSkills();
      setState(() => _skills = skills);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createSkill() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String triggerType = 'keyword';
    final triggerController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建技能'),
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
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: triggerType,
                  decoration: const InputDecoration(
                    labelText: '触发类型',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'keyword', child: Text('关键词')),
                    DropdownMenuItem(value: 'pattern', child: Text('正则')),
                    DropdownMenuItem(value: 'auto', child: Text('自动')),
                    DropdownMenuItem(value: 'manual', child: Text('手动')),
                  ],
                  onChanged: (v) => setState(() => triggerType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: triggerController,
                  decoration: const InputDecoration(
                    labelText: '触发值',
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
      ),
    );

    if (result ?? false) {
      hermesCreateSkill(
        name: nameController.text,
        description: descController.text,
        triggerType: triggerType,
        triggerValue: triggerController.text,
      );
      _loadSkills();
    }
  }

  Future<void> _deleteSkill(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除技能'),
        content: const Text('确定要删除这个技能吗？'),
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
      hermesDeleteSkill(id: id);
      _loadSkills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能库'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSkills),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSkill,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_skills == null || _skills!.isEmpty) {
      return const Center(child: Text('没有技能，点击 + 创建'));
    }

    return ListView.builder(
      itemCount: _skills!.length,
      itemBuilder: (context, index) {
        final skill = _skills![index];
        return ListTile(
          title: Text(skill.name),
          subtitle: Text('${skill.triggerType} · 使用 ${skill.usageCount} 次'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteSkill(skill.id),
          ),
        );
      },
    );
  }
}
