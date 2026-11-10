// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VscreenBridgeRequest —— 现代化重构，行为契约不变。
//! 实际虚拟屏 HTTP 文法、body 预算与操作派发；不依赖 Android API。
//! 错误契约（逐字）：`UNKNOWN_ROUTE`/`UNKNOWN_ARGUMENT`/`DUPLICATE_ARGUMENT`/
//! `INVALID_ARGUMENT_ENCODING`/`INVALID_ARGUMENT_TYPE`/`INVALID_<参数名>`/
//! `INVALID_EDITOR_OPERATION`/`ANCHORED_MODE_UNAVAILABLE`/`VSCREEN_QUERY_LIMIT`/
//! `VSCREEN_POST_ROUTE`/`VSCREEN_POST_QUERY_AMBIGUOUS`/`VSCREEN_BODY_LENGTH_REQUIRED`/
//! `VSCREEN_BODY_LIMIT`/`VSCREEN_JSON_REQUIRED`/`VSCREEN_BODY_DEADLINE`/
//! `VSCREEN_BODY_TRUNCATED`/`VSCREEN_BODY_UTF8`/`VSCREEN_BODY_JSON`。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'core_identity.dart' show vscreenUuidPattern;
import 'manager_support.dart' show VscreenRoutes;

// int64 上界：web（JS double）编译不接受 >2^53 的整数字面量，
// 运行时解析绕开（web 端 vscreen 不实用此值，仅校验范围）。
final int _int64Max = int.parse('7fffffffffffffff', radix: 16);

/// HTTP 协议失败（原版 `HttpProtocol.Failure`：状态码 + 稳定码）。
class BridgeRequestFailure implements Exception {
  BridgeRequestFailure(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'BridgeRequestFailure($status, $code)';
}

/// body 预算（原版常量）。
const int vscreenMaxBody = 128 * 1024;
const int vscreenBodyTimeoutMs = 10000;

/// 操作枚举（原版 `Operation`）。
enum VscreenOperation {
  create,
  status,
  launch,
  tree,
  node,
  editor,
  edit,
  submit,
  touch,
  preview,
  see,
  anchor,
  anchoredClick,
  tap,
  swipe,
  key,
  type,
  close,
}

/// 动作面（原版 `Actions<T>`）。
abstract class VscreenBridgeActions<T> {
  T create(String orientation);

  T status();

  T launch(String pkg);

  T tree();

  T node(String generation, int frame, String id, String action, String text);

  T editor(String generation, String mode, String editorId, String text, int start, int end);

  T touch(String generation, int frame, String stroke, int action, double x, double y);

  T preview();

  T see() => preview();

  T anchor(String generation, int frame, String observation, int x, int y) {
    throw StateError('ANCHORED_MODE_UNAVAILABLE');
  }

  T anchoredClick(String generation, int frame, String anchor) {
    throw StateError('ANCHORED_MODE_UNAVAILABLE');
  }

  T action(String mode, String generation, int frame, String query);

  T type(String generation, int frame, String text);

  T close();
}

/// 虚拟屏桥请求（原版 `VscreenBridgeRequest`）。
class VscreenBridgeRequest {
  VscreenBridgeRequest._(this.operation, Map<String, String> parameters)
      : parameters = Map.unmodifiable(Map<String, String>.of(parameters)) {
    _validate();
  }

  final VscreenOperation operation;
  final Map<String, String> parameters;

  /// POST 路由表（原版 `postRoute`）。
  static bool postRoute(String route) => const {
        '/app/vscreen/edit',
        '/app/vscreen/submit',
        '/app/vscreen/node',
        '/app/vscreen/type',
        '/app/vscreen/anchor',
        '/app/vscreen/anchored-click',
      }.contains(route);

