// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenCore —— 现代化重构，行为契约不变。
//! 独立 shell/root 进程，只接受认证后的固定虚拟屏操作。
//! 服务面：绑定/接客/对端证明/HTTP 头解析/12 路由/显示创建/输入编排。
//! 错误契约（逐字）：`CORE_ALREADY_BOUND`/`UNAUTHORIZED`/`VSCREEN_NOT_CREATED`/
//! `VSCREEN_TARGET_UNVERIFIABLE`/`VSCREEN_TARGET_CHANGED`/`STALE_GENERATION`/
//! `INVALID_STROKE`/`INVALID_TOUCH`/`INVALID_DURATION`/`INVALID_KEY`/`INVALID_TEXT`/
//! `ACCESSIBILITY_REQUIRED_FOR_UNICODE`/`UNKNOWN_ROUTE`/`INVALID_ARGUMENT`/
//! `DISPLAY_ADAPTER_FACTS_INVALID`/`DISPLAY_CREATE_FAILED`/`INPUT_RESULT_UNKNOWN`/
//! `INPUT_REJECTED`/`VSCREEN_INPUT_UNAVAILABLE`/`NO_LAUNCH_ACTIVITY`/
//! `LAUNCH_RESULT_UNKNOWN`/`LAUNCH_REJECTED`/`INVALID_PACKAGE`/`STALE_FRAME`/
//! `HEAD_LIMIT`/`VSCREEN_TRUSTED_DISPLAY_DENIED`/`resultMetadataUnavailable`。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'core_identity.dart';
import 'display_session.dart';
import 'failures.dart';
import 'input_policy.dart';
import 'peer_proof.dart';
import 'pixels.dart';
import 'policy.dart';
import 'support.dart';
import 'vscreen_handshake.dart';

/// 宿主显示工厂（原版 `DisplayFactory`；宿主夹具只替换平台事实）。
typedef VscreenDisplayFactory = VscreenDisplaySession Function(int width, int height);

/// 系统执行面（原版 `ProcessBuilder` exec 段；缝）。
class VscreenExecResult {
  const VscreenExecResult(this.exit, this.text, this.unknown);

  final int exit;
  final String text;
  final bool unknown;
}

typedef VscreenExecFn = VscreenExecResult Function(List<String> args);

/// 前台包观察（原版 ActivityManager 反射段；缝）。
typedef VscreenForegroundPackage = String Function(int displayId);

/// 失败诊断捕获（原版 `diagnostics.Failure.capture`；缝）。
typedef VscreenFailureCapture = Map<String, Object?>? Function(
    String code, Object? error, bool displayCreation);

/// 生产显示创建缝（原版 DisplayManager/ImageReader/flag 反射段）。
abstract class VscreenDisplayCreator {
  /// 反射取 `DisplayManager` 常量；null = 查不到（登记 absent）。
  int? flagValue(String name);

  TrustedDisplayPermission trustedPermission();

  /// 固定参数创建；返回 null = `DISPLAY_CREATE_FAILED`。
  /// 抛异常走 failure 映射；自行回收半成品 ImageReader/Display（等价原版 addSuppressed 清理）。
  VscreenDisplaySession? create(int width, int height, int flags);
}

/// 宿主控制柄（原版 `HostControl`）。
class VscreenHostControl {
  VscreenHostControl._(this._server, this._bound, this.endpoint);

  final VscreenCoreServer _server;
  final ServerSocket _bound;
  final VscreenHandshake endpoint;

  VscreenHandshake handshake() => endpoint;

  /// 60s 无请求自关（原版 tick）。
  void tick() {
    if (_server._isBound(_bound) &&
        _server.elapsed() - _server._lastRequest > 60000) {
      _server.shutdown();
    }
  }

  void close() {
    _server.shutdown();
  }
}

