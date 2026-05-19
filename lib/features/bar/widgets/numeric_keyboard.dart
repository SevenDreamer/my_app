import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 数字键盘
class NumericKeyboard extends StatelessWidget {
  final VoidCallback? onBackspace;
  final VoidCallback? onPlus;
  final VoidCallback? onMinus;
  final VoidCallback? onAddAnother;
  final VoidCallback? onComplete;
  final ValueChanged<String>? onKeyTap;

  const NumericKeyboard({
    super.key,
    this.onBackspace,
    this.onPlus,
    this.onMinus,
    this.onAddAnother,
    this.onComplete,
    this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3', 'backspace']),
        _buildRow(['4', '5', '6', '+']),
        _buildRow(['7', '8', '9', '-']),
        _buildRow(['.', '0', '再记', '完成']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return IntrinsicHeight(
      child: Row(
        children: keys.map((key) => _buildKey(key)).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final isAction = ['backspace', '+', '-', '再记', '完成'].contains(key);
    return Expanded(
      child: InkWell(
        onTap: () => _handleKey(key),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: _buildKeyContent(key, isAction),
        ),
      ),
    );
  }

  Widget _buildKeyContent(String key, bool isAction) {
    if (key == 'backspace') {
      return Builder(
        builder: (context) => Icon(
          LucideIcons.delete,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    if (key == '完成') {
      return Builder(
        builder: (context) => Text(
          key,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (isAction) {
      return Builder(
        builder: (context) => Text(
          key,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return Text(key,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500));
  }

  void _handleKey(String key) {
    switch (key) {
      case 'backspace':
        onBackspace?.call();
        break;
      case '+':
        onPlus?.call();
        break;
      case '-':
        onMinus?.call();
        break;
      case '再记':
        onAddAnother?.call();
        break;
      case '完成':
        onComplete?.call();
        break;
      default:
        onKeyTap?.call(key);
    }
  }
}
