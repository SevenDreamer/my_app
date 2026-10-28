// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenRequestScope —— 现代化重构，行为契约不变。
//! 请求上下文显式随编排调用传递；本机直接操作不借用助手许可。
library;

import 'support.dart';
import 'target_evidence.dart';

/// 派发许可（原版 `CapabilityBroker.DispatchPermit`）。
abstract class DispatchPermitApi {
  bool isCurrent();
}

/// 能力经纪（原版 `CapabilityBroker`；缝侧实现）。
abstract class CapabilityBrokerApi {
  bool current(CapabilityRequestApi request);

  DispatchPermitApi? claimDispatch(CapabilityRequestApi request);
}

/// 请求作用域（原版 `VirtualScreenRequestScope`）。
class VscreenRequestScope {
  VscreenRequestScope(this.broker, this.request, this.authority, String target)
      : target = _resolveTarget(request, target);

  static String _resolveTarget(CapabilityRequestApi? request, String fallback) {
    final evidence = request?.target;
    return evidence is VscreenTargetEvidence ? evidence.packageName : fallback;
  }

  final CapabilityBrokerApi? broker;
  final CapabilityRequestApi? request;
  final bool Function()? authority;
  final String target;
  DispatchPermitApi? _permit;

  bool current() {
    try {
      return (authority == null || authority!()) &&
          (request == null ||
              broker != null &&
                  request!.capability == 'screen' &&
                  broker!.current(request!));
    } on Exception {
      return false;
    }
  }

  bool claim() {
    if (!current()) return false;
    if (request == null) return true;
    _permit ??= broker!.claimDispatch(request!);
    return _permit != null && _permit!.isCurrent();
  }
}
