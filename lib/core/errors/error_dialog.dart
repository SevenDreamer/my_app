//! 错误详情弹窗：码 + 人话 + 建议 + 完整原文（可滚动可复制）——替代 toast 糊脸
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import 'app_error.dart';
import 'error_codes.dart';
import 'error_log.dart';

/// 弹出错误详情（默认同时落盘记录；从日志页回看时传 record: false）
Future<void> showErrorDialog(
  BuildContext context,
  AppError error, {
  bool record = true,
}) async {
  if (record) {
    await ErrorLog.record(error); // 先落盘（弹窗失败也不丢记录）
  }
  if (!context.mounted) return;

  await showShadDialog<void>(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text('${error.code} · ${ErrorCodes.categoryOf(error.code)}'
          '${error.context != null ? '（${error.context}）' : ''}'),
      description: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(error.message),
      ),
      actions: [
        ShadButton.outline(
          child: const Text('复制错误'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: error.fullText));
            ShadSonner.of(ctx).show(
              ShadToast(
                id: DateTime.now().microsecondsSinceEpoch,
                title: const Text('错误信息已复制'),
              ),
            );
          },
        ),
        ShadButton(
          child: const Text('关闭'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.hint != null) ...[
                Text('建议：${error.hint}',
                    style: Theme.of(ctx).textTheme.labelSmall),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (error.detail != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.neutral,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    error.detail!,
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
