// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.BridgeConnectionDescriptor —— 现代化重构，行为契约不变。
//! 一个已绑定监听者身份。凭据刻意不出现在普通快照里；
//! 只有私有 0600 发布者可以序列化含凭据的 [privateRecord]。
//! 错误契约：`BRIDGE_DESCRIPTOR_IDENTITY`。
library;

/// 描述符（校验即构造；凭据 [credentialHeader] 仅经 [privateRecord] 外发）。
class BridgeConnectionDescriptor {
  static const int schemaVersion = 1;
  static const String guestPath = '/run/dsha-bridge/connection.json';
  static const String environment = 'DSHA_BRIDGE_DESCRIPTOR';
  static const String urlEnvironment = 'DSHA_BRIDGE_URL';

  BridgeConnectionDescriptor._({
    required this.applicationId,
    required this.installInstanceId,
    required this.bridgeRunId,
    required this.generation,
    required this.port,
    required this.token,
  });

  /// 构造即校验（原版构造器）；[expectedApplicationId] 为本 App 身份
  ///（原版 `AppIdentity.applicationId()` 的接线面）。
  factory BridgeConnectionDescriptor.create({
    required String expectedApplicationId,
    required String applicationId,
    required String installInstanceId,
    required String bridgeRunId,
    required int generation,
    required int port,
    required String token,
  }) {
    if (applicationId != expectedApplicationId ||
        !_uuid(installInstanceId) ||
        !_uuid(bridgeRunId) ||
        generation <= 0 ||
        port < 1 ||
        port > 65535 ||
        port == 3090 ||
        port == 3081 ||
        port == 3190 ||
        !RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(token)) {
      throw ArgumentError('BRIDGE_DESCRIPTOR_IDENTITY');
    }
    return BridgeConnectionDescriptor._(
      applicationId: applicationId,
      installInstanceId: installInstanceId,
      bridgeRunId: bridgeRunId,
      generation: generation,
      port: port,
      token: token,
    );
  }

  /// 规范小写 UUID（Java `UUID.toString().equals(value)` 的等价判定）。
  static bool _uuid(String value) =>
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(value);

  final String applicationId;
  final String installInstanceId;
  final String bridgeRunId;
  final int generation;
  final int port;
  final String token;

  String host() => '127.0.0.1';

  String baseUrl() => 'http://127.0.0.1:$port';

  String state() => 'ready';

  String credentialHeader() => token;

  /// 普通快照：**不含 token**。
  Map<String, Object?> safeSnapshot() => {
        'schemaVersion': schemaVersion,
        'applicationId': applicationId,
        'installInstanceId': installInstanceId,
        'bridgeRunId': bridgeRunId,
        'generation': generation,
        'host': host(),
        'port': port,
        'baseUrl': baseUrl(),
        'state': state(),
      };

  /// 含凭据记录；仅私有 0600 发布者可序列化。
  Map<String, Object?> privateRecord() => {
        ...safeSnapshot(),
        'token': token,
      };

  /// 常时安全比对（原版 `MessageDigest.isEqual`）。
  bool authenticates(String app, String run, String presented) {
    return applicationId == app &&
        bridgeRunId == run &&
        constantTimeEquals(token, presented);
  }

  /// guest 环境变量注入面（原版方法名 `environment()`，与常量同名 Dart 不允许）。
  Map<String, String> guestEnvironment() => {
        environment: guestPath,
        urlEnvironment: baseUrl(),
        'DSHA_BRIDGE_INSTALLATION_ID': installInstanceId,
        'DSHA_BRIDGE_APPLICATION_ID': applicationId,
      };

  @override
  String toString() =>
      'BridgeConnectionDescriptor{applicationId=$applicationId,generation=$generation,port=$port,state=ready}';
}

/// 常时比较（长度差异也走满比较循环，不提前返回）。
bool constantTimeEquals(String a, String b) {
  final left = a.codeUnits;
  final right = b.codeUnits;
  var diff = left.length ^ right.length;
  final max = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < max; i++) {
    diff |= (i < left.length ? left[i] : 0) ^ (i < right.length ? right[i] : 0);
  }
  return diff == 0;
}
