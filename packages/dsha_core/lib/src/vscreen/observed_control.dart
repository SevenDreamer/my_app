// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenObservedControl —— 现代化重构，行为契约不变。
//! 有界 agent 观察的单一语义属主；原始像素证据永不改标。
//! 错误契约（逐字）：`ANCHOR_IDENTITY_UNAVAILABLE`/`UNKNOWN_ROUTE`/`ANCHOR_NOT_AVAILABLE`/
//! `OBSERVATION_EXPIRED`/`ANCHOR_EXPIRED`/`INPUT_RESULT_UNKNOWN`/`ANCHOR_IDENTITY_CHANGED`/
//! `ANCHOR_ALREADY_ISSUED`/`ANCHOR_TREE_CHANGED`/`ANCHOR_NODE_UNAVAILABLE`/`ANCHOR_NODE_CHANGED`/
//! `ANCHOR_OCCLUDED`/`ANCHOR_TREE_BUDGET`/`NODE_ACTION_REJECTED`/`SCREEN_TARGET_CHANGED`
//! （+ [AnchorProofApi] 的 ANCHOR_* 摘取代号）。
library;

import 'dart:math';

import 'target_evidence.dart';
import 'support.dart';

/// 原版常量：观察 TTL 30s；证明元数据上限 1MiB（`VirtualScreenAnchorProof.METADATA_LIMIT`）。
const int observationTtlMs = 30 * 1000;
const int _metadataLimit = 1024 * 1024;

/// 单 isolate 门（原版 `ReentrantLock` 语义投影：同线程可重入；`expire`
/// 计时回调永不在读者持锁段内运行）。
class _Gate {
  bool _held = false;

  bool get isHeldByCurrentThread => _held;

  void lock() {
    _held = true;
  }

  bool tryLock() {
    if (_held) {
      return false;
    }
    _held = true;
    return true;
  }

  void unlock() {
    _held = false;
  }
}

class _Owner {
  _Owner(VscreenContext context, Map<String, Object?> frame)
      : original = context.request(),
        consent = (context.request().target as VscreenTargetEvidence)
            .consentRevision,
        managerEpoch = frame.getLong('managerEpoch'),
        managerRevision = frame.getLong('managerRevision'),
        core = frame.getString('coreInstance'),
        generation = frame.getString('generation'),
        display =
            (context.request().target as VscreenTargetEvidence).displayId,
        window = (context.request().target as VscreenTargetEvidence).windowId,
        packageName =
            (context.request().target as VscreenTargetEvidence).packageName {
    final target = original.target as VscreenTargetEvidence;
    if (consent < 0 ||
        core != target.coreInstance ||
        frame.getInt('displayId') != display ||
        packageName != frame.getString('package') ||
        window < 0 ||
        packageName.isEmpty) {
      throw ArgumentError('ANCHOR_IDENTITY_UNAVAILABLE');
    }
  }

  final CapabilityRequestApi original;
  final int consent, managerEpoch, managerRevision;
  final String core, generation;
  final int display, window;
  final String packageName;

  bool matches(VscreenContext context, Map<String, Object?> args) {
    final request = context.request();
    final target = request.target;
    if (target is! VscreenTargetEvidence) {
      return false;
    }
    return context.serviceEpoch() >= 0 &&
        original.runtime == request.runtime &&
        original.installInstanceId == request.installInstanceId &&
        original.bridgeRunId == request.bridgeRunId &&
        original.policyRevision == request.policyRevision &&
        original.authorityEpoch == request.authorityEpoch &&
        consent == target.consentRevision &&
        core == target.coreInstance &&
        generation == target.generation &&
        display == target.displayId &&
        window == target.windowId &&
        packageName == target.packageName &&
        core == args.optString('coreInstance') &&
        generation == args.optString('generation') &&
        managerEpoch == args.optLong('managerEpoch', -1) &&
        managerRevision == args.optLong('managerRevision', -1);
  }
}

