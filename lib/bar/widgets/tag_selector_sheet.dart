import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 标签选择弹窗
class TagSelectorSheet extends StatefulWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?>? onTagSelected;

  const TagSelectorSheet({
    super.key,
    required this.tags,
    this.selectedTag,
    this.onTagSelected,
  });

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  String _searchQuery = '';
  String? _localSelectedTag;
  bool _isSearching = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _localSelectedTag = widget.selectedTag;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredTags {
    if (_searchQuery.isEmpty) return widget.tags;
    return widget.tags.where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                HeroUiButton(
                  variant: HeroUiButtonVariant.ghost,
                  size: HeroUiButtonSize.sm,
                  leading: const Icon(LucideIcons.search, size: 18),
                  label: '',
                  onPressed: () => setState(() => _isSearching = true),
                ),
                const Expanded(
                  child: Text('标签列表', style: HeroUiTypography.bodySmMedium, textAlign: TextAlign.center),
                ),
                HeroUiButton(
                  variant: HeroUiButtonVariant.ghost,
                  size: HeroUiButtonSize.sm,
                  leading: const Icon(LucideIcons.plus, size: 18),
                  label: '',
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // 搜索框
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HeroUiSearchField(
                placeholder: '输入标签关键词',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          if (_isSearching) const SizedBox(height: 16),
          // 标签流式布局
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _filteredTags.map((tag) {
                final isSelected = _localSelectedTag == tag;
                return HeroUiChip(
                  variant: isSelected ? HeroUiChipVariant.primary : HeroUiChipVariant.tertiary,
                  isSelected: isSelected,
                  startIcon: const Icon(LucideIcons.tag, size: 14),
                  label: tag,
                  onTap: () => setState(() => _localSelectedTag = isSelected ? null : tag),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // 确认按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: HeroUiButton(
              label: '确认',
              variant: HeroUiButtonVariant.primary,
              size: HeroUiButtonSize.lg,
              expand: true,
              onPressed: () => widget.onTagSelected?.call(_localSelectedTag),
            ),
          ),
        ],
      ),
    );
  }
}