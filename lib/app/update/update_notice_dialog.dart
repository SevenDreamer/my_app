//! 更新提示对话框（shadcn 风）：新版版本号 + Release notes 摘要 + 动作
//!
//! 「忽略本版」把版本号记入本机，同版本不再打扰；
//! 「前往下载」打开 GitHub Release 页面（v1 统一提示型，不做静默安装）。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'download_qr.dart';
import 'update_service.dart';

/// 有新版时弹出提示；[info] 为 null 时不展示
Future<void> showUpdateNotice(BuildContext context, UpdateInfo info) {
  final notes = _excerpt(info.notes, maxLines: 8);
  return showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog.alert(
      title: Text('发现新版本 v${info.version}'),
      description: Text(notes.isEmpty ? '本次更新包含改进与修复。' : notes),
      actions: [
        ShadButton.outline(
          child: const Text('忽略本版'),
          onPressed: () {
            UpdateService().ignoreVersion(info.version);
            Navigator.of(context).pop();
          },
        ),
        ShadButton(
          child: const Text('前往下载'),
          onPressed: () async {
            final uri = Uri.tryParse(info.url);
            if (uri != null) {
              if (defaultTargetPlatform == TargetPlatform.android) {
                // Android：直接下载签名 apk（Release 页面在手机浏览器是登录墙）
                final (signedUrl, _) = await fetchAndroidSignedUrl();
                final target = signedUrl != null ? Uri.tryParse(signedUrl) : uri;
                if (target != null) {
                  launchUrl(target, mode: LaunchMode.externalApplication);
                }
              } else {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
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