class _Observation {
  _Observation(Map<String, Object?> frame, VscreenContext context,
      this.proof, this.pixels, this.version)
      : id = frame.getString('observationId'),
        owner = _Owner(context, frame),
        source = frame.getLong('sourceFrameSeq'),
        width = frame.getInt('width'),
        height = frame.getInt('height'),
        created = frame.getLong('observationCreatedElapsedMillis') {
    if (source < 1 ||
        !vscreenUuidValid(id) ||
        width <= 0 ||
        height <= 0) {
      throw ArgumentError('ANCHOR_IDENTITY_UNAVAILABLE');
    }
  }

  final String id;
  final _Owner owner;
  final AnchorProofApi proof;
  final ObservedPixelsApi pixels;
  final int source, created, version;
  final int width, height;
  String anchor = '';
  AnchorCandidateApi? selected;
  bool consumed = false, released = false;
  bool expired = false;
  ExpiryHandle? expiry;
}

/// 观察控制面（原版 `VirtualScreenObservedControl`）。
class VscreenObservedControl {
  VscreenObservedControl({
    required VscreenClock clock,
    required AnchorProofApi Function(VscreenContext context) captureProof,
  })  : _clock = clock,
        _captureProof = captureProof;

  final VscreenClock _clock;
  final AnchorProofApi Function(VscreenContext context) _captureProof;
  final Map<String, _Observation> _observations = <String, _Observation>{};
  int _metadataBytes = 0;
  final _Gate _gate = _Gate();
  int _invalidation = 0;
  int _clearedVersion = 0;
  int _readers = 0;

  /// 原版 `run(service, display, operation, args, context, pixels, click)`。
  Map<String, Object?> run(
    int display,
    String operation,
    Map<String, Object?> args,
    VscreenContext context,
    ObservedPixelsApi pixels,
    VscreenClick click,
  ) {
    _gate.lock();
    if (_clearedVersion != _invalidation) {
      _clearLocked();
    }
    final version = _invalidation;
    _readers++;
    try {
      var result = _runLocked(display, operation, args, context, pixels, click);
      if (operation == 'anchored-click') {
        result = _clickMetadata(result, args);
      }
      if (version != _invalidation) {
        if (operation == 'see' && result.optBoolean('ok')) {
          return _unavailable(result, 'OBSERVATION_EXPIRED');
        }
        if (operation == 'anchored-click' &&
            (result.optBoolean('ok') ||
                result.optBoolean('executionUnknown'))) {
          return vscreenFailure('INPUT_RESULT_UNKNOWN', false)
              .put('executionUnknown', true)
              .put('mode', 'ANCHORED_NODE')
              .put('sourceFrameSeq', args.optLong('frameSeq', -1))
              .put('validatedCurrentSeq',
                  result.optLong('validatedCurrentSeq', -1));
        }
        return operation == 'anchored-click'
            ? _clickMetadata(vscreenFailure('ANCHOR_EXPIRED', false), args)
            : vscreenFailure('ANCHOR_EXPIRED', false);
      }
      return result;
    } on Exception {
      return operation == 'anchored-click'
          ? _clickMetadata(vscreenFailure('ANCHOR_NOT_AVAILABLE', false), args)
          : vscreenFailure('ANCHOR_NOT_AVAILABLE', false);
    } finally {
      _readers--;
      if (_readers == 0) {
        _prune();
        if (_clearedVersion != _invalidation) {
          _clearLocked();
        }
      }
      _gate.unlock();
    }
  }

