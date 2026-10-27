// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenPeerProof —— 现代化重构，行为契约不变。
//! 同连接对端证明：复用桥 HMAC 原语（`BridgeHandshake.hmac/sha/nonce/nonceValid/matches`），
//! 线上不携带凭据。行协议逐字：`DSHA_VSCREEN_HELLO 1 <nonce>` / `DSHA_VSCREEN_PROOF 1 <nonce> <proof>`。
//! 错误契约（逐字）：`VSCREEN_PEER_UNPROVEN` / `VSCREEN_PEER_TIMEOUT` /
//! `VSCREEN_PEER_LINE_INVALID` / `VSCREEN_PEER_LINE_LIMIT`。
library;

import 'dart:async';
import 'dart:io';

import '../bridge/bridge_handshake.dart'
    show
        bridgeHmac,
        bridgeMatches,
        bridgeNonce,
        bridgeNonceValid,
        bridgeSha;

/// 契约常量（原版 `HEADER`；HTTP 证据头名）。
const String vscreenProofHeader = 'X-DSHA-VScreen-Proof';

/// 对端证明失败（消息即错误代号，对应原版 `IOException(code)`）。
class VscreenPeerException implements Exception {
  VscreenPeerException(this.code);

  final String code;

  @override
  String toString() => 'VscreenPeerException: $code';
}

/// 会话证明（原版 `Session`）。
class VscreenPeerSession {
  VscreenPeerSession({
    required this.token,
    required this.identityEncoded,
    required this.port,
    required this.applicationId,
    required this.client,
    required this.server,
  });

  /// 接线缝：`VirtualScreenHandshake` 的 token / `identity.encode()` / 端口。
  final String token;
  final String identityEncoded;
  final int port;
  final String applicationId;
  final String client;
  final String server;

  String identity() =>
      '$applicationId\n1\nhttp://127.0.0.1:$port\n$identityEncoded\n$client\n$server';

  String serverProof() =>
      bridgeHmac(token, 'DSHA-VSCREEN-SERVER/1\n${identity()}');

  String clientProof(String method, String target) => bridgeHmac(
        token,
        'DSHA-VSCREEN-CLIENT/1\n${identity()}\n$method\n$target\n${bridgeSha(const [])}',
      );

  bool authorizes(String method, String target, String proof) =>
      bridgeMatches(clientProof(method, target), proof);
}

/// 客户端握手（原版 `client(Socket, endpoint)`）。
Future<VscreenPeerSession> vscreenPeerClient(
  Socket socket, {
  required String token,
  required String identityEncoded,
  required int port,
  required String applicationId,
}) async {
  final client = bridgeNonce();
  await _write(socket, 'DSHA_VSCREEN_HELLO 1 $client');
  final reply = (await _readPeerLine(socket)).split(' ');
  if (reply.length != 4 ||
      reply[0] != 'DSHA_VSCREEN_PROOF' ||
      reply[1] != '1' ||
      !bridgeNonceValid(reply[2])) {
    throw VscreenPeerException('VSCREEN_PEER_UNPROVEN');
  }
  final session = VscreenPeerSession(
    token: token,
    identityEncoded: identityEncoded,
    port: port,
    applicationId: applicationId,
    client: client,
    server: reply[2],
  );
  if (!bridgeMatches(session.serverProof(), reply[3])) {
    throw VscreenPeerException('VSCREEN_PEER_UNPROVEN');
  }
  return session;
}

/// 服务端握手（原版 `server(Socket, endpoint)`）。
Future<VscreenPeerSession> vscreenPeerServer(
  Socket socket, {
  required String token,
  required String identityEncoded,
  required int port,
  required String applicationId,
}) async {
  final hello = (await _readPeerLine(socket)).split(' ');
  if (hello.length != 3 ||
      hello[0] != 'DSHA_VSCREEN_HELLO' ||
      hello[1] != '1' ||
      !bridgeNonceValid(hello[2])) {
    throw VscreenPeerException('VSCREEN_PEER_UNPROVEN');
  }
  final session = VscreenPeerSession(
    token: token,
    identityEncoded: identityEncoded,
    port: port,
    applicationId: applicationId,
    client: hello[2],
    server: bridgeNonce(),
  );
  await _write(
      socket, 'DSHA_VSCREEN_PROOF 1 ${session.server} ${session.serverProof()}');
  return session;
}

Future<void> _write(Socket socket, String value) async {
  socket.add('$value\r\n'.codeUnits); // US-ASCII（内容已限 32..126 + 格式串）
  await socket.flush();
}

/// 行读取（原版 `line(Socket)`）：总截止 3s、上限 256 字节、可打印 ASCII、CRLF。
///
/// 原版逐次 read 的 `SoTimeout` 超时抛 `SocketTimeoutException` 原样上抛；
/// 此处同位抛 [TimeoutException]。总截止耗尽才抛 `VSCREEN_PEER_TIMEOUT`。
Future<String> _readPeerLine(Socket socket) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  final iterator = StreamIterator<int>(socket.expand((chunk) => chunk));
  final text = <int>[];
  while (text.length < 256) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw VscreenPeerException('VSCREEN_PEER_TIMEOUT');
    }
    int value;
    try {
      if (!await iterator.moveNext().timeout(remaining)) {
        throw VscreenPeerException('VSCREEN_PEER_LINE_INVALID'); // 原版 read() 返回 -1
      }
      value = iterator.current;
    } on TimeoutException {
      rethrow; // 原版 SocketTimeoutException 同位
    }
    if (value == 13 /* '\r' */) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw VscreenPeerException('VSCREEN_PEER_TIMEOUT');
      }
      try {
        if (!await iterator.moveNext().timeout(remaining) ||
            iterator.current != 10 /* '\n' */) {
          throw VscreenPeerException('VSCREEN_PEER_LINE_INVALID');
        }
      } on TimeoutException {
        rethrow;
      }
      return String.fromCharCodes(text);
    }
    if (value < 32 || value > 126) {
      throw VscreenPeerException('VSCREEN_PEER_LINE_INVALID');
    }
    text.add(value);
  }
  throw VscreenPeerException('VSCREEN_PEER_LINE_LIMIT');
}
