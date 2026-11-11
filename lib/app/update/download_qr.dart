//! 扫码下载（桌面端）：生成 Android 安装包下载 URL 二维码
//!
//! R2 公开桶的安装包 URL 匿名长期有效——不再走 Device Flow token
//! 换 GitHub 签名 URL（旧方案链接 1 小时过期）。二维码里放 manifest
//! 解析出的下载地址，手机扫码浏览器打开直接下载。
import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../design/widgets/app_button.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_codes.dart';
import '../../core/errors/error_dialog.dart';
import 'update_service.dart';

/// 取最新版本 Android 安装包的下载 URL（R2 manifest，匿名）。
/// [abi] 指定架构（D2 分架构选包）：精确匹配 → universal → 首个，
/// 兜底逻辑在 [UpdateInfo.resolveApk]。
/// 返回 (url, err)：成功时 err 为 null；失败时 url 为 null 且 err 是具体原因。
Future<(String?, AppError?)> fetchAndroidDownloadUrl({String? abi}) async {
  final info = await UpdateService().latest();
  if (info == null) {
    return (
      null,
      const AppError(
        code: ErrorCodes.updateNoApk,
        message: '暂时获取不到下载信息',
        hint: '检查网络后重试',
      )
    );
  }
  final url = info.resolveApk(abi ?? 'arm64-v8a');
  if (url == null) {
    return (
      null,
      const AppError(
        code: ErrorCodes.updateNoApk,
        message: '最新版本还没有 Android 安装包',
      )
    );
  }
  return (url, null);
}

/// 弹出扫码下载对话框（无需授权，安装包 URL 匿名公开）
Future<void> showDownloadQrDialog(BuildContext context) async {
  final (url, err) = await fetchAndroidDownloadUrl();
  if (!context.mounted) return;
  if (url == null) {
    await showErrorDialog(context,
        err ?? const AppError(code: ErrorCodes.unknown, message: '获取下载链接失败'));
    return;
  }

  await showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog(
      title: const Text('扫码下载 Android 版'),
      description: const Text('用手机相机或微信扫码，浏览器打开后下载安装。\n链接长期有效，可随时扫码。'),
      actions: [
        AppButton(
          label: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: QrImageView(
            data: url,
            size: 220,
            backgroundColor: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    ),
  );
}
