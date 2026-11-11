//! 日志查看弹窗（调试用）：AppLogger 的 ring buffer 全量展示
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/logging/app_logger.dart';
import '../../design/widgets/app_button.dart';

Future<void> showLogViewerDialog(BuildContext context) async {
  await showShadDialog<void>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: const Text('运行日志（最近 200 条）'),
      actions: [
        AppButton(variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(ctx).pop(),
          label: '关闭',
        ),
      ],
      child: SizedBox(
        width: 420,
        height: 360,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: AppLogger.instance.entries,
          builder: (_, lines, __) => lines.isEmpty
              ? const Center(child: Text('暂无日志'))
              : ListView.builder(
                  reverse: true, // 最新在下——滚动即最新
                  itemCount: lines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      lines[lines.length - 1 - i],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}