/// Core 服务（原版 `VirtualScreenCore` 服务面）。
class VscreenCoreServer {
  VscreenCoreServer({
    required this.identity,
    required this.clock,
    required this.token,
    VscreenDisplayFactory? hostDisplayFactory,
    VscreenDisplayCreator? displayCreator,
    VscreenForegroundPackage? foregroundPackage,
    VscreenExecFn? exec,
    VscreenFailureCapture? failureCapture,
    void Function()? processExit,
  })  : hostDisplayFactory = hostDisplayFactory,
        displayCreator = displayCreator,
        foregroundPackage = foregroundPackage,
        _exec = exec ?? _unavailableExec,
        _failureCapture = failureCapture,
        _processExit = processExit ?? _defaultExit;

  final VscreenCoreIdentityLike identity;
  final VscreenClock clock;
  final String token;
  final VscreenDisplayFactory? hostDisplayFactory;
  final VscreenDisplayCreator? displayCreator;
  final VscreenForegroundPackage? foregroundPackage;
  final VscreenExecFn _exec;
  final VscreenFailureCapture? _failureCapture;
  final void Function() _processExit;

  VscreenDisplaySession? session;
  bool running = true;
  String startupStage = 'CONTEXT';
  String missingDisplayFlags = '';
  int _lastRequest = 0;
  ServerSocket? _server;

  static void _defaultExit() {}
  static VscreenExecResult _unavailableExec(List<String> args) =>
      const VscreenExecResult(-1, '', true);

  int elapsed() => clock.millis();

  bool _isBound(ServerSocket bound) => identical(_server, bound);

  /// 宿主夹具绑定（原版 `bindControlForHost`）。
  Future<VscreenHostControl> bindControl({
    InternetAddress? bindAddress,
    int port = 0,
  }) async {
    if (_server != null) {
      throw FileSystemException('CORE_ALREADY_BOUND');
    }
    _lastRequest = elapsed();
    _server = await ServerSocket.bind(bindAddress ?? InternetAddress.loopbackIPv4, port,
        shared: false);
    final endpoint = VscreenHandshake(_server!.port, token, identity.birth);
    _startAcceptLoop(endpoint);
    return VscreenHostControl._(this, _server!, endpoint);
  }

  void _startAcceptLoop(VscreenHandshake endpoint) {
    final bound = _server!;
    bound.listen((socket) {
      // 原版线程池 2..4 + 队列 8：满员即拒接（等价上限 12 在飞）。
      if (_inflight >= 12) {
        socket.destroy();
        return;
      }
      _inflight++;
      _handle(socket, bound).whenComplete(() => _inflight--);
    }, onError: (_) {
      shutdown();
    });
  }

  int _inflight = 0;

  /// 连接处理（原版 `handle`）：对端证明 → HTTP 头 → 授权 → 路由 → 回包。
  Future<void> _handle(Socket accepted, ServerSocket bound) async {
    var close = false;
    try {
      final deadline = elapsed() + 3000;
      final peer = await vscreenPeerServer(
        accepted,
        token: token,
        identityEncoded: identity.birth.encode(),
        port: bound.port,
        applicationId: identity.applicationId(),
      );
      final bytes = StreamIterator<int>(accepted.expand((chunk) => chunk));
      final requestLine = await _line(bytes, 24576, deadline);
      final parts = _splitN(requestLine, ' ', 3);
      if (parts.length != 3 || parts[0] != 'GET') return;
      var authorization = '';
      var remaining = 32768;
      for (;;) {
        final header = await _line(bytes, min(remaining, 4096), deadline);
        remaining -= header.length + 2;
        if (header.isEmpty) break;
        if (remaining <= 0) throw FileSystemException('HEAD_LIMIT');
        if (header.toLowerCase().startsWith('${vscreenProofHeader.toLowerCase()}:')) {
          authorization = header.substring(vscreenProofHeader.length + 1).trim();
        }
      }
      final authorized = peer.authorizes(parts[0], parts[1], authorization);
      final path = parts[1].split('?')[0];
      late Map<String, Object?> result;
      if (!authorized) {
        result = _error('UNAUTHORIZED');
      } else {
        if (!running || !identical(_server, bound)) return;
        _lastRequest = elapsed();
        result = route(path, _query(parts[1]));
        close = path == '/vscreen/close';
      }
      final body = utf8.encode(jsonEncode(result));
      accepted.add(utf8.encode('HTTP/1.1 ${authorized ? '200 OK' : '401 Unauthorized'}\r\n'
          'Content-Type: application/json\r\n'
          'Content-Length: ${body.length}\r\n'
          'Connection: close\r\n\r\n'));
      accepted.add(body);
      await accepted.flush();
    } catch (e) {
      // 原版吞掉一切连接级异常。
    } finally {
      accepted.destroy();
      if (close) shutdown();
    }
  }

