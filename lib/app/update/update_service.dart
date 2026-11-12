//! 更新检查（v2 分发）：匿名拉 R2 manifest → semver 对比 → 提示下载安装
//!
//! 安装包与 manifest 托管在 Cloudflare R2 公开桶，匿名 GET 即可——
//! 不再依赖 GitHub token（历史遗留的 Device Flow 授权/流水线通知已移除）。
//! manifest 固定 `manifest.json`（更新通道已移除；过渡期 release.sh 兼容
//! 双写 manifest-dev.json 供旧版本读取，见 tool/release.sh）。
//! 一切异常都静默返回 null——更新检查绝不打断使用
//!（无新版 / 网络失败 / iOS 平台 / 已忽略版本）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_log.dart';

/// 一条可用的更新提示
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
    required this.apks,
    this.apkSha256,
    this.patch,
  });

  /// 纯版本号（如 1.3.0-dev.5）
  final String version;

  /// APK 完整性期望值（R2 manifest 的 apkSha256；旧 manifest 无此字段=null）
  final String? apkSha256;

  /// 更新说明（截取展示由 UI 决定）
  final String notes;

  /// 下载页地址（桌面「前往下载」）
  final String url;

  /// Android 安装包：ABI → 下载 URL（可含 'universal' 兜底项）
  final Map<String, String> apks;

  /// 热更 patch 发布信息（manifest `patch` 节；无 patch 发布时为 null）
  final PatchInfo? patch;

  /// 按设备 ABI 解析安装包 URL：精确匹配 → universal → 首个
  String? resolveApk(String? abi) {
    if (apks.isEmpty) return null;
    if (abi != null && apks.containsKey(abi)) return apks[abi];
    return apks['universal'] ?? apks.values.first;
  }
}

/// 热更 patch 发布信息（manifest `patch` 节；tool/patch.sh 发布时刷新）
class PatchInfo {
  const PatchInfo({
    required this.release,
    required this.number,
    this.notes = '',
    this.time = '',
  });

  /// 目标 release（version+build 全号，如 1.3.0-dev.26+70）——只对同号设备有意义
  final String release;

  /// Shorebird Patch 序号（Patch N）
  final int number;

  /// 更新说明（tool/patch.sh 的第二参数，可空）
  final String notes;

  /// 发布时间（UTC ISO8601，脚本打点）
  final String time;

  /// 解析 manifest `patch` 节；缺失/非法返回 null（一律按「无 patch」处理）
  static PatchInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final release = raw['release'];
    final number = raw['number'];
    if (release is! String || release.isEmpty) return null;
    if (number is! int) return null;
    return PatchInfo(
      release: release,
      number: number,
      notes: (raw['notes'] as String?) ?? '',
      time: (raw['time'] as String?) ?? '',
    );
  }
}

/// 更新源：返回最新版本元数据；网络/解析异常向上抛，调用方静默落盘
abstract class UpdateSource {
  Future<UpdateInfo?> fetchLatest();
}

/// R2 静态 manifest 源：GET {baseUrl}/manifest.json 解析 UpdateInfo
class ManifestUpdateSource implements UpdateSource {
  ManifestUpdateSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// R2 公开桶地址（my-app-apks 桶 my_app_dist/ 前缀，公共开发 URL）
  static const String baseUrl =
      'https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist';

  /// manifest 文件名（通道概念已移除，固定一份）
  static const String manifestName = 'manifest.json';

  @override
  Future<UpdateInfo?> fetchLatest() async {
    final resp = await _client.get(Uri.parse('$baseUrl/$manifestName'));
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
      apkSha256: j['apkSha256'] as String?,
      patch: PatchInfo.tryParse(j['patch']),
    );
  }
}

class UpdateService {
  UpdateService({UpdateSource? source})
      : _source = source ?? ManifestUpdateSource();

  static const String _kIgnoredVersionKey = 'update_ignored_version';

  final UpdateSource _source;

  /// 最新版本元数据（不做新旧/忽略过滤；扫码下载等场景用）
  Future<UpdateInfo?> latest() async {
    try {
      return await _source.fetchLatest();
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
  /// 规则：1.2.0 < 1.3.0-dev.1 < 1.3.0（同三段下，正式版大于预发布版）。
  /// 比较委托 pub_semver（pub 官方解析器）——手写比较踩过坑：
  /// 'dev.10' 整段字符串比 < 'dev.9'，跨位数就漏报更新。
  bool _isNewer(String remote, String current) {
    final r = _tryParse(remote);
    final c = _tryParse(current);
    if (r == null || c == null) return false;
    return r > c;
  }

  /// 解析版本号：先剥 +build 号（更新判断只看纯版本号），
  /// 格式非法返回 null（调用侧按"无更新"处理）
  Version? _tryParse(String version) {
    final main = version.split('+').first;
    try {
      return Version.parse(main);
    } on FormatException {
      return null;
    }
  }
}
