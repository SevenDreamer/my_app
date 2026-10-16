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
  static const String _deviceCodeEndpoint =
      'https://github.com/login/device/code';
  static const String _accessTokenEndpoint =
      'https://github.com/login/oauth/access_token';

  final http.Client _client;
  final FlutterSecureStorage _storage;

  /// 已存的 access token（无授权返回 null）
  Future<String?> get token => _storage.read(key: _kTokenKey);

  /// 是否已授权
  Future<bool> get isAuthorized async => (await token) != null;

  /// 撤销本设备的授权（删除本地 token）
  Future<void> revoke() => _storage.delete(key: _kTokenKey);

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
      final resp = await _client.post(
        Uri.parse(_accessTokenEndpoint),
        headers: const {'Accept': 'application/json'},
        body: {
          'client_id': clientId,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final accessToken = j['access_token'] as String?;
      if (accessToken != null) {
        await _storage.write(key: _kTokenKey, value: accessToken);
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
