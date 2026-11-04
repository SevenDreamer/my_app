//! 连接层：launch-token 登录换会话凭证 → HTTP 交换 + WebSocket 升级。
//!
//! 设计（参考 dsh-go connection 的协议形态，代码原创）：
//! - 登录：`GET /?token=<launch token>` 换签名会话凭证（绑 host:port，长效；
//!   dsh web 重启不失效，launch token 每次进程启动都变）。
//! - 401 才重登（凭证是 bearer，调用方持久化进安全存储）。
//! - 全部请求带正确 Host 头、不发 Origin（非浏览器客户端语义）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'errors.dart';

/// 会话凭证（登录产物；bearer 语义，调用方负责安全持久化）。
class DshSession {
  const DshSession({
    required this.cookieName,
    required this.cookieValue,
    required this.authority,
    this.expiresAt,
  });

  final String cookieName;
  final String cookieValue;

  /// `host:port`（凭证绑定的 authority）。
  final String authority;
  final DateTime? expiresAt;

  String get cookieHeader => '$cookieName=$cookieValue';

  Map<String, Object?> toJson() => {
        'cookieName': cookieName,
        'cookieValue': cookieValue,
        'authority': authority,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  static DshSession? fromJson(Map<String, Object?> json) {
    final name = json['cookieName'];
    final value = json['cookieValue'];
    final authority = json['authority'];
    if (name is! String || value is! String || authority is! String) return null;
    return DshSession(
      cookieName: name,
      cookieValue: value,
      authority: authority,
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// 一个 `dsh web` Host 的连接（HTTP + WS 双通道共用此会话）。
class DshConnection {
  DshConnection({
    required this.baseUrl,
    this.session,
    HttpClient? client,
  }) : _client = client ?? HttpClient()..autoUncompress = false;

  /// 例：`http://127.0.0.1:3080`（不含尾斜杠）。
  final String baseUrl;
  final HttpClient _client;

  /// 当前会话凭证（null = 未登录）。
  DshSession? session;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
        path: '${base.path}$path', queryParameters: query);
  }

  /// 登录：launch token 换会话凭证（401 语义：token 失效/已用）。
  Future<DshSession> login(String launchToken) async {
    final request = await _client.getUrl(_uri('/', {'token': launchToken}));
    request.headers.set(HttpHeaders.hostHeader,
        '${Uri.parse(baseUrl).host}:${Uri.parse(baseUrl).port}');
    request.headers.removeAll(HttpHeaders.cookieHeader);
    final response = await request.close();
    // 吃掉响应体（登录以 Set-Cookie 判定，不解析正文）。
    await response.drain<void>();
    if (response.statusCode == HttpStatus.unauthorized) {
      throw const DshUnauthorizedException('LAUNCH_TOKEN_INVALID');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DshApiException('LOGIN_FAILED',
          'HTTP ${response.statusCode} on login');
    }
    final setCookies = response.headers[HttpHeaders.setCookieHeader] ?? [];
    for (final raw in setCookies) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq);
      final value = pair.substring(eq + 1);
      if (value.isEmpty) continue;
      session = DshSession(
        cookieName: name,
        cookieValue: value,
        authority:
            '${Uri.parse(baseUrl).host}:${Uri.parse(baseUrl).port}',
      );
      return session!;
    }
    throw const DshApiException('LOGIN_NO_SESSION', '登录未返回会话凭证');
  }

  /// HTTP 交换（JSON）；401 抛 [DshUnauthorizedException]（调用方重登重试）。
  Future<Map<String, Object?>> exchange(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final current = session;
    if (current == null) {
      throw const DshApiException('NOT_LOGGED_IN', '先 login() 再交换');
    }
    final request = await _client.openUrl(method, _uri(path, query));
    request.headers.set(HttpHeaders.hostHeader, current.authority);
    request.headers.set(HttpHeaders.cookieHeader, current.cookieHeader);
    request.headers.contentType = ContentType.json;
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode == HttpStatus.unauthorized) {
      throw const DshUnauthorizedException();
    }
    final decoded = text.isEmpty ? <String, Object?>{} : jsonDecode(text);
    if (decoded is Map<String, Object?>) {
      if (response.statusCode >= 400) {
        throw DshApiException(
            '${decoded['code'] ?? 'HTTP_${response.statusCode}'}',
            '${decoded['message'] ?? text}');
      }
      return decoded;
    }
    throw DshApiException('BAD_RESPONSE', '响应不是 JSON 对象');
  }

  /// WebSocket 升级（mux 的物理链路；带会话凭证与 Host 头）。
  Future<WebSocket> openWebSocket(String path) async {
    final current = session;
    if (current == null) {
      throw const DshApiException('NOT_LOGGED_IN', '先 login() 再升级');
    }
    final wsUri = _uri(path).replace(scheme: 'ws');
    return WebSocket.connect(
      wsUri.toString(),
      headers: {
        HttpHeaders.hostHeader: current.authority,
        HttpHeaders.cookieHeader: current.cookieHeader,
      },
    );
  }

  void close() {
    _client.close(force: true);
  }
}
