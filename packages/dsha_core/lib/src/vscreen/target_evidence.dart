// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VscreenTargetEvidence —— 现代化重构，行为契约不变。
//! 像素观察与一次语义节点分开携带；共同绑定 core/display/窗口身份。
//! 错误契约（逐字）：`INVALID_CONSENT_EVIDENCE` / `INVALID_ANCHORED_EVIDENCE`。

/// 原版 `NativeConsentPolicy.MAX_REVISION`（2^53-1）。
const int nativeConsentMaxRevision = 9007199254740991;

/// 观察形态（原版 `Observation`；`kind()` 输出小写名）。
enum Observation { pixel, observedAnchor, anchoredNode, node, editor, displayName }

/// 目标证据（原版 `VscreenTargetEvidence`，实现 `WindowTargetEvidence` 的数据面）。
class VscreenTargetEvidence {
  VscreenTargetEvidence({
    required this.coreInstance,
    required this.generation,
    required this.displayId,
    required this.windowId,
    required this.packageName,
    required this.observation,
    required this.frameSequence,
    required this.nodeOrEditorId,
    this.consentRevision = -1,
  }) {
    if (consentRevision < -1 || consentRevision > nativeConsentMaxRevision) {
      throw ArgumentError('INVALID_CONSENT_EVIDENCE');
    }
    if ((observation == Observation.anchoredNode ||
            observation == Observation.observedAnchor) &&
        (!_uuid(coreInstance) ||
            generation.isEmpty ||
            generation.length > 80 ||
            displayId <= 0 ||
            windowId < 0 ||
            packageName.isEmpty ||
            packageName.length > 200 ||
            frameSequence < 1 ||
            !_uuid(nodeOrEditorId) ||
            consentRevision < 0)) {
      throw ArgumentError('INVALID_ANCHORED_EVIDENCE');
    }
  }

  final String coreInstance;
  final String generation;
  final String packageName;
  final String nodeOrEditorId;
  final int displayId;
  final int windowId;
  final int frameSequence;
  final int consentRevision;
  final Observation observation;

  /// 一轮当前校验帧永远不得替换调用方的原始来源观察。
  bool matchesAnchored(
    String core,
    String sourceGeneration,
    int sourceFrameSequence,
    String anchorId,
    int expectedConsentRevision,
  ) {
    return _matches(
      Observation.anchoredNode,
      core,
      sourceGeneration,
      sourceFrameSequence,
      anchorId,
      expectedConsentRevision,
    );
  }

  bool matchesObservedAnchor(
    String core,
    String sourceGeneration,
    int sourceFrameSequence,
    String observationId,
    int expectedConsentRevision,
  ) {
    return _matches(
      Observation.observedAnchor,
      core,
      sourceGeneration,
      sourceFrameSequence,
      observationId,
      expectedConsentRevision,
    );
  }

  bool _matches(
    Observation expected,
    String core,
    String sourceGeneration,
    int sourceFrameSequence,
    String id,
    int expectedConsentRevision,
  ) {
    return observation == expected &&
        coreInstance == core &&
        generation == sourceGeneration &&
        frameSequence == sourceFrameSequence &&
        nodeOrEditorId == id &&
        consentRevision == expectedConsentRevision;
  }

  static bool _uuid(String value) {
    return RegExp(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}').hasMatch(value);
  }

  String kind() => 'vscreen/${observation.name.toLowerCase()}';
}
