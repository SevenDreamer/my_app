// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenNativeControls —— 现代化重构，行为契约不变。
//! A resumed native page explicitly owns one semantic session, separate from assistant nodes.
//! 错误契约（逐字）：`NATIVE_CONTROL_ALREADY_BOUND`/`INVALID_NATIVE_NODE_ACTION`/
//! `NATIVE_CONTROL_REVOKED`。
library;

import 'a11y_support.dart';
import 'accessibility.dart';
import 'support.dart';

/// 原生页面生命周期缝（原版 AppCompatActivity + Lifecycle）。
abstract class NativePageLifecycle {
  /// 原版 RESUMED 以上 + 非 finishing/destroyed。
  bool resumed();

  bool finishing();

  bool destroyed();

  /// ON_PAUSE/ON_STOP/ON_DESTROY 任一（原版 LifecycleEventObserver）。
  void addCloseObserver(void Function() onClose);

  void removeCloseObserver(void Function() onClose);

  bool isMainThread();

  void runOnMain(void Function() action);
}

/// 原生控制后端（原版 `VirtualScreenNativeControls.Backend`）。
abstract class NativeControlsBackend {
  bool current();

  Map<String, Object?> run(VscreenAccessibility session, NativeScreenControlLease lease,
      String operation, Map<String, Object?> args);
}

/// 原生控制会话（原版 `VirtualScreenNativeControls`）。
class VscreenNativeControls {
  VscreenNativeControls(this._page, {required NativeReplyApi replies})
      : _replies = replies {
    _page.addCloseObserver(close);
    if (!_page.resumed() || _page.finishing() || _page.destroyed()) {
      _closed = true;
    }
  }

  final NativePageLifecycle _page;
  final NativeReplyApi _replies;
  final VscreenAccessibility session = VscreenAccessibility(
    roots: _UnavailableRoots(),
    clock: _NullClock(),
  );
  bool _closed = false;
  NativeControlsBackend? _backend;
  NativeScreenControlLease? _lease;
  int _inFlight = 0;

  /// 绑定后端（原版 `bind`）；只有 resumed 原生页能取得这个本地属主。
  void bind(NativeControlsBackend backend, NativeScreenControlLease lease) {
    if (_backend != null) throw StateError('NATIVE_CONTROL_ALREADY_BOUND');
    _backend = backend;
    _lease = lease;
    if (!uiCurrent()) {
      _lease?.close();
    }
  }

  bool uiCurrent() =>
      !_closed && !_page.finishing() && !_page.destroyed();

  bool current() {
    final backend = _backend;
    return uiCurrent() &&
        backend != null &&
        backend.current() &&
        _lease != null;
  }

  /// Opaque local subject for the screen backend; callers cannot substitute their own predicate.
  bool nativeAuthorityCurrent() {
    final backend = _backend;
    return uiCurrent() && backend != null && backend.current();
  }

  Map<String, Object?> tree() => _run('tree', <String, Object?>{});

  Map<String, Object?> node(String? id, String? action, String? text) {
    if (id == null ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        (action != 'click' && action != 'set_text') ||
        text == null ||
        text.length > 16000) {
      return _replies.refused('INVALID_NATIVE_NODE_ACTION');
    }
    return _run('node', <String, Object?>{'nodeId': id, 'action': action, 'text': text});
  }

  Map<String, Object?> _run(String operation, Map<String, Object?> args) {
    final backend = _backend;
    final lease = _lease;
    if (!uiCurrent() || backend == null || lease == null) {
      return _replies.refused('NATIVE_CONTROL_REVOKED');
    }
    _inFlight++;
    try {
      return backend.run(session, lease, operation, args);
    } finally {
      _inFlight--;
      if (_inFlight == 0 && _closed) session.clear();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _lease?.close();
    void remove() => _page.removeCloseObserver(close);

    if (_page.isMainThread()) {
      remove();
    } else {
      _page.runOnMain(remove);
    }
    if (_inFlight == 0) session.clear();
  }
}

class _NullClock implements VscreenClock {
  @override
  int millis() => 0;
}

class _UnavailableRoots implements VirtualRootApi {
  @override
  A11yNode? virtualRoot(int displayId) => null;

  @override
  String windowDiagnostic() => 'NATIVE_SESSION_DETACHED';

  @override
  A11yNode? refreshVirtualRoot(int displayId, A11yNode? root) => null;

  @override
  bool matchesTarget(ScreenTarget identity) => false;

  @override
  void validateActionRoot(int displayId, A11yNode root) {}
}