  Map<String, Object?> _runLocked(
    int display,
    String operation,
    Map<String, Object?> args,
    VscreenContext context,
    ObservedPixelsApi pixels,
    VscreenClick click,
  ) {
    _prune();
    try {
      if (context.request().target is! VscreenTargetEvidence ||
          !context.current() ||
          context.target.displayId != display) {
        return vscreenFailure('ANCHOR_IDENTITY_UNAVAILABLE', false);
      }
      if (operation == 'see') {
        return _see(context, pixels);
      }
      if (operation == 'anchor') {
        return _select(context, args);
      }
      if (operation == 'anchored-click') {
        final result = _click(context, args, pixels, click);
        result.put('mode', 'ANCHORED_NODE');
        if (!result.has('sourceFrameSeq')) {
          result.put('sourceFrameSeq', args.optLong('frameSeq', -1));
        }
        if (!result.has('validatedCurrentSeq')) {
          result.put('validatedCurrentSeq', -1);
        }
        return result;
      }
      return vscreenFailure('UNKNOWN_ROUTE', false);
    } on Exception catch (error) {
      return vscreenFailure(
          error is AnchorUnavailable ? error.reason : 'ANCHOR_NOT_AVAILABLE',
          false);
    }
  }

  Map<String, Object?> _see(
      VscreenContext context,
      ObservedPixelsApi pixels,
  ) {
    if (!context.claimDispatch()) {
      return vscreenFailure('SCREEN_TARGET_CHANGED', false);
    }
    AnchorProofApi? before, after;
    Map<String, Object?>? frame;
    _Observation? retained;
    var capturedId = '';
    var reason = 'ANCHOR_NOT_AVAILABLE';
    try {
      try {
        before = _captureProof(context);
      } on Exception catch (error) {
        reason = error is AnchorUnavailable
            ? error.reason
            : 'ANCHOR_TREE_UNAVAILABLE';
      }
      frame = pixels.capture(before != null);
      capturedId = frame.optString('observationId');
      if (!frame.optBoolean('ok')) {
        return frame;
      }
      if (before == null || !frame.has('observationId')) {
        reason = before == null
            ? reason
            : frame.optString(
                'availabilityReason', 'OBSERVATION_NOT_AVAILABLE');
        return _unavailable(frame, reason);
      }
      after = _captureProof(context);
      if (!before.sameAs(after) || !context.current()) {
        return _unavailable(frame, 'ANCHOR_TREE_CHANGED');
      }
      if (before.candidates.isEmpty) {
        return _unavailable(frame, 'ANCHOR_NODE_UNAVAILABLE');
      }
      while (_observations.isNotEmpty &&
          (_observations.length >= 2 ||
              _metadataBytes + before.bytes > _metadataLimit)) {
        _remove(_observations.values.first);
      }
      if (before.bytes > _metadataLimit) {
        return _unavailable(frame, 'ANCHOR_TREE_BUDGET');
      }
      retained = _Observation(
          frame, context, before, pixels, _invalidation);
      if (_expired(retained)) {
        retained = null;
        return _unavailable(frame, 'OBSERVATION_EXPIRED');
      }
      _observations[retained.id] = retained;
      _metadataBytes += before.bytes;
      final exact = retained;
      retained.expiry = pixels.expireAfter(
        () => _expire(exact),
        max(0, observationTtlMs - (_clock.millis() - exact.created) + 1),
      );
      before = null; // 该观察独占这份完整证明与候选句柄
      return frame
          .put('anchoredAvailable', true)
          .put('availabilityReason', 'AVAILABLE')
          .put('anchorCandidateCount', retained.proof.candidates.length);
    } on Exception catch (error) {
      if (retained != null) {
        _remove(retained);
        retained = null;
        capturedId = '';
      }
      if (frame != null && frame.optBoolean('ok')) {
        return _unavailable(
            frame,
            error is AnchorUnavailable
                ? error.reason
                : 'ANCHOR_NOT_AVAILABLE');
      }
      rethrow;
    } finally {
      after?.close();
      before?.close();
      if (retained == null && capturedId.isNotEmpty) {
        pixels.release(capturedId);
      }
    }
  }

