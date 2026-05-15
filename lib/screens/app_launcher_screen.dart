import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../models/sub_app.dart';
import '../apps/chat_app.dart';
import '../apps/image_app.dart';
import '../apps/code_app.dart';
import '../apps/database_manager_app.dart';

/// 子应用启动器（主界面）
class AppLauncherScreen extends StatelessWidget {
  AppLauncherScreen({super.key});

  // 子应用列表
  final List<SubApp> _apps = [
    SubApp(
      id: 'chat',
      name: '聊天助手',
      description: 'AI 智能对话助手',
      icon: LucideIcons.messageCircle,
      color: const Color(0xFF7C5CFC),
      builder: ChatApp.new,
    ),
    SubApp(
      id: 'image',
      name: '图片处理',
      description: 'AI 图片编辑工具',
      icon: LucideIcons.image,
      color: const Color(0xFF57A6FF),
      builder: ImageApp.new,
    ),
    SubApp(
      id: 'code',
      name: '代码助手',
      description: 'AI 代码生成与优化',
      icon: LucideIcons.code2,
      color: const Color(0xFF4ECDC4),
      builder: CodeApp.new,
    ),
    SubApp(
      id: 'database',
      name: '数据库管理',
      description: '数据库浏览与管理工具',
      icon: LucideIcons.database,
      color: const Color(0xFFFF6B6B),
      builder: DatabaseManagerApp.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes Agent'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              // TODO: 打开设置
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎语
            const Text(
              '欢迎使用 Hermes Agent',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择要使用的工具',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // 子应用列表
            Expanded(
              child: ListView.separated(
                itemCount: _apps.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  return _AppCard(app: app);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 子应用卡片（使用 HeroUI 组件）
class _AppCard extends StatelessWidget {
  final SubApp app;

  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return HeroUiCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => app.builder()),
        );
      },
      borderRadius: 16,
      showShadow: false,
      borderColor: Colors.transparent,
      body: Row(
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: app.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              app.icon,
              size: 28,
              color: app.color,
            ),
          ),
          const SizedBox(width: 20),

          // 文字信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 应用名称
                Text(
                  app.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 应用描述
                Text(
                  app.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 打开箭头
          Icon(
            LucideIcons.arrowRight,
            size: 20,
            color: app.color,
          ),
        ],
      ),
    );
  }
}
