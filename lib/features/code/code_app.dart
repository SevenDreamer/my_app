import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 代码助手子应用
class CodeApp extends StatelessWidget {
  const CodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代码助手'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: HeroUiCard(
          borderRadius: 24,
          showShadow: true,
          surfaceVariant: HeroUiSurfaceVariant.defaultVariant,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.code2,
                size: 64,
                color: Color(0xFF4ECDC4),
              ),
              const SizedBox(height: 16),
              const Text(
                '代码助手',
                style: HeroUiTypography.heading3,
              ),
              const SizedBox(height: 8),
              Text(
                'AI 代码生成与优化',
                style: HeroUiTypography.bodySm.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '功能开发中...',
                style: HeroUiTypography.bodyXs.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 24),
              HeroUiButton(
                label: '生成代码',
                onPressed: () {
                  // TODO: 实现代码生成功能
                },
                variant: HeroUiButtonVariant.primary,
                size: HeroUiButtonSize.lg,
                leading: const Icon(LucideIcons.sparkles, size: 18),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
        ),
      ),
    );
  }
}