  /// body 收取（原版 `readPost` 主体；HTTP 头解析留缝）。
  /// [bodyLength] 为 Content-Length（FIXED），[input] 为字节流。
  static Future<List<int>> readPostBody({
    required int bodyLength,
    required List<String> contentType,
    required String contentEncoding,
    required Stream<List<int>> input,
    void Function()? writeContinue,
  }) async {
    if (bodyLength < 1) throw BridgeRequestFailure(411, 'VSCREEN_BODY_LENGTH_REQUIRED');
    if (bodyLength > vscreenMaxBody) throw BridgeRequestFailure(413, 'VSCREEN_BODY_LIMIT');
    if (contentType.length != 1 ||
        !RegExp(r'^application/json(?:\s*;\s*charset=utf-8)?$', caseSensitive: false)
            .hasMatch(contentType[0]) ||
        contentEncoding.isNotEmpty) {
      throw BridgeRequestFailure(415, 'VSCREEN_JSON_REQUIRED');
    }
    writeContinue?.call();
    final output = BytesBuilder();
    await for (final chunk in input) {
      output.add(chunk);
      if (output.length > bodyLength) break;
    }
    final bytes = output.toBytes();
    if (bytes.length < bodyLength) throw BridgeRequestFailure(400, 'VSCREEN_BODY_TRUNCATED');
    try {
      const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException {
      throw BridgeRequestFailure(400, 'VSCREEN_BODY_UTF8');
    }
    return bytes;
  }

  /// JSON body 构造（原版 `json`）。
  static VscreenBridgeRequest json(String route, Map<String, Object?> body) {
    final values = <String, String>{};
    for (final entry in body.entries) {
      final numeric = const {
            'frameSeq',
            'x',
            'y',
            'x1',
            'y1',
            'x2',
            'y2',
            'ms',
            'start',
            'end',
            'keycode',
          }.contains(entry.key) ||
          (entry.key == 'action' && route == '/app/vscreen/touch');
      final value = entry.value;
      if (numeric ? value is! num : value is! String) {
        throw BridgeRequestFailure(400, 'INVALID_ARGUMENT_TYPE');
      }
      values[entry.key] = '$value';
    }
    return _create(route, values);
  }

  /// query 构造（原版 `query`）。
  static VscreenBridgeRequest query(String route, String query) {
    if (query.length > 512 * 1024) throw BridgeRequestFailure(413, 'VSCREEN_QUERY_LIMIT');
    final values = <String, String>{};
    for (final pair in query.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      try {
        final key = Uri.decodeQueryComponent(eq >= 0 ? pair.substring(0, eq) : pair);
        final value =
            Uri.decodeQueryComponent(eq >= 0 ? pair.substring(eq + 1) : '');
        if (values.containsKey(key)) {
          throw BridgeRequestFailure(400, 'DUPLICATE_ARGUMENT');
        }
        values[key] = value;
      } on ArgumentError {
        throw BridgeRequestFailure(400, 'INVALID_ARGUMENT_ENCODING');
      }
    }
    return _create(route, values);
  }

  static VscreenBridgeRequest _create(String route, Map<String, String> values) {
    var name = VscreenRoutes.operation(route);
    if (name.isEmpty) throw BridgeRequestFailure(404, 'UNKNOWN_ROUTE');
    // 旧 MCP editor 端点读兼容，但不能把 edit/submit 误当 get。
    if (name == 'editor') {
      final op = values['operation'] ?? values['op'] ?? 'get';
      if (values.containsKey('op') &&
          values.containsKey('operation') &&
          values['op'] != values['operation']) {
        throw BridgeRequestFailure(400, 'INVALID_EDITOR_OPERATION');
      }
      if (!const {'get', 'edit', 'submit'}.contains(op)) {
        throw BridgeRequestFailure(400, 'INVALID_EDITOR_OPERATION');
      }
      name = op == 'get' ? 'editor' : op;
      values.remove('operation');
      values.remove('op');
    }
    final operation = VscreenOperation.values.asNameMap()[name];
    if (operation == null) throw BridgeRequestFailure(404, 'UNKNOWN_ROUTE');
    return VscreenBridgeRequest._(operation, values);
  }

  String route() => '/app/vscreen/${operation.name.replaceAll('_', '-')}';

  String queryText() => parameters.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  /// 派发（原版 `execute`）。
  T execute<T>(VscreenBridgeActions<T> actions) {
    final gen = _value('generation', ''), text = _value('text', '');
    final frame = _number('frameSeq', -1);
    switch (operation) {
      case VscreenOperation.create:
        return actions.create(_value('orientation', 'portrait'));
      case VscreenOperation.status:
        return actions.status();
      case VscreenOperation.launch:
        return actions.launch(_value('package', ''));
      case VscreenOperation.tree:
        return actions.tree();
      case VscreenOperation.node:
        return actions.node(
            gen, frame, _value('nodeId', ''), _value('action', ''), text);
      case VscreenOperation.editor:
        return actions.editor(gen, 'editor', '', '', 0, 0);
      case VscreenOperation.edit:
        return actions.editor(
            gen,
            'edit',
            _value('editorId', ''),
            text,
            _number('start', text.length),
            _number('end', _number('start', text.length)));
      case VscreenOperation.submit:
        return actions.editor(gen, 'submit', _value('editorId', ''), '', 0, 0);
      case VscreenOperation.touch:
        return actions.touch(
            gen,
            frame,
            _value('stroke', ''),
            _number('action', -1),
            double.parse(_value('x', '0')),
            double.parse(_value('y', '0')));
      case VscreenOperation.preview:
        return actions.preview();
      case VscreenOperation.see:
        return actions.see();
      case VscreenOperation.anchor:
        return actions.anchor(gen, frame, _value('observationId', ''),
            _number('x', -1), _number('y', -1));
      case VscreenOperation.anchoredClick:
        return actions.anchoredClick(gen, frame, _value('anchorId', ''));
      case VscreenOperation.tap:
      case VscreenOperation.swipe:
      case VscreenOperation.key:
        return actions.action(operation.name, gen, frame, queryText());
      case VscreenOperation.type:
        return actions.type(gen, frame, text);
      case VscreenOperation.close:
        return actions.close();
    }
  }

  /// 解析与活状态无关；必需调用方证据由 manager 强制（原版 `requiresExistingCore`）。
  bool requiresExistingCore() =>
      operation != VscreenOperation.create &&
      operation != VscreenOperation.status &&
      operation != VscreenOperation.close;

  String _value(String name, String fallback) => parameters[name] ?? fallback;

  int _number(String name, int fallback) =>
      parameters.containsKey(name) ? int.parse(parameters[name]!) : fallback;

  void _need(String name, int length) {
    final value = parameters[name];
    if (value == null || value.isEmpty || value.length > length) {
      throw BridgeRequestFailure(400, 'INVALID_$name');
    }
  }

  void _integer(String name, int min, int max, bool required) {
    if (!parameters.containsKey(name)) {
      if (required) throw BridgeRequestFailure(400, 'INVALID_$name');
      return;
    }
    try {
      final value = int.parse(parameters[name]!);
      if (value < min || value > max) throw FormatException();
    } on FormatException {
      throw BridgeRequestFailure(400, 'INVALID_$name');
    }
  }

  void _coordinate(String name) {
    _need(name, 80);
    try {
      final value = double.parse(parameters[name]!);
      if (value.isNaN || value.isInfinite || value < 0) throw FormatException();
    } on FormatException {
      throw BridgeRequestFailure(400, 'INVALID_$name');
    }
  }

  void _validate() {
    final allowed = <String>{'coreInstance'};
    if (parameters.containsKey('coreInstance') &&
        !RegExp('^$vscreenUuidPattern\$').hasMatch(_value('coreInstance', ''))) {
      throw BridgeRequestFailure(400, 'INVALID_coreInstance');
    }
    switch (operation) {
      case VscreenOperation.create:
        allowed.add('orientation');
        if (!const {'portrait', 'landscape'}.contains(_value('orientation', 'portrait'))) {
          throw BridgeRequestFailure(400, 'INVALID_orientation');
        }
      case VscreenOperation.launch:
        allowed.add('package');
        _need('package', 160);
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$')
            .hasMatch(parameters['package']!)) {
          throw BridgeRequestFailure(400, 'INVALID_package');
        }
      case VscreenOperation.status:
      case VscreenOperation.tree:
      case VscreenOperation.preview:
      case VscreenOperation.see:
      case VscreenOperation.close:
        break;
      case VscreenOperation.anchor:
      case VscreenOperation.anchoredClick:
        allowed.addAll(const ['generation', 'frameSeq']);
        _need('coreInstance', 36);
        _need('generation', 80);
        _integer('frameSeq', 1, 9007199254740991, true);
        final token =
            operation == VscreenOperation.anchor ? 'observationId' : 'anchorId';
        allowed.add(token);
        _need(token, 36);
        if (!RegExp('^$vscreenUuidPattern\$').hasMatch(_value(token, ''))) {
          throw BridgeRequestFailure(400, 'INVALID_$token');
        }
        if (operation == VscreenOperation.anchor) {
          allowed.addAll(const ['x', 'y']);
          _integer('x', 0, 0x7fffffff, true);
          _integer('y', 0, 0x7fffffff, true);
        }
      case VscreenOperation.editor:
      case VscreenOperation.edit:
      case VscreenOperation.submit:
        allowed.addAll(const ['generation', 'editorId', 'text', 'start', 'end']);
        _need('generation', 80);
        if (operation != VscreenOperation.editor) _need('editorId', 160);
        if (operation == VscreenOperation.edit) {
          if (!parameters.containsKey('text') || parameters['text']!.length > 16000) {
            throw BridgeRequestFailure(400, 'INVALID_text');
          }
          _integer('start', 0, parameters['text']!.length, false);
          _integer('end', 0, parameters['text']!.length, false);
        }
      default:
        allowed.addAll(const ['generation', 'frameSeq']);
        _need('generation', 80);
        // node 走无障碍 performAction：目标是否还活着由无障碍层树新鲜度决定，与"当前第几帧"
        // 无关，因此帧号对它是可选的（issue #117）；坐标与文本输入仍必填。
        _integer('frameSeq', 1, _int64Max, operation != VscreenOperation.node);
        if (operation == VscreenOperation.node) {
          allowed.addAll(const ['nodeId', 'action', 'text']);
          _need('nodeId', 80);
          if (!const {
            'click',
            'long_click',
            'scroll_forward',
            'scroll_backward',
            'focus',
            'set_text',
          }.contains(_value('action', ''))) {
            throw BridgeRequestFailure(400, 'INVALID_action');
          }
          if ((_value('action', '') == 'set_text' && !parameters.containsKey('text')) ||
              _value('text', '').length > 16000) {
            throw BridgeRequestFailure(400, 'INVALID_text');
          }
        } else if (operation == VscreenOperation.type) {
          allowed.add('text');
          _need('text', 2000);
        } else if (operation == VscreenOperation.key) {
          allowed.add('keycode');
          _integer('keycode', 0, 100, true);
          if (!const {'3', '4', '66', '67'}.contains(_value('keycode', ''))) {
            throw BridgeRequestFailure(400, 'INVALID_keycode');
          }
        } else if (operation == VscreenOperation.tap) {
          allowed.addAll(const ['x', 'y']);
          _coordinate('x');
          _coordinate('y');
        } else if (operation == VscreenOperation.swipe) {
          allowed.addAll(const ['x1', 'y1', 'x2', 'y2', 'ms']);
          for (final key in const ['x1', 'y1', 'x2', 'y2']) _coordinate(key);
          _integer('ms', 50, 3000, false);
        } else if (operation == VscreenOperation.touch) {
          allowed.addAll(const ['stroke', 'action', 'x', 'y']);
          _need('stroke', 64);
          if (!RegExp(r'^[a-f0-9-]{16,64}$').hasMatch(_value('stroke', ''))) {
            throw BridgeRequestFailure(400, 'INVALID_stroke');
          }
          _integer('action', 0, 3, true);
          _coordinate('x');
          _coordinate('y');
        }
    }
    if (!allowed.containsAll(parameters.keys)) {
      throw BridgeRequestFailure(400, 'UNKNOWN_ARGUMENT');
    }
    if (parameters.containsKey('text') && parameters['text']!.length > 16000) {
      throw BridgeRequestFailure(400, 'INVALID_text');
    }
  }
}
