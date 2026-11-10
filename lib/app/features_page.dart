//! 功能页（首页）：功能列表（底部导航「功能」tab 的内容）。
//!
//! 设计语言：列表模式 + 产品轴分组（VISION 分层：平台/能力/个性/工具）；
//! 响应式（DESIGN.md · Responsive）：compact 单列列表 / 宽屏卡片网格。
//! 功能清单来自注册表，按平台能力过滤：不支持的隐藏，受限的标注说明。
import 'package:flutter/widgets.dart';

import '../core/logging/sentry_bridge.dart';
import '../design/tokens.dart';
import '../design/widgets/app_header.dart';
import '../design/widgets/app_layout.dart';
import '../design/widgets/app_scaffold.dart';
import 'feature_registry.dart';

/// 分组顺序（产品轴：平台 → 能力 → 个性 → 工具）
const _groupOrder = ['平台', '能力', '个性', '工具'];

const _groupNotes = {
  '平台': '系统与 agent · 中枢主战场',
  '能力': '手机能力外借',
  '个性': '表达与玩具',
  '工具': '杂务',
};

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final features = kFeatures
        .where((f) => f.support != PlatformSupport.none)
        .toList(growable: false);
    // 按产品轴分组（保持注册表顺序）
    final grouped = <String, List<FeatureEntry>>{};
    for (final f in features) {
      grouped.putIfAbsent(f.group, () => []).add(f);
    }
    final layout = AppLayout.of(context);

    return AppScaffold(
      header: const AppHeader(title: '功能'),
      body: AppContentWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final g in _groupOrder)
                if (grouped[g]?.isNotEmpty ?? false) ...[
                  _GroupHeader(title: g, note: _groupNotes[g]),
                  const SizedBox(height: AppSpacing.sm),
                  if (layout.isCompact)
                    _FeatureList(items: grouped[g]!)
                  else
                    _FeatureGrid(items: grouped[g]!),
                  const SizedBox(height: AppSpacing.xl),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 组标题（字阶公式：组标题用 bodyMd 加重，说明走 label-sm）
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
        if (note != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(note!, style: AppTypography.labelSm),
        ],
      ],
    );
  }
}

/// compact：单列卡片列表（内缩分割线）
class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.items});

  final List<FeatureEntry> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 40 + AppSpacing.md * 2),
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            _FeatureTile(feature: items[i]),
          ],
        ],
      ),
    );
  }
}

/// 宽屏：卡片网格（同元素重组，不发明新样式——card 规格容器 + 既有 tile 内容）
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});

  final List<FeatureEntry> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final f in items)
          SizedBox(
            width: 320,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: _FeatureTile(feature: f),
            ),
          ),
      ],
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
                    style: AppTypography.labelSm,
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
