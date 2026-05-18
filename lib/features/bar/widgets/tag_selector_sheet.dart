import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:lucide_flutter/lucide_flutter.dart';

/// 标签选择弹窗（使用 shadcn_flutter）
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
                shadcn.GhostButton(
                  onPressed: () => setState(() => _isSearching = true),
                  child: const Icon(LucideIcons.search, size: 18),
                ),
                const Expanded(
                  child: Text('标签列表', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                shadcn.GhostButton(
                  onPressed: () {},
                  child: const Icon(LucideIcons.plus, size: 18),
                ),
              ],
            ),
          ),
          // 搜索框
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '输入标签关键词',
                  border: InputBorder.none,
                  isDense: true,
                ),
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
                return GestureDetector(
                  onTap: () => setState(() => _localSelectedTag = isSelected ? null : tag),
                  child: isSelected
                      ? shadcn.PrimaryBadge(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.tag, size: 14),
                              const SizedBox(width: 4),
                              Text(tag),
                            ],
                          ),
                        )
                      : shadcn.OutlineBadge(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.tag, size: 14),
                              const SizedBox(width: 4),
                              Text(tag),
                            ],
                          ),
                        ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // 确认按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: shadcn.PrimaryButton(
              onPressed: () => widget.onTagSelected?.call(_localSelectedTag),
              child: const Text('确认'),
            ),
          ),
        ],
      ),
    );
  }
}