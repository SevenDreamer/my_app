//! GitHub Device Flow 授权：用户用自己的账号授权本设备查询私有仓库
//!
//! 安全模型（AGENTS.md · 版本与发布）：**二进制零内置 token**——
//! client_id 是公开值可入库，access_token 由用户设备在本机
//! secure storage 生成并保存（桌面=Windows DPAPI，移动=钥匙串/Keystore）。
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// 一次设备码授权所需的全部信息
class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;

  /// 已拼好 user_code 的链接（打开即免输码）
  final String verificationUriComplete;
  final int expiresIn;
  final int interval;
}

class GithubAuthService {
  GithubAuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  /// 注册的 OAuth App Client ID（Device Flow 公开值，非秘密）
  static const String clientId = 'Ov23likLbtcSkW7rdHMA';

  static const String _kTokenKey = 'github_access_token';
  static const String _kRefreshKey = 'github_refresh_token';
  static const String _kExpiresKey = 'github_token_expires_at';
  static const String _deviceCodeEndpoint =
      'https://github.com/login/device/code';
  static const String _accessTokenEndpoint =
      'https://github.com/login/oauth/access_token';

  final http.Client _client;
  final FlutterSecureStorage _storage;

  /// 已存的 access token 原始读取（不做续期判断）
  Future<String?> get token => _storage.read(key: _kTokenKey);

  /// 获取有效 token：过期（或临期 5 分钟）时用 refresh_token 自动续期；
  /// 续期失败（refresh_token 也失效）→ 清理本地凭据并返回 null。
  Future<String?> validToken() async {
    final token = await _storage.read(key: _kTokenKey);
    if (token == null) return null;

    final expiresRaw = await _storage.read(key: _kExpiresKey);
    final expiresAt = int.tryParse(expiresRaw ?? '') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 仍在有效期内（留 5 分钟余量）直接返回
    if (expiresAt > nowMs + 5 * 60 * 1000) return token;

    final refresh = await _storage.read(key: _kRefreshKey);
    if (refresh == null) {
      // 旧格式无过期信息：照常返回，是否真失效交给 API 的 401 兜底
      if (expiresAt == 0) return token;
      await revoke();
      return null;
    }

    // 用 refresh_token 换新 access_token
    final resp = await _client.post(
      Uri.parse(_accessTokenEndpoint),
      headers: const {'Accept': 'application/json'},
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
      },
    );
    if (resp.statusCode != 200) {
      await revoke();
      return null;
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final newToken = j['access_token'] as String?;
    if (newToken == null) {
      await revoke();
      return null;
    }
    await _storage.write(key: _kTokenKey, value: newToken);
    final newRefresh = j['refresh_token'] as String?;
    if (newRefresh != null) {
      await _storage.write(key: _kRefreshKey, value: newRefresh);
    }
    final expiresIn = (j['expires_in'] as num?)?.toInt() ?? 0;
    if (expiresIn > 0) {
      await _storage.write(
        key: _kExpiresKey,
        value: DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch
            .toString(),
      );
    }
    return newToken;
  }

  /// 是否已授权
  Future<bool> get isAuthorized async => (await token) != null;

  /// 撤销本设备的授权（清理全部本地凭据）
  Future<void> revoke() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kRefreshKey);
    await _storage.delete(key: _kExpiresKey);
  }

  /// 步骤一：申请设备码（scope: repo——访问私有仓库 release）
  Future<DeviceCode> requestDeviceCode() async {
    final resp = await _client.post(
      Uri.parse(_deviceCodeEndpoint),
      headers: const {'Accept': 'application/json'},
      body: {'client_id': clientId, 'scope': 'repo'},
    );
    if (resp.statusCode != 200) {
      throw StateError('申请设备码失败（HTTP ${resp.statusCode}）');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    // GitHub 的失败响应也是 JSON：先透出 error，不要让 as String 在 null 上炸
    final error = j['error'];
    if (error != null) {
      final desc = j['error_description'] ?? j['error_uri'] ?? '';
      throw StateError(
        '设备码申请失败：$error${desc is String && desc.isNotEmpty ? '（$desc）' : ''}',
      );
    }
    final deviceCode = j['device_code'] as String?;
    final userCode = j['user_code'] as String?;
    final uri = j['verification_uri'] as String?;
    if (deviceCode == null || userCode == null || uri == null) {
      final raw = resp.body.length > 300
          ? resp.body.substring(0, 300)
          : resp.body;
      throw StateError('设备码响应异常（缺字段）：$raw');
    }
    return DeviceCode(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: uri,
      verificationUriComplete:
          (j['verification_uri_complete'] as String?) ?? '$uri?user_code=$userCode',
      expiresIn: (j['expires_in'] as num?)?.toInt() ?? 900,
      interval: (j['interval'] as num?)?.toInt() ?? 5,
    );
  }

  /// 步骤二：轮询授权结果（内部处理 pending / slow_down，直到成功或过期）
  Future<String> pollForToken(DeviceCode code) async {
    final deadline = DateTime.now().add(Duration(seconds: code.expiresIn));
    var interval = code.interval;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));

      // 单次请求的网络抖动不算失败：视为 pending 继续轮询（授权动作不白费）
      final Map<String, dynamic> j;
      try {
        final resp = await _client.post(
          Uri.parse(_accessTokenEndpoint),
          headers: const {'Accept': 'application/json'},
          body: {
            'client_id': clientId,
            'device_code': code.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        );
        j = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        continue; // 网络中断/抖动：下一轮再试
      }
      final accessToken = j['access_token'] as String?;
      if (accessToken != null) {
        await _storage.write(key: _kTokenKey, value: accessToken);
        // GitHub 在 token 到期策略下会返回 refresh_token：一并保存供自动续期
        final refreshToken = j['refresh_token'] as String?;
        if (refreshToken != null) {
          await _storage.write(key: _kRefreshKey, value: refreshToken);
        }
        final expiresIn = (j['expires_in'] as num?)?.toInt() ?? 0;
        if (expiresIn > 0) {
          await _storage.write(
            key: _kExpiresKey,
            value: DateTime.now()
                .add(Duration(seconds: expiresIn))
                .millisecondsSinceEpoch
                .toString(),
          );
        }
        return accessToken;
      }
      final error = j['error'] as String?;
      if (error == 'authorization_pending') continue;
      if (error == 'slow_down') {
        interval += 5;
        continue;
      }
      // expired_token / access_denied / 其他
      throw StateError('授权未完成：$error');
    }
    throw TimeoutException('授权超时（设备码已过期）');
  }
}