  Map<String, Object?> _select(
      VscreenContext context,
      Map<String, Object?> args,
  ) {
    final id = args.optString('observationId');
    final observation = _observations[id];
    if (observation == null || _expired(observation)) {
      return vscreenFailure('OBSERVATION_EXPIRED', false);
    }
    final target = context.request().target as VscreenTargetEvidence;
    if (!observation.owner.matches(context, args) ||
        context.serviceEpoch() != observation.proof.connectionEpoch ||
        observation.source != args.optLong('frameSeq', -1) ||
        !target.matchesObservedAnchor(
            observation.owner.core,
            observation.owner.generation,
            observation.source,
            id,
            observation.owner.consent)) {
      return vscreenFailure('ANCHOR_IDENTITY_CHANGED', false);
    }
    if (observation.anchor.isNotEmpty) {
      return vscreenFailure('ANCHOR_ALREADY_ISSUED', false);
    }
    final x = args.getInt('x'), y = args.getInt('y');
    final selected =
        observation.proof.selectAnchor(x, y, observation.width, observation.height);
    if (_expired(observation)) {
      return vscreenFailure('OBSERVATION_EXPIRED', false);
    }
    if (!context.claimDispatch()) {
      return vscreenFailure('SCREEN_TARGET_CHANGED', false);
    }
    if (_expired(observation)) {
      return vscreenFailure('OBSERVATION_EXPIRED', false);
    }
    observation.selected = selected;
    observation.anchor = vscreenUuid();
    final result = <String, Object?>{}
        .put('ok', true)
        .put('anchorId', observation.anchor)
        .put('sourceFrameSeq', observation.source)
        .put('mode', 'ANCHORED_NODE');
    return _expired(observation)
        ? vscreenFailure('OBSERVATION_EXPIRED', false)
        : result;
  }

  Map<String, Object?> _click(
    VscreenContext context,
    Map<String, Object?> args,
    ObservedPixelsApi pixels,
    VscreenClick click,
  ) {
    _Observation? observation;
    final id = args.optString('anchorId');
    for (final candidate in _observations.values) {
      if (candidate.anchor == id && id.isNotEmpty) {
        observation = candidate;
        break;
      }
    }
    if (observation == null || observation.consumed || _expired(observation)) {
      return vscreenFailure('ANCHOR_EXPIRED', false);
    }
    // 首次发送即消费这笔精确租约，包括随后的拒绝或未知结果。
    observation.consumed = true;
    final submitted = <bool>[false];
    var validated = -1;
    try {
      final target = context.request().target as VscreenTargetEvidence;
      if (!observation.owner.matches(context, args) ||
          observation.source != args.optLong('frameSeq', -1) ||
          !target.matchesAnchored(
              observation.owner.core,
              observation.owner.generation,
              observation.source,
              id,
              observation.owner.consent)) {
        return vscreenFailure('ANCHOR_IDENTITY_CHANGED', false);
      }
      final live = _captureProof(context);
      try {
        if (!observation.proof.sameAs(live)) {
          return vscreenFailure('ANCHOR_TREE_CHANGED', false);
        }
        final original = observation.selected;
        if (original == null || !original.node.refresh()) {
          return vscreenFailure('ANCHOR_NODE_CHANGED', false);
        }
        final selected = live.same(original);
        if (selected == null) {
          return vscreenFailure('ANCHOR_NODE_CHANGED', false);
        }
        final region = vscreenRegion(
            original.bounds, observation.width, observation.height);
        if (!live.unobscured(region)) {
          return vscreenFailure('ANCHOR_OCCLUDED', false);
        }
        final check = pixels.region(observation.id, region);
        if (!check.optBoolean('ok')) {
          return check;
        }
        if (check.optLong('sourceFrameSeq', -1) != observation.source ||
            observation.owner.generation != check.optString('generation') ||
            check.optInt('displayId', -1) != observation.owner.display) {
          return vscreenFailure('ANCHOR_IDENTITY_CHANGED', false);
        }
        validated = check.getLong('validatedCurrentSeq');
        if (observation.version != _invalidation || _expired(observation)) {
          return vscreenFailure('ANCHOR_EXPIRED', false);
        }
        if (!context.current()) {
          return vscreenFailure('SCREEN_TARGET_CHANGED', false);
        }
        final owned = observation;
        final accepted = click(
          original.node,
          live.root,
          context,
          submitted,
          () => !_expired(owned) && owned.version == _invalidation,
        );
        var result = accepted
            ? <String, Object?>{'ok': true}
            : vscreenFailure('NODE_ACTION_REJECTED', false);
        if (submitted[0] && !context.current()) {
          result = vscreenFailure('INPUT_RESULT_UNKNOWN', false)
              .put('executionUnknown', true);
        }
        return result
            .put('mode', 'ANCHORED_NODE')
            .put('sourceFrameSeq', observation.source)
            .put('validatedCurrentSeq', validated);
      } finally {
        live.close();
      }
    } catch (error) {
      final result = vscreenFailure(
          submitted[0]
              ? 'INPUT_RESULT_UNKNOWN'
              : _expired(observation)
                  ? 'ANCHOR_EXPIRED'
                  : 'ANCHOR_NOT_AVAILABLE',
          false);
      if (submitted[0]) {
        result.put('executionUnknown', true);
      }
      return result
          .put('mode', 'ANCHORED_NODE')
          .put('sourceFrameSeq', observation.source)
          .put('validatedCurrentSeq', validated);
    } finally {
      _remove(observation);
    }
  }

