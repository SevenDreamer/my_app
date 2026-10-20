//! 更新检查（v1 提示型）：GitHub Releases latest → semver 对比 → 提示跳转
//!
//! 一切异常都静默返回 null——更新检查绝不打断使用
//!（无授权 / 网络失败 / iOS 平台 / 已忽略版本 / 非新版）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_log.dart';
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
  static const String _kChannelKey = 'update_channel';

  /// 更新通道：'stable'（默认，只看正式版）/ 'dev'（含预发布版）
  Future<String> channel() async {
    return await const FlutterSecureStorage().read(key: _kChannelKey) ??
        'stable';
  }

  Future<void> setChannel(String value) =>
      const FlutterSecureStorage().write(key: _kChannelKey, value: value);

  final GithubAuthService _auth;
  final http.Client _client;

  /// 静默检查；无新版或任何异常返回 null
  Future<UpdateInfo?> check() async {
    // iOS 无 App Store 外的更新渠道（AGENTS.md 明确不支持）
    if (defaultTargetPlatform == TargetPlatform.iOS) return null;

    final token = await _auth.validToken();
    if (token == null) return null;

    try {
      // 按通道取 Release 列表（dev 通道含 prerelease；stable 过滤掉 prerelease）
      final ch = await channel();
      final resp = await _client.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases?per_page=10'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      // 401 = token 失效/被撤销 → 静默降级（设置页可重新授权）
      if (resp.statusCode != 200) return null;

      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final candidates = list.where((r) {
        final release = r as Map<String, dynamic>;
        if (release['draft'] == true) return false;
        if (ch == 'stable' && release['prerelease'] == true) return false;
        return true;
      }).toList();
      if (candidates.isEmpty) return null;
      final j = candidates.first as Map<String, dynamic>;
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
    } catch (e) {
      // 静默不打扰，但落盘备查（「我」页错误日志可回看）
      await ErrorLog.record(AppError.from(e, context: '更新检查'));
      return null;
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

  /// 语义化版本比较（含预发布）：remote 是否比 current 更新。
  /// 规则：1.2.0 < 1.3.0-dev.1 < 1.3.0（同三段下，正式版大于预发布版）
  bool _isNewer(String remote, String current) {
    final r = _split(remote);
    final c = _split(current);
    for (var i = 0; i < 3; i++) {
      if (r.$1[i] != c.$1[i]) return r.$1[i] > c.$1[i];
    }
    // 三段相同：正式版 > 预发布版；都有预发布则按字符串比较（dev.1 < dev.2）
    final rPre = r.$2;
    final cPre = c.$2;
    if (rPre == null && cPre == null) return false;
    if (rPre == null) return true; // remote 是正式、current 是预发布
    if (cPre == null) return false; // remote 是预发布、current 是正式
    return rPre.compareTo(cPre) > 0;
  }

  /// 拆为（三段数值, 预发布段或 null）；忽略 +build 号
  (List<int>, String?) _split(String version) {
    final main = version.split('+').first;
    final dash = main.indexOf('-');
    final core = dash >= 0 ? main.substring(0, dash) : main;
    final pre = dash >= 0 ? main.substring(dash + 1) : null;
    final nums = <int>[
      for (final p in core.split('.')) int.tryParse(p) ?? 0,
    ];
    while (nums.length < 3) {
      nums.add(0);
    }
    return (nums.sublist(0, 3), pre);
  }
}
