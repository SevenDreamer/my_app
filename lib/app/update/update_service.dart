//! 更新检查（v1 提示型）：GitHub Releases latest → semver 对比 → 提示跳转
//!
//! 一切异常都静默返回 null——更新检查绝不打断使用
//!（无授权 / 网络失败 / iOS 平台 / 已忽略版本 / 非新版）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'github_auth_service.dart';

/// 一条可用的更新提示
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
  });

  /// 纯版本号（tag 剥掉 v 前缀，如 1.2.0）
  final String version;

  /// Release notes（截取展示由 UI 决定）
  final String notes;

  /// Release 页面地址
  final String url;
}

class UpdateService {
  UpdateService({GithubAuthService? auth, http.Client? client})
      : _auth = auth ?? GithubAuthService(),
        _client = client ?? http.Client();

  static const String _repo = 'SevenDreamer/my_app';
  static const String _kIgnoredVersionKey = 'update_ignored_version';

  final GithubAuthService _auth;
  final http.Client _client;

  /// 静默检查；无新版或任何异常返回 null
  Future<UpdateInfo?> check() async {
    // iOS 无 App Store 外的更新渠道（AGENTS.md 明确不支持）
    if (defaultTargetPlatform == TargetPlatform.iOS) return null;

    final token = await _auth.token;
    if (token == null) return null;

    try {
      final resp = await _client.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      // 401 = token 失效/被撤销 → 静默降级（设置页可重新授权）
      if (resp.statusCode != 200) return null;

      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      var version = (j['tag_name'] as String?) ?? '';
      if (version.startsWith('v')) version = version.substring(1);
      if (version.isEmpty) return null;

      final ignored = await ignoredVersion();
      if (ignored == version) return null;

      final current = await _currentVersion();
      if (!_isNewer(version, current)) return null;

      return UpdateInfo(
        version: version,
        notes: (j['body'] as String?) ?? '',
        url: (j['html_url'] as String?) ?? '',
      );
    } catch (_) {
      return null; // 网络问题一律静默
    }
  }

  /// 「忽略本版」：记下版本号，同版本不再提示（本机存储，非敏感数据）
  Future<void> ignoreVersion(String version) =>
      const FlutterSecureStorage().write(
        key: _kIgnoredVersionKey,
        value: version,
      );

  Future<String?> ignoredVersion() => const FlutterSecureStorage().read(
        key: _kIgnoredVersionKey,
      );

  Future<String> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version; // 不含 build number
  }

  /// 语义化版本比较：remote 是否比 current 更新
  bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] != c[i]) return r[i] > c[i];
    }
    return false; // 同版本不算新版
  }

  List<int> _parse(String version) {
    final parts = version.split('+').first.split('.');
    final nums = <int>[
      for (final p in parts) int.tryParse(p) ?? 0,
    ];
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums.sublist(0, 3);
  }
}
