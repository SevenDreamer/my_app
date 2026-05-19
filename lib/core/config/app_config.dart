/// 全局应用配置
///
/// 集中管理环境变量、API 地址、功能开关等常量。
/// 参考 React 项目 src/config/index.ts 的设计。
library;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// 应用运行环境
enum AppEnvironment {
  /// 本地开发（连 localhost）
  dev,
  /// 测试环境
  staging,
  /// 生产环境
  prod,
}

/// 全局配置类
class AppConfig {
  const AppConfig._();

  // ─── 当前环境（修改此处切换环境）────
  static const AppEnvironment environment = AppEnvironment.dev;

  // ─── API 基础地址 ────
  static const String _devBaseUrl = 'http://localhost:5000';
  static const String _stagingBaseUrl = 'https://staging-api.example.com';
  static const String _prodBaseUrl = 'https://api.example.com';

  /// 当前环境的 API 基础地址
  static String get baseUrl {
    switch (environment) {
      case AppEnvironment.dev:
        return _devBaseUrl;
      case AppEnvironment.staging:
        return _stagingBaseUrl;
      case AppEnvironment.prod:
        return _prodBaseUrl;
    }
  }

  // ─── 认证相关 ────
  static const String tokenStorageKey = 'auth_token';
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);

  // ─── 超时设置 ────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ─── 功能开关 ────
  static const bool enableLogging = !kReleaseMode;
  static const bool enableDevTools = !kReleaseMode;
}
