/// 认证相关 FFI 绑定
///
/// 调用 Rust 的认证相关 C ABI 接口

library;

import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

/// 认证 FFI 绑定类（单例模式）
class AuthFFI {
  static late final AuthFFI _instance;
  late final ffi.DynamicLibrary _dylib;

  /// 私有构造函数
  AuthFFI._() {
    if (Platform.isWindows) {
      _dylib = ffi.DynamicLibrary.open('my_app.dll');
    } else if (Platform.isLinux) {
      _dylib = ffi.DynamicLibrary.open('libmy_app.so');
    } else if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.open('libmy_app.dylib');
    } else if (Platform.isAndroid) {
      // Android: library is bundled in APK, load from process
      _dylib = ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError(
          'Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  /// 初始化 FFI（必须在调用任何方法前调用）
  static void init() {
    _instance = AuthFFI._();
  }

  /// 获取单例实例
  static AuthFFI get instance => _instance;

  // ==================== 函数签名定义 ====================

  /// auth_init: 返回 CString 指针
  late final _authInit = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_init');

  /// auth_login: 返回 CString 指针
  late final _authLogin = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_login');

  /// auth_logout: 返回 CString 指针
  late final _authLogout = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_logout');

  /// auth_get_current_user: 返回 CString 指针
  late final _authGetCurrentUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_get_current_user');

  /// auth_create_user: 返回 CString 指针
  late final _authCreateUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>('auth_create_user');

  /// auth_get_users: 返回 CString 指针
  late final _authGetUsers = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_get_users');

  /// auth_update_user: 返回 CString 指针
  late final _authUpdateUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>)>('auth_update_user');

  /// auth_delete_user: 返回 CString 指针
  late final _authDeleteUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Pointer<Utf8>),
      Pointer<Utf8> Function(int, Pointer<Utf8>)>('auth_delete_user');

  /// auth_register_app: 返回 CString 指针
  late final _authRegisterApp = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>('auth_register_app');

  /// auth_get_apps: 返回 CString 指针
  late final _authGetApps = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('auth_get_apps');

  /// auth_update_app: 返回 CString 指针
  late final _authUpdateApp = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>)>('auth_update_app');

  /// auth_delete_app: 返回 CString 指针
  late final _authDeleteApp = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Pointer<Utf8>),
      Pointer<Utf8> Function(int, Pointer<Utf8>)>('auth_delete_app');

  /// auth_assign_app_to_user: 返回 CString 指针
  late final _authAssignAppToUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Int64, Pointer<Utf8>),
      Pointer<Utf8> Function(int, int, Pointer<Utf8>)>('auth_assign_app_to_user');

  /// auth_remove_app_from_user: 返回 CString 指针
  late final _authRemoveAppFromUser = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Int64, Pointer<Utf8>),
      Pointer<Utf8> Function(int, int, Pointer<Utf8>)>('auth_remove_app_from_user');

  /// auth_get_user_apps: 返回 CString 指针
  late final _authGetUserApps = _dylib.lookupFunction<
      Pointer<Utf8> Function(Int64, Pointer<Utf8>),
      Pointer<Utf8> Function(int, Pointer<Utf8>)>('auth_get_user_apps');

  // ==================== Dart 封装方法 ====================

  /// 辅助：调用 Rust 函数并转换结果
  String _callRust(Pointer<Utf8> Function(Pointer<Utf8>) func,
      Pointer<Utf8> arg) {
    final resultPtr = func(arg);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 辅助：释放 CString 指针
  late final _freeString = _dylib.lookupFunction<
      Void Function(Pointer<Utf8>),
      void Function(Pointer<Utf8>)>('free_string');

  /// 初始化认证数据库
  /// [dbPath] 数据库路径（可为空，默认 "auth.db"）
  /// 返回：JSON 字符串
  String initAuth({String dbPath = ''}) {
    final dbPathC = dbPath.toNativeUtf8();
    final resultPtr = _authInit(dbPathC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 用户登录
  /// [requestJson] 登录请求 JSON：`{"username": "...", "password": "..."}`
  /// 返回：JSON 字符串 `{"ok": true, "user_id": ..., "username": "...", "role": "...", "token": "..."}`
  String login(String requestJson) {
    final jsonC = requestJson.toNativeUtf8();
    final resultPtr = _authLogin(jsonC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 用户登出
  /// [token] 登录时获取的 token
  /// 返回：JSON 字符串
  String logout(String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authLogout(tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取当前登录用户
  /// [token] 登录时获取的 token
  /// 返回：JSON 字符串
  String getCurrentUser(String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authGetCurrentUser(tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 创建用户（仅管理员）
  /// [requestJson] 创建用户请求 JSON：`{"username": "...", "password": "...", "role": "..."}`
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String createUser(String requestJson, String token) {
    final jsonC = requestJson.toNativeUtf8();
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authCreateUser(jsonC, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取用户列表（仅管理员）
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String getUsers(String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authGetUsers(tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 更新用户（仅管理员）
  /// [userId] 用户 ID
  /// [requestJson] 更新用户请求 JSON：`{"password": "...", "role": "..."}`
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String updateUser(int userId, String requestJson, String token) {
    final jsonC = requestJson.toNativeUtf8();
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authUpdateUser(userId, jsonC, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 删除用户（仅管理员）
  /// [userId] 用户 ID
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String deleteUser(int userId, String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authDeleteUser(userId, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 注册应用（仅管理员）
  /// [requestJson] 应用信息 JSON
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String registerApp(String requestJson, String token) {
    final jsonC = requestJson.toNativeUtf8();
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authRegisterApp(jsonC, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取应用列表
  /// [token] 用户 token
  /// 返回：JSON 字符串
  String getApps(String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authGetApps(tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 更新应用（仅管理员）
  /// [appId] 应用 ID
  /// [requestJson] 应用信息 JSON
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String updateApp(int appId, String requestJson, String token) {
    final jsonC = requestJson.toNativeUtf8();
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authUpdateApp(appId, jsonC, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 删除应用（仅管理员）
  /// [appId] 应用 ID
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String deleteApp(int appId, String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authDeleteApp(appId, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 为用户分配应用（仅管理员）
  /// [userId] 用户 ID
  /// [appId] 应用 ID
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String assignAppToUser(int userId, int appId, String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authAssignAppToUser(userId, appId, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 移除用户的应用权限（仅管理员）
  /// [userId] 用户 ID
  /// [appId] 应用 ID
  /// [token] 管理员 token
  /// 返回：JSON 字符串
  String removeAppFromUser(int userId, int appId, String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authRemoveAppFromUser(userId, appId, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取用户的应用权限
  /// [userId] 用户 ID
  /// [token] 用户 token（管理员可以查看所有用户，普通用户只能查看自己）
  /// 返回：JSON 字符串
  String getUserApps(int userId, String token) {
    final tokenC = token.toNativeUtf8();
    final resultPtr = _authGetUserApps(userId, tokenC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }
}
