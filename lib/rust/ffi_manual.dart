/// 手动 FFI 绑定（临时方案）
///
/// 调用 Rust 的 C ABI 接口。等 flutter_rust_bridge codegen 在 Windows 上
/// 修复后，替换为自动生成的绑定。
library;

import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

/// FFI 绑定类（单例模式）
class CoreFFI {
  static late final CoreFFI _instance;
  late final ffi.DynamicLibrary _dylib;

  /// 私有构造函数
  CoreFFI._() {
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
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  /// 初始化 FFI（必须在调用任何方法前调用）
  static void init() {
    _instance = CoreFFI._();
  }

  /// 获取单例实例
  static CoreFFI get instance => _instance;

  // ==================== 函数签名定义 ====================

  /// init_my_app: 返回 CString 指针
  late final _initMyApp = _dylib
      .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)>('init_my_app');

  /// get_core_version: 返回 CString 指针
  late final _getCoreVersion = _dylib
      .lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('get_core_version');

  /// ping: 返回 CString 指针
  late final _ping = _dylib
      .lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('ping');

  /// free_string: 释放 CString 指针
  late final _freeString = _dylib
      .lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('free_string');

  /// add: 简单加法测试
  late final _add = _dylib
      .lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('add');

  /// llm_list_models: 返回 CString 指针（JSON）
  late final _llmListModels = _dylib
      .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)>(
          'llm_list_models');

  // ==================== Dart 封装方法 ====================

  /// 初始化 My App
  String initMyApp({String logLevel = 'info'}) {
    final logLevelC = logLevel.toNativeUtf8();
    final resultPtr = _initMyApp(logLevelC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取 Core 版本号
  String getCoreVersion() {
    final resultPtr = _getCoreVersion();
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// Ping 测试
  String ping() {
    final resultPtr = _ping();
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 加法测试
  int add(int a, int b) => _add(a, b);

  /// 获取 LLM 模型列表（返回 JSON 字符串）
  String llmListModels({String provider = 'deepseek'}) {
    final providerC = provider.toNativeUtf8();
    final resultPtr = _llmListModels(providerC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  // ==================== 数据库 FFI 函数 ====================

  /// db_connect: 返回 JSON 字符串指针
  late final _dbConnect = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('db_connect');

  /// db_disconnect: 返回 JSON 字符串指针
  late final _dbDisconnect = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('db_disconnect');

  /// db_get_databases: 返回 JSON 字符串指针
  late final _dbGetDatabases = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('db_get_databases');

  /// db_get_tables: 返回 JSON 字符串指针
  late final _dbGetTables = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>('db_get_tables');

  /// db_get_fields: 返回 JSON 字符串指针
  late final _dbGetFields = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>('db_get_fields');

  /// db_get_table_data: 返回 JSON 字符串指针
  late final _dbGetTableData = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int64, Int64),
      Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, int)>('db_get_table_data');

  /// db_test_connection: 返回 JSON 字符串指针
  late final _dbTestConnection = _dylib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('db_test_connection');

  // ==================== 数据库 Dart 封装 ====================

  /// 连接数据库
  /// [configJson] DbConnectionConfig 的 JSON 字符串
  /// 返回：{"ok": true, "conn_id": "..."} 或 {"ok": false, "error": "..."}
  String dbConnect(String configJson) {
    final configC = configJson.toNativeUtf8();
    final resultPtr = _dbConnect(configC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 断开连接
  String dbDisconnect(String connId) {
    final cidC = connId.toNativeUtf8();
    final resultPtr = _dbDisconnect(cidC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取数据库列表
  String dbGetDatabases(String connId) {
    final cidC = connId.toNativeUtf8();
    final resultPtr = _dbGetDatabases(cidC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取表列表
  String dbGetTables(String connId, String databaseName) {
    final cidC = connId.toNativeUtf8();
    final dbC = databaseName.toNativeUtf8();
    final resultPtr = _dbGetTables(cidC, dbC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取表字段信息
  String dbGetFields(String connId, String databaseName, String tableName) {
    final cidC = connId.toNativeUtf8();
    final dbC = databaseName.toNativeUtf8();
    final tableC = tableName.toNativeUtf8();
    final resultPtr = _dbGetFields(cidC, dbC, tableC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取表数据（分页）
  String dbGetTableData(String connId, String databaseName, String tableName,
      {int limit = 100, int offset = 0}) {
    final cidC = connId.toNativeUtf8();
    final dbC = databaseName.toNativeUtf8();
    final tableC = tableName.toNativeUtf8();
    final resultPtr = _dbGetTableData(cidC, dbC, tableC, limit, offset);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 测试连接
  String dbTestConnection(String configJson) {
    final configC = configJson.toNativeUtf8();
    final resultPtr = _dbTestConnection(configC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }
}
