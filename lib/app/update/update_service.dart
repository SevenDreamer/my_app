//! 更新检查（v2 分发）：匿名拉 R2 manifest → semver 对比 → 提示下载安装
//!
//! 安装包与 manifest 托管在 Cloudflare R2 公开桶，匿名 GET 即可——
//! 不再依赖 GitHub token（Device Flow 现在只剩流水线通知在用）。
//! manifest 每通道一份：stable → manifest.json，dev → manifest-dev.json。
//! 一切异常都静默返回 null——更新检查绝不打断使用
//!（无新版 / 网络失败 / iOS 平台 / 已忽略版本）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_log.dart';

/// 一条可用的更新提示
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
    required this.apks,
  });

  /// 纯版本号（如 1.3.0-dev.5）
  final String version;

  /// 更新说明（截取展示由 UI 决定）
  final String notes;

  /// 下载页地址（桌面「前往下载」）
  final String url;

  /// Android 安装包：ABI → 下载 URL（可含 'universal' 兜底项）
  final Map<String, String> apks;

  /// 按设备 ABI 解析安装包 URL：精确匹配 → universal → 首个
  String? resolveApk(String? abi) {
    if (apks.isEmpty) return null;
    if (abi != null && apks.containsKey(abi)) return apks[abi];
    return apks['universal'] ?? apks.values.first;
  }
}

/// 更新源：返回该通道的最新版本元数据；网络/解析异常向上抛，调用方静默落盘
abstract class UpdateSource {
  Future<UpdateInfo?> fetchLatest(String channel);
}

/// R2 静态 manifest 源：GET {baseUrl}/{manifest 文件} 解析 UpdateInfo
class ManifestUpdateSource implements UpdateSource {
  ManifestUpdateSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// R2 公开桶地址（my-app-apks 桶 my_app_dist/ 前缀，公共开发 URL）
  static const String baseUrl =
      'https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist';

  /// 通道 → manifest 文件名
  String manifestFile(String channel) =>
      channel == 'dev' ? 'manifest-dev.json' : 'manifest.json';

  @override
  Future<UpdateInfo?> fetchLatest(String channel) async {
    final resp =
        await _client.get(Uri.parse('$baseUrl/${manifestFile(channel)}'));
    if (resp.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final version = (j['version'] as String?) ?? '';
    if (version.isEmpty) return null;
    final apks = <String, String>{};
    final rawApks = (j['apks'] as Map?) ?? const {};
    for (final e in rawApks.entries) {
      if (e.key is String && e.value is String) {
        apks[e.key] = e.value as String;
      }
    }
    return UpdateInfo(
      version: version,
      notes: (j['notes'] as String?) ?? '',
      url: (j['page'] as String?) ?? '',
      apks: apks,
    );
  }
}

class UpdateService {
  UpdateService({UpdateSource? source})
      : _source = source ?? ManifestUpdateSource();

  static const String _kIgnoredVersionKey = 'update_ignored_version';
  static const String _kChannelKey = 'update_channel';

  /// 更新通道：'stable'（默认，只看正式版）/ 'dev'（含预发布版）
  Future<String> channel() async {
    return await const FlutterSecureStorage().read(key: _kChannelKey) ??
        'stable';
  }

  Future<void> setChannel(String value) =>
      const FlutterSecureStorage().write(key: _kChannelKey, value: value);

  final UpdateSource _source;

  /// 最新版本元数据（不做新旧/忽略过滤；扫码下载等场景用）
  Future<UpdateInfo?> latest() async {
    try {
      return await _source.fetchLatest(await channel());
    } catch (e) {
      // 静默不打扰，但落盘备查（「我」页错误日志可回看）
      await ErrorLog.record(AppError.from(e, context: '更新检查'));
      return null;
    }
  }

  /// 静默检查；无新版或任何异常返回 null
  Future<UpdateInfo?> check() async {
    // iOS 无 App Store 外的更新渠道（AGENTS.md 明确不支持）
    if (defaultTargetPlatform == TargetPlatform.iOS) return null;

    final info = await latest();
    if (info == null) return null;

    final ignored = await ignoredVersion();
    if (ignored == info.version) return null;

    final current = await _currentVersion();
    if (!_isNewer(info.version, current)) return null;

    return info;
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
