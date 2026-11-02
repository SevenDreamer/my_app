//! Core HTTP 传输实现（原版 `VirtualScreenTransport`：裸 Socket GET + peer proof）。
//!
//! 契约逐字：Header `X-DSHA-VScreen-Proof` 带 `clientProof("GET", target)`；
//! route 白名单 `/vscreen/[a-z]+` 或 observation 两路由；target ≤ 24,000；
//! 响应铁律（Content-Length 单值、禁 Transfer/Content-Encoding、401 容许、
//! MAX_RESPONSE 4 MiB、RESPONSE_DEADLINE_MS 12s 总预算——deadline 机制）。
//! 裸 Socket 而非 HttpClient：防 EOF 后透明重试（原版注释契约）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'manager.dart';
import 'peer_proof.dart';
import 'vscreen_handshake.dart';

class HttpTransport implements VscreenTransportApi {
  HttpTransport(
      {required this.applicationId, this.responseDeadlineMs = 12000});

  static const int _maxResponse = 4 * 1024 * 1024;
  static const String _proofHeader = 'X-DSHA-VScreen-Proof';
  final int responseDeadlineMs;

  /// 应用身份（原版 `AppIdentity.applicationId()`，装配层注入）。
  final String applicationId;

  @override
  Future<Map<String, Object?>> request(
      VscreenHandshake endpoint, String route, String query) async {
    final observationRoute = route == '/vscreen/observation-release' ||
        route == '/vscreen/observation-region';
    final target =
        query.isEmpty ? route : '$route?${Uri.encodeFull(query)}';
    if ((!RegExp(r'^/vscreen/[a-z]+$').hasMatch(route) && !observationRoute) ||
        target.length > 24000) {
      return _fail('VSCREEN_REQUEST_TARGET_INVALID');
    }
    for (int i = 0; i < target.length; i++) {
      final c = target.codeUnitAt(i);
      if (c <= 32 || c >= 127 || c == 0x23) {
        return _fail('VSCREEN_REQUEST_TARGET_INVALID');
      }
    }
    if (!RegExp(r'^[!-~]{1,256}$').hasMatch(endpoint.token)) {
      return _fail('VSCREEN_REQUEST_TOKEN_INVALID');
    }
    final deadlineMs = responseDeadlineMs;
    Socket? socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv4, endpoint.port,
          timeout: Duration(milliseconds: deadlineMs));
      // 同 socket 先 peer 握手（原版：VirtualScreenPeerProof.client(socket, endpoint)），
      // 再发 HTTP GET（带 session.clientProof）。
      final peer = await vscreenPeerClient(
        socket,
        token: endpoint.token,
        identityEncoded: endpoint.identity.encode(),
        port: endpoint.port,
        applicationId: applicationId,
      );
      final proof = peer.clientProof('GET', target);
      socket.write('GET $target HTTP/1.1\r\n'
          'Host: 127.0.0.1:${endpoint.port}\r\n'
          '$_proofHeader: $proof\r\n'
          'Connection: close\r\n\r\n');
      await socket.flush();
      final buffer = BytesBuilder(copy: false);
      await for (final chunk
          in socket.timeout(Duration(milliseconds: deadlineMs), onTimeout: (sink) {
        sink.close();
        throw const SocketException('RESPONSE_DEADLINE');
      })) {
        buffer.add(chunk);
        if (buffer.length > _maxResponse + 65536) {
          throw const HttpException('MAX_RESPONSE');
        }
      }
      return _parse(buffer.takeBytes());
    } on SocketException catch (e) {
      if (e.message == 'RESPONSE_DEADLINE') return _fail('VSCREEN_CORE_TIMEOUT');
      return _fail('VSCREEN_CORE_UNREACHABLE');
    } on HttpException catch (e) {
      return _fail(e.message == 'MAX_RESPONSE'
          ? 'VSCREEN_RESPONSE_TOO_LARGE'
          : 'VSCREEN_BAD_RESPONSE');
    } catch (_) {
      return _fail('VSCREEN_BAD_RESPONSE');
    } finally {
      socket?.destroy();
    }
  }

  Map<String, Object?> _parse(List<int> raw) {
    final text = latin1.decode(raw, allowInvalid: true);
    final sep = text.indexOf('\r\n\r\n');
    if (sep < 0) return _fail('VSCREEN_BAD_RESPONSE');
    final head = text.substring(0, sep);
    final lines = head.split('\r\n');
    if (lines.isEmpty) return _fail('VSCREEN_BAD_RESPONSE');
    final status = lines.first.split(' ');
    if (status.length < 2) return _fail('VSCREEN_BAD_RESPONSE');
    final code = int.tryParse(status[1]) ?? 0;
    // 响应铁律：Content-Length 单值、禁 Transfer/Content-Encoding。
    int? length;
    for (final line in lines.skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) return _fail('VSCREEN_BAD_RESPONSE');
      final name = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      if (name == 'transfer-encoding' || name == 'content-encoding') {
        return _fail('VSCREEN_BAD_RESPONSE');
      }
      if (name == 'content-length') {
        if (length != null) return _fail('VSCREEN_BAD_RESPONSE'); // 单值
        length = int.tryParse(value);
        if (length == null) return _fail('VSCREEN_BAD_RESPONSE');
      }
    }
    if (code == 401) return _fail('VSCREEN_CORE_FORBIDDEN');
    if (code != 200) return _fail('VSCREEN_CORE_BAD_STATUS');
    final body = raw.sublist(sep + 4);
    if (length != null && body.length != length) {
      return _fail('VSCREEN_BAD_RESPONSE');
    }
    if (body.length > _maxResponse) return _fail('VSCREEN_RESPONSE_TOO_LARGE');
    try {
      final decoded = jsonDecode(utf8.decode(body));
      return decoded is Map<String, Object?>
          ? decoded
          : _fail('VSCREEN_BAD_RESPONSE');
    } catch (_) {
      return _fail('VSCREEN_BAD_RESPONSE');
    }
  }

  Map<String, Object?> _fail(String code) =>
      {'ok': false, 'error': code};
}
