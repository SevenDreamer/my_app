//! 更新提示对话框 + Android 内置下载安装（D1：跳过浏览器）
//!
//! Android：点「下载并安装」→ 进度框（0..1）→ 下载完成自动调起系统安装器；
//! 桌面：「前往下载」打开下载页。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/tokens.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_codes.dart';
import '../../core/errors/error_dialog.dart';
import 'apk_installer.dart';
import 'update_service.dart';

/// 有新版时弹出提示；[info] 为 null 时不展示
Future<void> showUpdateNotice(BuildContext context, UpdateInfo info) async {
  final notes = _excerpt(info.notes, maxLines: 8);
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  await showShadDialog<void>(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text('发现新版本 v${info.version}'),
      description: Text(notes.isEmpty ? '本次更新包含改进与修复。' : notes),
      actions: [
        ShadButton.outline(
          child: const Text('忽略本版'),
          onPressed: () {
            UpdateService().ignoreVersion(info.version);
            Navigator.of(ctx).pop();
          },
        ),
        ShadButton(
          child: Text(isAndroid ? '下载并安装' : '前往下载'),
          onPressed: () async {
            Navigator.of(ctx).pop();
            if (isAndroid) {
              await _downloadAndInstall(ctx, info);
            } else {
              final uri = Uri.tryParse(info.url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ],
    ),
  );
}

/// Android：进度框 + 按 ABI 下载 + 调起系统安装器
Future<void> _downloadAndInstall(BuildContext ctx, UpdateInfo info) async {
  if (!ctx.mounted) return;

  final progress = ValueNotifier<double>(0);
  BuildContext? progressDlgCtx;
  // ignore: unawaited_futures
  showShadDialog<void>(
    context: ctx,
    builder: (dctx) {
      progressDlgCtx = dctx;
      return ShadDialog.alert(
        title: const Text('正在下载更新'),
        actions: [
          ShadButton.outline(
            child: const Text('后台下载'),
            onPressed: () => Navigator.of(dctx).pop(),
          ),
        ],
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadProgress(value: p),
                const SizedBox(height: AppSpacing.sm),
                Text('${(p * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      );
    },
  );

  // 按设备 ABI 选架构包（D2）；下载 URL 来自 R2 manifest（匿名公开）
  final url = info.resolveApk(await deviceAbi());

  // 关进度框（下载/安装完成或失败）
  void closeProgress() {
    if (progressDlgCtx?.mounted == true) {
      Navigator.of(progressDlgCtx!).pop();
    }
    progressDlgCtx = null;
  }

  if (url == null) {
    closeProgress();
    progress.dispose();
    if (ctx.mounted) {
      await showErrorDialog(
        ctx,
        const AppError(
          code: ErrorCodes.updateNoApk,
          message: '最新版本还没有 Android 安装包',
        ),
      );
    }
    return;
  }

  final installErr =
      await downloadAndInstallApk(url, onProgress: (p) => progress.value = p);
  closeProgress();
  progress.dispose();
  if (installErr != null && ctx.mounted) {
    await showErrorDialog(ctx, installErr);
  }
}

/// Release notes 摘要：去首尾空白、限行数、防大段刷屏
String _excerpt(String body, {required int maxLines}) {
  final lines = body
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length <= maxLines) return lines.join('\n');
  return '${lines.take(maxLines).join('\n')}\n……';
}
