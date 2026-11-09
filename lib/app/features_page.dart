//! 功能页：功能列表（底部导航「功能」tab 的内容）
//!
//! 功能清单来自注册表（feature_registry.dart），
//! 按当前平台能力过滤展示：不支持的隐藏，受限的标注说明。
import 'package:flutter/widgets.dart';

import '../core/logging/sentry_bridge.dart';
import '../design/tokens.dart';
import '../design/widgets/app_header.dart';
import '../design/widgets/app_scaffold.dart';
import 'feature_registry.dart';

/// 功能页：功能列表（底部导航「功能」tab 的内容）。
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 当前平台不支持的功能不展示；受限功能在副标题标注
    final features = kFeatures
        .where((f) => f.support != PlatformSupport.none)
        .toList(growable: false);

    return AppScaffold(
      header: const AppHeader(title: '功能'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              for (var i = 0; i < features.length; i++) ...[
                if (i > 0)
                  // 内缩分割线：从标题文字左缘起线，视觉更轻
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 40 + AppSpacing.md * 2),
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                _FeatureTile(feature: features[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 功能行：图标块 + 标题/副标题（受限功能在副标题标注）
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final FeatureEntry feature;

  @override
  Widget build(BuildContext context) {
    final bool limited = feature.support == PlatformSupport.limited;
    final String subtitle = limited
        ? '${feature.subtitle}（${feature.limitedNote ?? '当前平台功能受限'}）'
        : feature.subtitle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 操作埋点：功能入口点击（Sentry Logs，docs 见 SentryBridge.action）
        SentryBridge.action('open_feature', {'id': feature.id});
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (routeContext, _, __) => feature.builder(routeContext),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // 入口图标块：primary 淡底（AGENTS.md 视觉约定）
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(feature.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