  /// 路由表（原版 `route`；单 isolate 同步执行＝原版类锁语义）。
  Map<String, Object?> route(String path, Map<String, String> q) {
    try {
      if (path == '/vscreen/ping') return _ok();
      if (path == '/vscreen/create') {
        return create(int.parse(q['width'] ?? '1008'), int.parse(q['height'] ?? '1792'));
      }
      if (path == '/vscreen/status') return status();
      if (path == '/vscreen/close') {
        release();
        return _ok();
      }
      if (session == null) return _error('VSCREEN_NOT_CREATED');
      final expected = q['expectedPackage'] ?? '';
      if (expected.isNotEmpty) {
        final actual = currentPackage();
        if (actual.isEmpty) return _error('VSCREEN_TARGET_UNVERIFIABLE');
        if (expected != actual) return _error('VSCREEN_TARGET_CHANGED');
      }
      if (path == '/vscreen/launch') return launchPackage(q['package']);
      if (path == '/vscreen/preview') {
        return preview(int.parse(q['since'] ?? '-1'), q['generation']);
      }
      if (path == '/vscreen/observe') {
        if (session!.generation != q['generation']) return _error('STALE_GENERATION');
        return q['retain'] == 'true'
            ? session!.observations.capture(session!, status)
            : preview(-1, session!.generation);
      }
      if (path == '/vscreen/observation-region') {
        if (session!.generation != q['generation']) return _error('STALE_GENERATION');
        return session!.observations.region(
            session!,
            q['observationId'] ?? '',
            VscreenRect(
              int.parse(q['left'] ?? '-1'),
              int.parse(q['top'] ?? '-1'),
              int.parse(q['right'] ?? '-1'),
              int.parse(q['bottom'] ?? '-1'),
            ));
      }
      if (path == '/vscreen/observation-release') {
        session!.observations.remove(q['observationId'] ?? '');
        return _ok();
      }
      if (path == '/vscreen/touch') {
        if (session!.generation != q['generation']) return _error('STALE_GENERATION');
        final stroke = q['stroke'] ?? '';
        if (!RegExp(r'^[a-f0-9-]{16,64}$').hasMatch(stroke)) {
          return _error('INVALID_STROKE');
        }
        final action = int.parse(q['action'] ?? '-1');
        if (action < 0 || action > 3) return _error('INVALID_TOUCH');
        final x = _coordinate(q, 'x', session!.width),
            y = _coordinate(q, 'y', session!.height);
        if (action == 0) {
          final requested = int.parse(q['frameSeq'] ?? '-1');
          final rejection = VscreenPolicy.inputRejection(
              requested, session!.sequence, session!.observed, elapsed() - session!.observedAt);
          if (rejection != null) {
            return _staleFrame(rejection, requested, session!.sequence, session!.observed);
          }
          session!.observed = -1;
        }
        return _inputResult(session!.input.touch(stroke, action, x, y));
      }
      if (!const {
        '/vscreen/tap',
        '/vscreen/swipe',
        '/vscreen/type',
        '/vscreen/key',
        '/vscreen/check',
      }.contains(path)) {
        return _error('UNKNOWN_ROUTE');
      }
      final observed = int.parse(q['frameSeq'] ?? '-1');
      if (session!.generation != q['generation']) return _error('STALE_GENERATION');
      // 拒绝码只说"过期"是没用的：没看过这一帧、被新帧顶掉、观察超时是三种不同的自救方式。
      final rejection = VscreenPolicy.inputRejection(
          observed, session!.sequence, session!.observed, elapsed() - session!.observedAt);
      if (rejection != null) {
        return _staleFrame(rejection, observed, session!.sequence, session!.observed);
      }
      if (path == '/vscreen/check') {
        session!.observed = -1;
        return status();
      }
      if (session!.input.active()) return _error('TOUCH_IN_PROGRESS');
      if (path == '/vscreen/tap' || path == '/vscreen/swipe') {
        final tap = path.endsWith('/tap');
        final x = _coordinate(q, tap ? 'x' : 'x1', session!.width),
            y = _coordinate(q, tap ? 'y' : 'y1', session!.height);
        final endX = tap ? x : _coordinate(q, 'x2', session!.width),
            endY = tap ? y : _coordinate(q, 'y2', session!.height);
        final ms = tap ? 0 : int.parse(q['ms'] ?? '300');
        if (ms < 0 || ms > 3000) return _error('INVALID_DURATION');
        final stroke = vscreenUuid();
        session!.observed = -1;
        try {
          if (!session!.input.touch(stroke, 0, x, y).accepted()) {
            return _inputFailure(session!);
          }
          final steps = max(1, ms ~/ 16);
          for (var n = 1; n < steps; n++) {
            sleep(const Duration(milliseconds: 16));
            if (!session!.input
                .touch(stroke, 2, x + (endX - x) * n / steps, y + (endY - y) * n / steps)
                .accepted()) {
              return _inputFailure(session!);
            }
          }
          return _inputResult(session!.input.touch(stroke, 1, endX, endY));
        } finally {
          session!.input.cancel();
        }
      }
      if (path == '/vscreen/key') {
        final code = int.parse(q['keycode'] ?? '-1');
        if (code != 3 && code != 4 && code != 66 && code != 67) {
          return _error('INVALID_KEY');
        }
        session!.observed = -1;
        return _inputResult(session!.input.key(code));
      }
      final text = q['text'] ?? '';
      if (text.isEmpty || text.length > 2000) return _error('INVALID_TEXT');
      if (!RegExp(r'^[\x20-\x7e]+$').hasMatch(text)) {
        return _error('ACCESSIBILITY_REQUIRED_FOR_UNICODE');
      }
      session!.observed = -1;
      return _inputResult(session!.input.text(text));
    } on FormatException {
      return _error('INVALID_ARGUMENT');
    } on ArgumentError {
      return _error('INVALID_ARGUMENT');
    } catch (error) {
      return failure(error, false);
    }
  }

