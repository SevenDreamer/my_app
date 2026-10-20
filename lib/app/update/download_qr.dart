//! 扫码下载（桌面端）：生成 Android 安装包的一次性签名下载 URL 二维码
//!
//! 私有仓库的 Release 资产不能匿名下载（实测浏览器直开 404），
//! 因此用 Device Flow token 走 GitHub 资产 API，取 302 的 Azure 签名
//! Location（实测有效期 1 小时）——二维码里放这个短时 URL。
//! 链接过期后重新打开弹窗即重新生成。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'github_auth_service.dart';

/// 取最新 Release 里 Android 资产的一次性签名下载 URL
///（无授权 / 无资产 / 网络问题均返回 null）
Future<String?> fetchAndroidSignedUrl() async {
  final token = await GithubAuthService().token;
  if (token == null) return null;

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  final client = http.Client();
  try {
    // 1) 找最新 Release 的 APK 资产 id
    final resp = await client.get(
      Uri.parse('https://api.github.com/repos/SevenDreamer/my_app/releases/latest'),
      headers: headers,
    );
    if (resp.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final assets = (j['assets'] as List?) ?? const [];
    final asset = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').endsWith('.apk'),
      orElse: () => null,
    );
    if (asset == null) return null;
    final id = asset['id'];

    // 2) 请求资产下载端点（不跟随跳转）→ 302 的 Location 即签名 URL
    final req = http.Request(
      'GET',
      Uri.parse('https://api.github.com/repos/SevenDreamer/my_app/releases/assets/$id'),
    )
      ..followRedirects = false
      ..headers.addAll({
        ...headers,
        'Accept': 'application/octet-stream',
      });
    final streamed = await client.send(req);
    return streamed.headers['location'];
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// 弹出扫码下载对话框（已授权状态下调用）
Future<void> showDownloadQrDialog(BuildContext context) async {
  final url = await fetchAndroidSignedUrl();
  if (!context.mounted) return;
  if (url == null) {
    ShadSonner.of(context).show(
      ShadToast(
        id: DateTime.now().microsecondsSinceEpoch,
        title: const Text('获取下载链接失败：请先在「更新检查」授权 GitHub'),
      ),
    );
    return;
  }

  await showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog(
      title: const Text('扫码下载 Android 版'),
      description: const Text('用手机相机或微信扫码，浏览器打开后下载安装。\n链接 1 小时内有效，过期重新打开本弹窗即可。'),
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
