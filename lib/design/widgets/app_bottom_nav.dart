//! 底部导航栏（零 Material 的 NavigationBar 等价物）
//!
//! 白底 + 顶边框 + 图标/标签两态（选中 primary，未选 secondary）。
//! 只吃 tokens，不引 Material。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// 单个导航目的地
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;

  /// 选中态图标（缺省复用 [icon]）
  final IconData? selectedIcon;
  final String label;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDestinationSelected(i),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == selectedIndex
                              ? (destinations[i].selectedIcon ??
                                  destinations[i].icon)
                              : destinations[i].icon,
                          size: 20,
                          color: i == selectedIndex
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                        if (destinations[i].label.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            destinations[i].label,
                            style: AppTypography.labelSm.copyWith(
                              color: i == selectedIndex
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