  /// 显示创建（原版 `create`；宿主夹具与生产双路径）。
  Map<String, Object?> create(int width, int height) {
    final size = VscreenPolicy.phoneSize(width, height);
    if (session != null && session!.width == size[0] && session!.height == size[1]) {
      return status();
    }
    release();
    if (hostDisplayFactory != null) {
      VscreenDisplaySession? created;
      try {
        created = hostDisplayFactory!(size[0], size[1]);
        if (created.id <= 0 || created.width != size[0] || created.height != size[1]) {
          throw ArgumentError('DISPLAY_ADAPTER_FACTS_INVALID');
        }
        session = created;
        created.start();
        return status();
      } catch (error) {
        session = null;
        try {
          created?.close();
        } catch (cleanup) {
          // 原版 addSuppressed：诊断合并留缝侧。
        }
        return failure(error, false);
      }
    }
    final creator = displayCreator;
    if (creator == null) return failure(StateError('DISPLAY_SERVICE_UNAVAILABLE'), false);
    var requestedTrusted = false;
    Object? displayCreateFailure;
    VscreenDisplaySession? created;
    try {
      final trusted = VscreenPolicy.requestTrustedDisplay(
          identity.birth.uid, creator.trustedPermission());
      final absent = <String>[];
      int flag(String name) {
        final value = creator.flagValue(name);
        if (value == null) absent.add(name);
        return value ?? 0;
      }

      var flags = 0;
      flags |= flag('VIRTUAL_DISPLAY_FLAG_PUBLIC');
      flags |= flag('VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY');
      flags |= flag('VIRTUAL_DISPLAY_FLAG_SUPPORTS_TOUCH');
      flags |= flag('VIRTUAL_DISPLAY_FLAG_DESTROY_CONTENT_ON_REMOVAL');
      flags |= flag('VIRTUAL_DISPLAY_FLAG_OWN_FOCUS');
      if (trusted) {
        final trustedFlag = flag('VIRTUAL_DISPLAY_FLAG_TRUSTED');
        requestedTrusted = trustedFlag != 0;
        flags |= trustedFlag;
      }
      missingDisplayFlags = absent.join(',');
      try {
        created = creator.create(size[0], size[1], flags);
      } catch (platformFailure) {
        displayCreateFailure = platformFailure;
        rethrow;
      }
      if (created == null) throw FileSystemException('DISPLAY_CREATE_FAILED');
      session = created;
      created.start();
      return status();
    } catch (error) {
      session = null;
      try {
        created?.abortCreate(); // 原版失败清理：active=false + frame 回收
      } catch (cleanup) {
        // addSuppressed 同位。
      }
      final stable = VscreenFailures.code(error);
      final denied =
          requestedTrusted && stable == VscreenFailures.permissionDenied;
      final result = failure(error, identical(error, displayCreateFailure));
      if (error is ArgumentError) return result..put('error', 'INVALID_ARGUMENT');
      return denied
          ? (result..put('error', VscreenFailures.trustedDisplayDenied))
          : result;
    }
  }

