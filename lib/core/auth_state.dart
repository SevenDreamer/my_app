// 全局认证状态管理
//
// 存储登录后的 token 和用户信息，供整个应用访问。

import 'package:my_app/rust/api/auth.dart' as auth_api;

class AuthState {
  // 单例模式
  static final AuthState _instance = AuthState._internal();
  factory AuthState() => _instance;
  AuthState._internal();

  // 当前 token（null 表示未登录）
  String? _token;

  // 当前用户信息（null 表示未登录）
  auth_api.UserInfo? _userInfo;

  // 后端基础 URL
  String? _baseUrl;

  // Getter
  String? get token => _token;
  auth_api.UserInfo? get userInfo => _userInfo;
  String? get baseUrl => _baseUrl;
  bool get isLoggedIn => _token != null;

  // 设置登录状态
  void login(String token, auth_api.UserInfo userInfo, String baseUrl) {
    _token = token;
    _userInfo = userInfo;
    _baseUrl = baseUrl;
  }

  // 登出
  void logout() {
    _token = null;
    _userInfo = null;
    _baseUrl = null;
  }
}
