// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.BridgeHandshake —— 现代化重构，行为契约不变。
//! 域分离 HMAC 证明；挑战两端都不携带凭据。
//! 错误契约：`BRIDGE_NONCE_INVALID` / `BRIDGE_BODY_HASH_INVALID`。
library;

import 'dart:math';

import 'package:crypto/crypto.dart';

import 'bridge_connection_descriptor.dart'
    show BridgeConnectionDescriptor, constantTimeEquals;

/// 挑战端点路径（契约常量）。
const String bridgeChallengePath = '/bridge/challenge';

final Random _random = Random.secure();

/// 32 字节随机数（64 位十六进制）。
String bridgeNonce() {
  final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
  return _hex(bytes);
}

/// nonce / bodyHash 格式门（64 位小写十六进制）。
bool bridgeNonceValid(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

String _identity(BridgeConnectionDescriptor d, String client, String server) {
  if (!bridgeNonceValid(client) || !bridgeNonceValid(server)) {
    throw ArgumentError('BRIDGE_NONCE_INVALID');
  }
  return [
    d.applicationId,
    d.installInstanceId,
    d.bridgeRunId,
    d.generation.toString(),
    d.baseUrl(),
    client,
    server,
  ].join('\n');
}

/// 服务端证明：`DSHA-BRIDGE-SERVER/1\n<identity>`。
String bridgeServerProof(
    BridgeConnectionDescriptor d, String client, String server) {
  return bridgeHmac(
      d.credentialHeader(), 'DSHA-BRIDGE-SERVER/1\n${_identity(d, client, server)}');
}

/// 客户端证明：`DSHA-BRIDGE-CLIENT/1\n<identity>\n<method>\n<target>\n<bodyHash>`。
String bridgeClientProof(
  BridgeConnectionDescriptor d,
  String client,
  String server,
  String method,
  String target,
  String bodyHash,
) {
  if (!bridgeNonceValid(bodyHash)) {
    throw ArgumentError('BRIDGE_BODY_HASH_INVALID');
  }
  return bridgeHmac(
    d.credentialHeader(),
    'DSHA-BRIDGE-CLIENT/1\n${_identity(d, client, server)}\n$method\n$target\n$bodyHash',
  );
}

/// HmacSHA256（key=US-ASCII，value=UTF-8），返回小写十六进制。
String bridgeHmac(String key, String value) {
  final digest = Hmac(sha256, key.codeUnits).convert(value.codeUnits);
  return _hex(digest.bytes);
}

/// SHA-256 小写十六进制。
String bridgeSha(List<int> bytes) => _hex(sha256.convert(bytes).bytes);

/// 证明比对：先过格式门，再常时比较（原版 `MessageDigest.isEqual`）。
bool bridgeMatches(String expected, String supplied) {
  return bridgeNonceValid(expected) &&
      bridgeNonceValid(supplied) &&
      constantTimeEquals(expected, supplied);
}

String _hex(List<int> bytes) {
  final value = StringBuffer();
  for (final b in bytes) {
    value.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return value.toString();
}
