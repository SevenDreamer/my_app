import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'tag_selector_sheet.dart';
import 'numeric_keyboard.dart';

/// 记账输入面板
class RecordInputPanel extends StatefulWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?>? onTagSelected;

  const RecordInputPanel({
    super.key,
    required this.tags,
    this.selectedTag,
    this.onTagSelected,
  });

  @override
  State<RecordInputPanel> createState() => _RecordInputPanelState();
}

class _RecordInputPanelState extends State<RecordInputPanel> {
  String _expression = ''; // 存储完整表达式，如 "100+50-20"
  String _remark = '';

  // 判断最后一个字符是否是运算符
  bool _lastIsOperator() {
    if (_expression.isEmpty) return false;
    final last = _expression[_expression.length - 1];
    return last == '+' || last == '-';
  }

  // 获取当前正在输入的数字部分
  String _getCurrentNumber() {
    if (_expression.isEmpty) return '';
    if (_lastIsOperator()) return '';
    final parts = _expression.split(RegExp('[+-]'));
    return parts.isEmpty ? '' : parts.last;
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == '.') {
        final currentNum = _getCurrentNumber();
        if (currentNum.contains('.')) return;
        if (currentNum.isEmpty) _expression += '0';
      }
      _expression += key;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    });
  }

  void _onPlus() {
    setState(() {
      // 如果表达式为空或最后是运算符，不允许添加
      if (_expression.isEmpty || _lastIsOperator()) return;
      _expression += '+';
    });
  }

  void _onMinus() {
    setState(() {
      if (_expression.isEmpty || _lastIsOperator()) return;
      _expression += '-';
    });
  }

  // 计算表达式的结果
  double _calculate() {
    if (_expression.isEmpty) return 0;
    if (_lastIsOperator()) {
      // 如果最后是运算符，去掉它再计算
      _expression = _expression.substring(0, _expression.length - 1);
    }

    // 解析表达式并计算
    final parts = _expression.split(RegExp('([+-])'));
    final operators = _expression.replaceAll(RegExp('[0-9.]'), '').split('');

    if (parts.isEmpty) return 0;

    double result = double.tryParse(parts[0]) ?? 0;

    for (int i = 1; i < parts.length && i <= operators.length; i++) {
      final num = double.tryParse(parts[i]) ?? 0;
      if (operators[i - 1] == '+') {
        result += num;
      } else if (operators[i - 1] == '-') {
        result -= num;
      }
    }

    return result;
  }

  void _onComplete() {
    final result = _calculate();
    // TODO: 保存记录
    Navigator.pop(context);
  }

  void _onAddAnother() {
    final result = _calculate();
    setState(() {
      _expression = result.toString();
      if (_expression.endsWith('.0')) {
        _expression = _expression.substring(0, _expression.length - 2);
      }
      _remark = '';
    });
    // TODO: 保存当前记录，继续添加下一笔
  }

  void _showTagSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => TagSelectorSheet(
        tags: widget.tags,
        selectedTag: widget.selectedTag,
        onTagSelected: (tag) {
          widget.onTagSelected?.call(tag);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Card(
          margin: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputRow(),
              _buildTagRow(),
              const Divider(height: 8),
              NumericKeyboard(
                onKeyTap: _onKeyTap,
                onBackspace: _onBackspace,
                onPlus: _onPlus,
                onMinus: _onMinus,
                onAddAnother: _onAddAnother,
                onComplete: _onComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.camera, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '备注',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) => _remark = value,
            ),
          ),
          Text(
            '¥${_expression.isEmpty ? '0' : _expression}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTagRow() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.tags.length,
              itemBuilder: (context, index) {
                final tag = widget.tags[index];
                final isSelected = widget.selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (_) => widget.onTagSelected?.call(isSelected ? null : tag),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
          _buildTagButton(),
        ],
      ),
    );
  }

  Widget _buildTagButton() {
    return InkWell(
      onTap: _showTagSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.tag, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '标签',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}