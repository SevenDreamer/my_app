//! 扫码下载（桌面端）：生成 Android 安装包的一次性签名下载 URL 二维码
//!
//! 私有仓库的 Release 资产不能匿名下载（实测浏览器直开 404），
//! 因此用 Device Flow token 走 GitHub 资产 API，取 302 的 Azure 签名
//! Location（实测有效期 1 小时）——二维码里放这个短时 URL。
//! 链接过期后重新打开弹窗即重新生成（token 由 validToken 自动续期）。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_codes.dart';
import '../../core/errors/error_dialog.dart';
import 'github_auth_service.dart';
import 'update_service.dart';

/// 取最新 Release 里 Android 资产的一次性签名下载 URL。
/// 返回 (url, err)：成功时 err 为 null；失败时 url 为 null 且 err 是具体原因。
Future<(String?, AppError?)> fetchAndroidSignedUrl() async {
  final auth = GithubAuthService();
  final token = await auth.validToken();
  if (token == null) {
    return (
      null,
      const AppError(
        code: ErrorCodes.authNone,
        message: '尚未授权或授权已过期',
        hint: '请在「更新检查」里授权 GitHub（可点重新授权）',
      ),
    );
  }

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  final client = http.Client();
  try {
    // 1) 按更新通道找 Release（dev 通道含 prerelease，桌面扫码与手机更新同步）
    final ch = await UpdateService().channel();
    final resp = await client.get(
      Uri.parse(
          'https://api.github.com/repos/SevenDreamer/my_app/releases?per_page=10'),
      headers: headers,
    );
    if (resp.statusCode == 401) {
      return (null, const AppError(code: ErrorCodes.authExpired,
          message: '授权已过期', hint: '请在「更新检查」里重新授权'));
    }
    if (resp.statusCode != 200) {
      return (null, AppError(code: ErrorCodes.updateRelease,
          message: '获取 Release 信息失败（HTTP ${resp.statusCode}）',
          detail: 'HTTP ${resp.statusCode}'));
    }
    final releases = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    final candidates = releases.where((r) {
      final release = r as Map<String, dynamic>;
      if (release['draft'] == true) return false;
      if (ch == 'stable' && release['prerelease'] == true) return false;
      return true;
    }).toList();
    if (candidates.isEmpty) {
      return (null, const AppError(
        code: ErrorCodes.updateNoApk,
        message: '当前通道还没有可用的 Release',
      ));
    }
    final j = candidates.first as Map<String, dynamic>;
    final assets = (j['assets'] as List?) ?? const [];
    final asset = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').endsWith('.apk'),
      orElse: () => null,
    );
    if (asset == null) {
      return (
        null,
        const AppError(
          code: ErrorCodes.updateNoApk,
          message: '最新 Release 还没有 Android 安装包',
        ),
      );
    }
    final id = asset['id'];

    // 2) 请求资产下载端点（不跟随跳转）→ 302 的 Location 即签名 URL
    final req = http.Request(
      'GET',
      Uri.parse(
          'https://api.github.com/repos/SevenDreamer/my_app/releases/assets/$id'),
    )
      ..followRedirects = false
      ..headers.addAll({...headers, 'Accept': 'application/octet-stream'});
    final streamed = await client.send(req);
    final location = streamed.headers['location'];
    if (location == null) {
      return (null, const AppError(code: ErrorCodes.updateSignedUrl,
          message: '获取下载链接失败（未拿到签名地址）'));
    }
    return (location, null);
  } catch (e) {
    return (null, AppError.from(e, context: '扫码下载'));
  } finally {
    client.close();
  }
}

/// 弹出扫码下载对话框（已授权状态下调用）
Future<void> showDownloadQrDialog(BuildContext context) async {
  final (url, err) = await fetchAndroidSignedUrl();
  if (!context.mounted) return;
  if (url == null) {
    await showErrorDialog(context, err ??
        const AppError(code: ErrorCodes.unknown, message: '获取下载链接失败'));
    return;
  }

  await showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog(
      title: const Text('扫码下载 Android 版'),
      description: const Text(
          '用手机相机或微信扫码，浏览器打开后下载安装。\n链接 1 小时内有效，过期重新打开本弹窗即可。'),
      actions: [
        ShadButton(
          child: const Text('关闭'),
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
