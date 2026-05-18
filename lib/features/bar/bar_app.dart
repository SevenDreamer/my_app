import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 酒吧系统子应用
class BarApp extends StatelessWidget {
  const BarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('酒吧系统'),
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
                LucideIcons.wine,
                size: 64,
                color: Color(0xFFE8AA42),
              ),
              const SizedBox(height: 16),
              Text(
                '酒吧系统',
                style: HeroUiTypography.heading3,
              ),
              const SizedBox(height: 8),
              Text(
                '酒吧点单与管理',
                style: HeroUiTypography.bodySm.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '功能开发中...',
                style: HeroUiTypography.bodyXs.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
        ),
      ),
    );
  }
}