  static Map<String, Object?> _clickMetadata(
      Map<String, Object?> result, Map<String, Object?> args) {
    try {
      result.put('mode', 'ANCHORED_NODE');
      if (!result.has('sourceFrameSeq')) {
        result.put('sourceFrameSeq', args.optLong('frameSeq', -1));
      }
      if (!result.has('validatedCurrentSeq')) {
        result.put('validatedCurrentSeq', -1);
      }
    } on Exception {
      // 原版忽略。
    }
    return result;
  }

  static Map<String, Object?> _unavailable(
      Map<String, Object?> frame, String reason) {
    frame.remove('observationId');
    if (!frame.has('sourceFrameSeq')) {
      frame.put('sourceFrameSeq', frame.optLong('frameSeq', -1));
    }
    return frame
        .put('anchoredAvailable', false)
        .put('availabilityReason', reason);
  }

  void _expire(_Observation exact) {
    exact.expired = true;
    // 计时器从不等待 A11/Core 读者，也从不使替换后的属主失效。
    if (_gate.isHeldByCurrentThread || !_gate.tryLock()) {
      return;
    }
    try {
      if (_observations[exact.id] == exact) {
        _remove(exact);
      }
    } finally {
      _gate.unlock();
    }
  }

  bool _expired(_Observation observation) {
    final now = _clock.millis();
    return observation.expired ||
        observation.released ||
        now < observation.created ||
        now - observation.created > observationTtlMs;
  }

  void _prune() {
    for (final observation
        in List<_Observation>.of(_observations.values)) {
      if (_expired(observation)) {
        _remove(observation);
      }
    }
  }

  void _remove(_Observation exact) {
    if (_observations[exact.id] == exact) {
      _observations.remove(exact.id);
      _metadataBytes -= exact.proof.bytes;
    }
    if (exact.released) {
      return;
    }
    exact.released = true;
    exact.expiry?.cancel();
    exact.expiry = null;
    exact.proof.close();
    try {
      exact.pixels.release(exact.id);
    } catch (e) {
      // 本地证据保持失效；精确 Core 属主有自己的原始图 TTL 与拆除。
    }
  }

  void invalidate() {
    _invalidation++;
  }

  /// 永不回收仍在用的证明，也不在 stop 线程等待远程读。
  void clear() {
    invalidate();
    if (_gate.isHeldByCurrentThread || !_gate.tryLock()) {
      return;
    }
    try {
      _clearLocked();
    } finally {
      _gate.unlock();
    }
  }

  void _clearLocked() {
    for (final observation
        in List<_Observation>.of(_observations.values)) {
      _remove(observation);
    }
    _clearedVersion = _invalidation;
  }
}

/// uuid 校验（原版 `VirtualScreenObservedControl.uuid`；Java `matches` 全匹配）。
bool vscreenUuidValid(String? id) =>
    id != null &&
    RegExp(r'^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$').hasMatch(id);
