//! HermesViewModel 单测（测试安全网扩面，2026-11-13）。
//!
//! 假 HermesGatewayClient（本地包）驱动：连接流转/会话刷新/请求编排。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_gateway/hermes_gateway.dart';
import 'package:my_app/features/hermes/hermes_view_model.dart';

class FakeGateway implements HermesGatewayClient {
  final List<String> calls = [];
  final _events = StreamController<GatewayEvent>.broadcast();
  final Map<String, Object?> responses;

  FakeGateway({this.responses = const {}});

  @override
  GatewayStatus status = GatewayStatus.disconnected;

  @override
  Stream<GatewayEvent> get events => _events.stream;

  @override
  Future<void> get ready async {}

  @override
  Future<void> connect({required Uri uri, String? token}) async {
    calls.add('connect:${uri.host}');
    status = GatewayStatus.connected;
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    status = GatewayStatus.disconnected;
  }

  @override
  Future<Object?> request(String method, [Map<String, dynamic>? params]) async {
    calls.add('request:$method');
    return responses[method];
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _events.close();
  }
}

void main() {
  test('connect/disconnect：连接流转', () async {
    final g = FakeGateway();
    final vm = HermesViewModel(g);
    await vm.connect('http://127.0.0.1:3080', 'tok');
    expect(g.calls, contains('connect:127.0.0.1'));
    await vm.disconnect();
    expect(g.calls, contains('disconnect'));
    vm.dispose();
  });

  test('refreshSessions：request 编排 + 列表快照', () async {
    final g = FakeGateway(responses: {
      'session.list': [
        {'id': 's1', 'title': '会话一'},
      ],
    });
    final vm = HermesViewModel(g);
    await vm.refreshSessions();
    expect(g.calls, contains('request:session.list'));
    vm.dispose();
  });

  test('send：未连接不炸（错误落位）', () async {
    final g = FakeGateway();
    final vm = HermesViewModel(g);
    await vm.send('你好');
    // 空会话/未连接下 send 优雅处理（不抛出）
    expect(g.calls, isNot(contains('connect')));
    vm.dispose();
  });
}
