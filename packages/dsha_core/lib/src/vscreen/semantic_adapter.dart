// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenSemanticAdapter —— 现代化重构，行为契约不变。
//! 语义节点的唯一所有者；显式上下文跨异步传递，不将无障碍连接当许可。
//! 错误契约（逐字）：`EXPLICIT_NATIVE_USER_REQUIRED`/`EXPLICIT_SCREEN_REQUEST_REQUIRED`。
library;

import 'a11y_support.dart';
import 'accessibility.dart';
import 'request_scope.dart';
import 'support.dart';

/// 无障碍服务静态面缝（原版 `DshaAccessibilityService`）。
abstract class AccessibilityServiceApi {
  bool isConnected();

  Map<String, Object?> virtualControl(
      VscreenAccessibility session,
      CapabilityBrokerApi broker,
      CapabilityRequestApi request,
      bool Function() current,
      int display,
      String operation,
      Map<String, Object?> args);

  Map<String, Object?> virtualObservedControl(
      VscreenAccessibility session,
      CapabilityBrokerApi broker,
      CapabilityRequestApi request,
      bool Function() current,
      int display,
      String operation,
      Map<String, Object?> args,
      ObservedPixelsApi pixels);

  Map<String, Object?> typeVirtual(CapabilityBrokerApi broker, CapabilityRequestApi request,
      bool Function() current, int display, String text);

  Map<String, Object?> typeVirtualUser(int display, String text, bool Function() current);
}

/// 语义适配（原版 `VirtualScreenSemanticAdapter`）。
class VscreenSemanticAdapter {
  VscreenSemanticAdapter(this.service);

  final AccessibilityServiceApi service;
  final VscreenAccessibility session = VscreenAccessibility(
    roots: _DetachedRoots(),
    clock: _ZeroClock(),
  );

  Map<String, Object?> nativeControl(
      VscreenAccessibility nativeSession,
      NativeScreenControlLease? lease,
      int display,
      String operation,
      Map<String, Object?> args) {
    if (lease == null) {
      return vscreenFailure('EXPLICIT_NATIVE_USER_REQUIRED', false);
    }
    return nativeSession.runNative(lease, display, operation, args);
  }

  Map<String, Object?> control(
      CapabilityBrokerApi? broker,
      CapabilityRequestApi? request,
      bool Function() current,
      int display,
      String operation,
      Map<String, Object?> args) {
    if (request == null || broker == null) {
      return vscreenFailure('EXPLICIT_SCREEN_REQUEST_REQUIRED', false);
    }
    return service.virtualControl(
        session, broker, request, current, display, operation, args);
  }

  Map<String, Object?> observed(
      CapabilityBrokerApi? broker,
      CapabilityRequestApi? request,
      bool Function() current,
      int display,
      String operation,
      Map<String, Object?> args,
      ObservedPixelsApi pixels) {
    if (request == null || broker == null) {
      return vscreenFailure('EXPLICIT_SCREEN_REQUEST_REQUIRED', false);
    }
    return service.virtualObservedControl(
        session, broker, request, current, display, operation, args, pixels);
  }

  Map<String, Object?> type(CapabilityBrokerApi? broker, CapabilityRequestApi? request,
      bool Function() current, int display, String text) {
    if (request == null) return service.typeVirtualUser(display, text, current);
    if (broker == null) {
      return vscreenFailure('EXPLICIT_SCREEN_REQUEST_REQUIRED', false);
    }
    return service.typeVirtual(broker, request, current, display, text);
  }

  void invalidateObserved() {
    session.invalidateObserved();
  }

  void clearObserved() {
    session.clearObserved();
  }

  void clear() {
    session.clear();
  }
}

class _ZeroClock implements VscreenClock {
  @override
  int millis() => 0;
}

class _DetachedRoots implements VirtualRootApi {
  @override
  A11yNode? virtualRoot(int displayId) => null;

  @override
  String windowDiagnostic() => '';

  @override
  A11yNode? refreshVirtualRoot(int displayId, A11yNode? root) => null;

  @override
  bool matchesTarget(ScreenTarget identity) => false;

  @override
  void validateActionRoot(int displayId, A11yNode root) {}
}
