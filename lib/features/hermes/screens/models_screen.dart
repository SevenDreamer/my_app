import 'package:flutter/material.dart';
import 'package:my_app/rust/hermes/api.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  List<ModelInfoFrb>? _models;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  void _loadModels() {
    try {
      final models = hermesGetModels();
      setState(() => _models = models);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('模型配置')),
      body: _models == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _models!.length,
              itemBuilder: (context, index) {
                final model = _models![index];
                final providerColor = _providerColor(model.provider);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: providerColor.withOpacity(0.2),
                      child: Text(
                        model.provider[0].toUpperCase(),
                        style: TextStyle(color: providerColor),
                      ),
                    ),
                    title: Text(model.name),
                    subtitle: Text(
                      '${model.provider} · ${_formatContext(model.contextLength)}',
                    ),
                    trailing: Text(
                      model.id,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'openai':
        return Colors.green;
      case 'anthropic':
        return Colors.orange;
      case 'openrouter':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatContext(int length) {
    if (length >= 1000) return '${length ~/ 1000}K';
    return '$length';
  }
}