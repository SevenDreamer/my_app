import 'package:flutter/material.dart';
import '../widgets/record_input_panel.dart';
import '../services/tag_service.dart';

/// 新增资产记录页面
class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key});

  @override
  State<AddRecordPage> createState() => AddRecordPageState();
}

class AddRecordPageState extends State<AddRecordPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  String? _selectedTag;

  List<RecordTag> _expenseTags = [];
  List<RecordTag> _incomeTags = [];
  bool _isLoading = true;

  List<String> get currentTags {
    final tags = _selectedIndex == 0 ? _expenseTags : _incomeTags;
    return tags.map((t) => t.name).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation!.addListener(_onTabAnimation);
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final expenseTags = await TagService.getTags(type: 'expense');
      final incomeTags = await TagService.getTags(type: 'income');
      if (mounted) {
        setState(() {
          _expenseTags = expenseTags;
          _incomeTags = incomeTags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTabAnimation() {
    final value = _tabController.animation!.value;
    if (value.round() != _selectedIndex) {
      setState(() {
        _selectedIndex = value.round();
        _selectedTag = null;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabAnimation);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('支出')),
            ButtonSegment(value: 1, label: Text('收入')),
          ],
          selected: {_selectedIndex},
          onSelectionChanged: _onSegmentChanged,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RecordInputPanel(
              tags: currentTags,
              selectedTag: _selectedTag,
              onTagSelected: _onTagSelected,
            ),
    );
  }

  void _onSegmentChanged(Set<int> selection) {
    setState(() {
      _selectedIndex = selection.first;
      _selectedTag = null;
    });
    _tabController.animateTo(selection.first);
  }

  void _onTagSelected(String? tag) {
    setState(() => _selectedTag = tag);
  }
}