  /// 状态快照（原版 `status`）。
  Map<String, Object?> status() {
    final current = session;
    if (current == null) return _ok()..put('active', false);
    final actual = currentPackage();
    return _ok()
      ..put('active', true)
      ..put('protocol', 1)
      ..put('coreInstance', identity.birth.instance)
      ..put('displayId', current.id)
      ..put('generation', current.generation)
      ..put('width', current.width)
      ..put('height', current.height)
      ..put('frameSeq', current.sequence)
      ..put('package', actual)
      ..put('packageVerified', actual.isNotEmpty)
      ..put('inputBackend', current.input.backend())
      ..put('inputUnavailable', current.input.unavailableReason())
      ..put('missingDisplayFlags', missingDisplayFlags)
      ..put('orientation', current.width > current.height ? 'landscape' : 'portrait');
  }

  String currentPackage() {
    try {
      final value = foregroundPackage?.call(session?.id ?? -1) ?? '';
      return RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]*)+$').hasMatch(value)
          ? value
          : '';
    } catch (e) {
      return '';
    }
  }

  Map<String, Object?> preview(int since, String? generation) =>
      VscreenPixels.preview(session!, since, generation ?? '', status);

  /// 包启动（原版 `launchPackage`）。
  Map<String, Object?> launchPackage(String? name) {
    if (name == null ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$').hasMatch(name)) {
      return _error('INVALID_PACKAGE');
    }
    final resolved = _exec([
      '/system/bin/cmd',
      'package',
      'resolve-activity',
      '--brief',
      '--user',
      'current',
      '-a',
      'android.intent.action.MAIN',
      '-c',
      'android.intent.category.LAUNCHER',
      name,
    ]);
    String? component;
    for (final line in resolved.text.split(RegExp(r'\r?\n'))) {
      if (line.trim().startsWith('$name/')) component = line.trim();
    }
    if (component == null || resolved.exit != 0) return _error('NO_LAUNCH_ACTIVITY');
    final launched = _exec([
      '/system/bin/am',
      'start',
      '--user',
      'current',
      '--display',
      '${session!.id}',
      '-n',
      component,
      '-f',
      '0x18000000',
    ]);
    if (launched.unknown) return _error('LAUNCH_RESULT_UNKNOWN');
    if (launched.exit != 0 ||
        launched.text.contains('Error') ||
        launched.text.contains('Exception')) {
      return _error('LAUNCH_REJECTED');
    }
    session!.packageName = name;
    return status();
  }

  void release() {
    final current = session;
    session = null;
    current?.close();
  }

  void shutdown() {
    if (!running) return;
    running = false;
    try {
      release();
    } catch (e) {
      // 独立出生探测报的是进程退出，永不是这次本地清理尝试。
    } finally {
      try {
        _server?.close();
      } catch (e) {
        // 原版忽略。
      }
      _server = null;
      _processExit();
    }
  }

  /// 失败包装（原版 `failure`；显示创建保留技术消息，输入/通用异常不回显正文）。
  Map<String, Object?> failure(Object? error, bool displayCreation) {
    final value = _error(VscreenFailures.code(error));
    try {
      final captured = _failureCapture
          ?.call(value.optString('error'), error!, displayCreation);
      value.put(
          'failureOrigin', displayCreation ? 'ANDROID_DISPLAY_CREATE' : 'NATIVE_OPERATION');
      if (captured != null) value.put('failure', captured);
      value.put(
          'cause',
          displayCreation
              ? VscreenFailures.cause(error)
              : error == null
                  ? ''
                  : error.runtimeType.toString());
    } on Exception {
      // 原版忽略。
    }
    return value;
  }

  Map<String, Object?> _inputResult(VscreenInputResult result) {
    if (result == VscreenInputResult.ACCEPTED) {
      try {
        return status();
      } catch (e) {
        return _ok()..put('resultMetadataUnavailable', true);
      }
    }
    final value = _error(result == VscreenInputResult.UNKNOWN
        ? 'INPUT_RESULT_UNKNOWN'
        : session!.input.available()
            ? 'INPUT_REJECTED'
            : VscreenInputPolicy.inputUnavailable);
    if (result == VscreenInputResult.UNKNOWN) value.put('executionUnknown', true);
    return value;
  }

  Map<String, Object?> _inputFailure(VscreenDisplaySession failed) =>
      _inputResult(failed.input.lastResult());

  /// 帧门拒绝：保留既有的 STALE_FRAME 码，同时给出可区分的原因与实际值/期望值。
  static Map<String, Object?> _staleFrame(
      String reason, int requested, int current, int observed) {
    return _error('STALE_FRAME')
      ..put('reason', reason)
      ..put('requestedFrameSeq', requested)
      ..put('currentFrameSeq', current)
      ..put('observedFrameSeq', observed);
  }

  static Map<String, Object?> _ok() => <String, Object?>{'ok': true};

  static Map<String, Object?> _error(String code) =>
      vscreenFailure(code, false);

  static double _coordinate(Map<String, String> q, String key, int edge) {
    final n = double.parse(q[key] ?? 'NaN');
    if (!n.isFinite || n < 0 || n >= edge) throw ArgumentError();
    return n;
  }

  static Map<String, String> _query(String target) {
    final q = <String, String>{};
    final at = target.indexOf('?');
    if (at < 0) return q;
    for (final pair in target.substring(at + 1).split('&')) {
      final eq = pair.indexOf('=');
      if (eq >= 0) {
        q[Uri.decodeQueryComponent(pair.substring(0, eq))] =
            Uri.decodeQueryComponent(pair.substring(eq + 1));
      }
    }
    return q;
  }

  static List<String> _splitN(String text, String sep, int limit) {
    final parts = <String>[];
    var start = 0;
    while (parts.length < limit - 1) {
      final at = text.indexOf(sep, start);
      if (at < 0) break;
      parts.add(text.substring(start, at));
      start = at + sep.length;
    }
    parts.add(text.substring(start));
    return parts;
  }

  /// 行读取（原版 `line`）：截止期 + 上限 + US-ASCII + 去 CR。
  /// 原版截止期耗尽同样落 `HEAD_LIMIT`；阻塞读由 `setSoTimeout` 抛出，此处同位超时上抛。
  Future<String> _line(StreamIterator<int> input, int maximum, int until) async {
    final bytes = BytesBuilder();
    while (bytes.length < maximum && elapsed() < until) {
      final remaining = Duration(milliseconds: max(1, until - elapsed()));
      if (!await input.moveNext().timeout(remaining)) throw FileSystemException('HEAD_LIMIT');
      final b = input.current;
      if (b == 0x0a /* '\n' */) {
        return String.fromCharCodes(bytes.toBytes()).replaceAll('\r', '');
      }
      bytes.addByte(b);
    }
    throw FileSystemException('HEAD_LIMIT');
  }
}

/// 出生身份面（缝：`VscreenCoreIdentity` + `AppIdentity`）。
abstract interface class VscreenCoreIdentityLike {
  VscreenCoreIdentity get birth;

  String applicationId();
}
