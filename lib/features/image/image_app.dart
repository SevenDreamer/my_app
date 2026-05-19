import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 图片处理子应用
class ImageApp extends StatelessWidget {
  const ImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片处理'),
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
                LucideIcons.image,
                size: 64,
                color: Color(0xFF57A6FF),
              ),
              const SizedBox(height: 16),
              const Text(
                '图片处理',
                style: HeroUiTypography.heading3,
              ),
              const SizedBox(height: 8),
              Text(
                'AI 图片编辑工具',
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
                label: '选择图片',
                onPressed: () {
                  // TODO: 实现图片处理功能
                },
                variant: HeroUiButtonVariant.primary,
                size: HeroUiButtonSize.lg,
                leading: const Icon(LucideIcons.upload, size: 18),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
        ),
      ),
    );
  }
}
