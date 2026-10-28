// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenManager —— 现代化重构，行为契约不变。
//! State snapshots use LOCK; remote/platform operations never run while holding it.
//! 错误契约（逐字）：`VSCREEN_UNSUPPORTED_LOW`/`VSCREEN_API_30_REQUIRED`/`INVALID_ORIENTATION`/
//! `SCREEN_TARGET_CHANGED`/`VSCREEN_APPLICATION_SCOPE_UNAVAILABLE`/`VSCREEN_START_IN_PROGRESS`/
//! `VSCREEN_REVOKED`/`VSCREEN_START_CANCELLED`/`DEVICE_CHANNEL_UNAVAILABLE`/
//! `VSCREEN_JOURNAL_UNAVAILABLE`/`VSCREEN_START_UNKNOWN`/`VSCREEN_START_NOT_SENT`/
//! `VSCREEN_CORE_IDENTITY_REQUIRED`/`VSCREEN_CORE_IDENTITY_CHANGED`/`VSCREEN_GENERATION_CHANGED`/
//! `CORE_EVIDENCE_REQUIRED`/`EXPLICIT_SCREEN_REQUEST_REQUIRED`/`VSCREEN_NOT_RUNNING`/
//! `VSCREEN_CLOSE_UNKNOWN`/`VSCREEN_CLOSE_SUPERSEDED`/`VSCREEN_CLEANUP_ATTEMPT_INVALID`/
//! `VSCREEN_ADB_LAUNCH_BUSY`/`STALE_GENERATION`/`STALE_FRAME`/`INPUT_RESULT_UNKNOWN`/
//! `ANCHOR_NOT_AVAILABLE`/`INVALID_PACKAGE`/`INVALID_TEXT`/`ACCESSIBILITY_REQUIRED_FOR_UNICODE`/
//! `INVALID_NODE_ACTION`/`INVALID_EDITOR_ARGUMENTS`/`VSCREEN_INPUT_REJECTED`/
//! `NATIVE_CONTROL_RESULT_UNKNOWN`/`NATIVE_CONTROL_REVOKED`/`VSCREEN_START_EXCEPTION` 等。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../install/sensitive_data.dart' show registerKnownSecret;
import 'bootstrap.dart';
import 'bridge_request.dart';
import 'channels.dart';
import 'core_identity.dart';
import 'journal.dart';
import 'manager_support.dart';
import 'policy.dart';
import 'request_scope.dart';
import 'semantic_adapter.dart';
import 'support.dart';
import 'target_evidence.dart';
import 'vscreen_handshake.dart';

/// 生命周期工作线程缝（原版 `ScheduledExecutorService`）。
abstract class ScheduledCancellable {
  void cancel();
}

abstract class VscreenWorkerApi {
  void execute(void Function() task);

  ScheduledCancellable schedule(void Function() task, int delayMs);

  ScheduledCancellable scheduleWithFixedDelay(
      void Function() task, int initialDelayMs, int delayMs);
}

/// 视觉效果缝（原版 `Visuals`）。
abstract class VscreenVisuals {
  void present();

  void stopped(int fence);
}

/// 通道选择缝（原版 `Channels`）。
abstract class VscreenChannelsApi {
  VscreenChannel? choose();

  VscreenChannel? find(String id);
}

/// 诊断记录缝（原版 `DiagnosticLog.record`）。
typedef DiagnosticRecordFn = void Function(String stage, String detail);

/// 启动异常捕获缝（原版 `diagnostics.Failure.capture`；[safeCodes] 为允许透出的消息码）。
typedef StartFailureCaptureFn = Map<String, Object?>? Function(
    String stage, Object? error, Set<String> safeCodes);

/// Core HTTP 传输缝（原版 `VirtualScreenTransport.request`；HTTP 客户端留接线轮）。
abstract class VscreenTransportApi {
  Map<String, Object?> request(VscreenHandshake endpoint, String route, String query);
}

/// 启动异常安全消息码（原版 `startExceptionMessagePolicy` 白名单，逐字）。
const Set<String> startExceptionSafeCodes = {
  'VSCREEN_JOURNAL_ROOT_UNAVAILABLE',
  'VSCREEN_JOURNAL_INVALID',
  'VSCREEN_JOURNAL_LIMIT',
  'VSCREEN_JOURNAL_FOREIGN',
  'VSCREEN_JOURNAL_LINK',
  'VSCREEN_JOURNAL_PERMISSIONS',
  'START_RESULT_UNKNOWN',
  'CORE_EXITED',
  'CORE_BOOTSTRAP_LIMIT',
  'CORE_BOOTSTRAP_INVALID',
};

/// 帧门拒绝节流（原版 `FRAME_REJECTION_INTERVAL_MS`）。
const int frameRejectionIntervalMs = 10000;

/// 清理探针退避（原版 `cleanupProbeDelayMillis`）。
int cleanupProbeDelayMillis(int attempt) {
  switch (attempt) {
    case 0:
      return 250;
    case 1:
      return 1000;
    case 2:
      return 3000;
    default:
      throw ArgumentError('VSCREEN_CLEANUP_ATTEMPT_INVALID');
  }
}

/// 「执行后」标记信封（原版 `ScreenActionResult` 语义，见 manager_support）。
const int _adbLaunchTtlMs = 30000;
const int _cleanupProbeAttempts = 3;

class _ClosedSession {
  _ClosedSession(VscreenHandshake? handle, this.channel, this.fence)
      : handle = handle,
        port = handle?.port ?? 0,
        token = handle?.token ?? '';

  final VscreenHandshake? handle;
  final int port;
  final String token;
  final String channel;
  final int fence;
  String probeReason = 'NOT_CHECKED';
}

enum CleanupCommit { notProven, committed, journalUnavailable, superseded }

/// 快照（原版 `Snapshot`）。
class VscreenSnapshot {
  VscreenSnapshot._(this.owner, this.identity, this.target, this.authority, this.channel,
      this.coreInstance, this.scope);

  final VscreenManager owner;
  final VscreenRequestFence identity;
  final String target;
  final bool Function() authority;
  final String channel;
  final String coreInstance;
  final VscreenRequestScope scope;
}

/// 虚拟屏管理器（原版 `VirtualScreenManager`）。
class VscreenManager {
  VscreenManager({
    required this.clock,
    required this.channels,
    required this.worker,
    required this.transport,
    required this.semantics,
    required this.launcher,
    required this.journal,
    required this.diagnostics,
    required this.failureCapture,
    required this.bootSource,
    required this.lowAndroid,
    required this.sdkInt,
    VscreenVisuals? visuals,
  }) {
    restoreJournal();
    _visuals = visuals ?? const _DefaultVisuals();
  }

  final VscreenClock clock;
  final VscreenChannelsApi channels;
  final VscreenWorkerApi worker;
  final VscreenTransportApi transport;
  final VscreenSemanticAdapter semantics;
  final VscreenLauncher launcher;
  final VscreenJournal? journal;
  final DiagnosticRecordFn diagnostics;
  final StartFailureCaptureFn failureCapture;
  final String Function() bootSource;
  final bool lowAndroid;
  final int sdkInt;
  late final VscreenVisuals _visuals;

  // Ordered mutation channel, separate from the state lock: stop/revoke never wait for it.
  final bool Function() _bridgeAuthorityDefault = () => true;

  String token = '', channel = '', generation = '', lastError = '';

  /// 最近一次创建失败摘要：连续重试同样的失败不再重复写诊断（写放大）。
  String lastCreateFailure = '';
  String lastStartOutcomeJson = '';
  int port = 0;
  int lifecycleEpoch = 0;
  int activeEpoch = -1;
  int stateRevision = 0;
  int frameSequence = -1;
  bool starting = false;
  bool launchDispatched = false;
  String _bridgeTarget = '';
  bool Function()? _bridgeAuthority;
  ScheduledCancellable? heartbeat;
  final OneShotLaunchAuthority adbLaunch = OneShotLaunchAuthority();
  final OneShotLaunchAuthority adbProbe = OneShotLaunchAuthority();
  VscreenLifecycleState lifecycleState = VscreenLifecycleState.stopped;
  VscreenHandshake? core;
  _ClosedSession? pendingCleanup;
  String attemptBoot = '';
  ScheduledCancellable? cleanupProbe;
  final Map<String, void Function()> observationReleases = {};
  bool observationReleaseScheduled = false;
  String lastFrameRejection = '';
  int lastFrameRejectionAt = 0;

  int epoch() => lifecycleEpoch;

  bool supported() => !lowAndroid && sdkInt >= 30;

  /// 本机直接操作作用域（原版 `localScope`）。
  VscreenRequestScope localScope() =>
      VscreenRequestScope(null, null, _bridgeAuthority ?? _bridgeAuthorityDefault, _bridgeTarget);

  /// 桥目标/授权随调用传递（原版 `withBridgeTarget`；单 isolate 用字段栈模拟 ThreadLocal）。
  T withBridgeTarget<T>(String target, bool Function() authority, T Function() action) {
    final beforeTarget = _bridgeTarget;
    final beforeAuthority = _bridgeAuthority;
    _bridgeTarget = target;
    _bridgeAuthority = authority;
    try {
      return action();
    } finally {
      _bridgeTarget = beforeTarget;
      _bridgeAuthority = beforeAuthority;
    }
  }

  static bool authorized(bool Function()? authority) {
    try {
      return authority == null || authority();
    } on Exception {
      return false;
    }
  }

  /// 只保留技术结果，不包含握手、token、图像或清理凭据。
  Map<String, Object?>? lastStartOutcome() {
    try {
      return lastStartOutcomeJson.isEmpty
          ? null
          : jsonDecode(lastStartOutcomeJson) as Map<String, Object?>;
    } on Exception {
      return null;
    }
  }

  VscreenSnapshot? snapshot(String? requiredGeneration, VscreenRequestScope scope) {
    if (starting || token.isEmpty || activeEpoch != lifecycleEpoch) return null;
    if (requiredGeneration != null &&
        (requiredGeneration.isEmpty || generation != requiredGeneration)) {
      return null;
    }
    final target = scope.request?.target;
    if (target is VscreenTargetEvidence) {
      final handle = core;
      if (handle == null ||
          handle.identity.instance != target.coreInstance ||
          (target.generation.isNotEmpty && generation != target.generation)) {
        return null;
      }
    }
    return VscreenSnapshot._(
      this,
      VscreenRequestFence(activeEpoch, port, token, generation, stateRevision),
      scope.target,
      scope.current,
      channel,
      core?.identity.instance ?? '',
      scope,
    );
  }

  bool currentLocked(VscreenSnapshot? s) =>
      s != null &&
      identical(s.owner, this) &&
      !starting &&
      s.identity.matches(lifecycleEpoch, activeEpoch, port, token, generation, stateRevision);

  bool current(VscreenSnapshot? s) {
    if (s == null || !authorized(s.authority)) return false;
    return currentLocked(s);
  }

  /// 请求编排核心（原版 `perform`）：栅栏 + 帧门 + 代次迁移 + 执行后判定。
  Map<String, Object?> perform(VscreenSnapshot? snapshot, String route, String query,
      bool changeGeneration,
      [bool freshFrame = true]) {
    if (snapshot == null) return missingSnapshot(null);
    if (!current(snapshot)) return failure('VSCREEN_REVOKED');
    var q = query;
    if (snapshot.target.isNotEmpty &&
        route != '/vscreen/launch' &&
        route != '/vscreen/status' &&
        route != '/vscreen/create') {
      q += '${q.isEmpty ? '' : '&'}expectedPackage=${encode(snapshot.target)}';
    }
    if ((VscreenRoutes.mutatesCore(route) ||
            route == '/vscreen/create' ||
            route == '/vscreen/preview') &&
        !_claim(snapshot)) {
      return failure('SCREEN_TARGET_CHANGED');
    }
    final value = requestAt(snapshot.identity.port, snapshot.identity.token, route, q);
    // 授权与目标检查可能走平台调用；同样不持 LOCK。
    if (!authorized(snapshot.authority)) {
      return afterExecutionOrNotExecuted(value, VscreenRoutes.mutatesCore(route),
          ScreenActionResult.targetChangedAfterExecution, 'SCREEN_TARGET_CHANGED');
    }
    String? rejection;
    var discardObserved = false;
    if (!currentLocked(snapshot)) {
      return afterExecutionOrNotExecuted(value, VscreenRoutes.mutatesCore(route),
          ScreenActionResult.runChangedAfterExecution, 'VSCREEN_REVOKED');
    }
    if (!value.optBoolean('ok')) {
      lastError = value.optString('error');
      // 只在这里算出要记的摘要，落盘必须放到锁外（记录会写文件）。
      rejection = frameRejectionDetail(route, value);
    } else {
      final returned = value.optString('generation', generation);
      if (generation != returned) {
        if (!changeGeneration) {
          return afterExecutionOrNotExecuted(value, VscreenRoutes.mutatesCore(route),
              ScreenActionResult.runChangedAfterExecution, 'STALE_GENERATION');
        }
        generation = returned;
        semantics.invalidateObserved();
        discardObserved = true;
        stateRevision++;
        frameSequence = -1;
      }
      final sequence = value.optLong('frameSeq', -1);
      if (freshFrame &&
          VscreenPolicy.frameRegressed(frameSequence, sequence,
              route == '/vscreen/status' || route == '/vscreen/preview')) {
        return failure('STALE_FRAME');
      }
      // 输入可能已经真的执行过：保留它的结果，但观察元数据只前进、绝不倒退。
      frameSequence = VscreenPolicy.advanceFrameSequence(frameSequence, sequence);
      tagLocked(value);
      value.put('coreInstance', snapshot.coreInstance);
    }
    if (discardObserved) semantics.clearObserved();
    if (rejection != null) recordFrameRejection(rejection);
    return value;
  }

  bool _claim(VscreenSnapshot snapshot) => snapshot.scope.claim();

  /// 帧门拒绝的可诊断摘要：稳定原因码 + 实际值/期望值；不含画面、坐标或用户内容。
  static String? frameRejectionDetail(String route, Map<String, Object?> value) {
    if (value.optString('error') != 'STALE_FRAME') return null;
    return '$route reason=${value.optString('reason', 'UNKNOWN')} '
        'requested=${value.optLong('requestedFrameSeq', -1)} '
        'current=${value.optLong('currentFrameSeq', -1)} '
        'observed=${value.optLong('observedFrameSeq', -1)}';
  }

  /// 同一 (route, reason) 的连续拒绝只记一条，且至少间隔 10 秒 —— 有界日志不能被常态拒绝刷掉。
  void recordFrameRejection(String detail) {
    final now = clock.millis();
    final key = detail.split(' requested=')[0];
    if (key == lastFrameRejection && now - lastFrameRejectionAt < frameRejectionIntervalMs) {
      return;
    }
    lastFrameRejection = key;
    lastFrameRejectionAt = now;
    recordDiagnostic('VSCREEN_INPUT_REJECTED', detail);
  }

  /// 诊断记录会写文件，一律交给 WORKER：绝不占住 ACTIONS 串行通道，也不在 LOCK 里落盘。
  void recordDiagnostic(String stage, String detail) {
    try {
      worker.execute(() {
        try {
          diagnostics(stage, detail);
        } catch (e) {
          // 原版吞掉。
        }
      });
    } catch (e) {
      // 原版吞掉。
    }
  }

  Map<String, Object?> missingSnapshot(String? requiredGeneration) {
    if (lifecycleState.cleanupPending()) {
      return decorate(failure('VSCREEN_${lifecycleState.wireName}'));
    }
    if (requiredGeneration != null &&
        (requiredGeneration.isEmpty || generation != requiredGeneration)) {
      return failure('STALE_GENERATION');
    }
    return failure(token.isEmpty
        ? 'VSCREEN_NOT_RUNNING'
        : starting
            ? 'VSCREEN_START_IN_PROGRESS'
            : 'VSCREEN_REVOKED');
  }

  Map<String, Object?> performRequired(
      String gen, String route, String query, VscreenRequestScope scope) {
    final session = snapshot(gen, scope);
    return session == null ? missingSnapshot(gen) : perform(session, route, query, false);
  }

  /// 「执行后状态已变」判定：保留真实结果 + 标记；未执行才给稳定拒绝码。
  static Map<String, Object?> afterExecutionOrNotExecuted(Map<String, Object?> value,
      bool mutating, String marker, String notExecutedError) {
    if (mutating && value.optBoolean('executionUnknown')) return value;
    if (mutating && value.optBoolean('ok')) return markedAfterExecution(value, marker);
    return value.optBoolean('ok') ? failure(notExecutedError) : value;
  }

  static Map<String, Object?> markedAfterExecution(Map<String, Object?> value, String marker) {
    value.put(marker, true);
    return value;
  }

  void tagLocked(Map<String, Object?> value) {
    value
      ..put('channel', channel)
      ..put('managerEpoch', activeEpoch)
      ..put('managerRevision', stateRevision);
  }

  bool frameCurrent(Map<String, Object?> value) =>
      value.optBoolean('ok') &&
      token.isNotEmpty &&
      !starting &&
      activeEpoch == lifecycleEpoch &&
      value.optLong('managerEpoch', -2) == activeEpoch &&
      value.optLong('managerRevision', -2) == stateRevision &&
      generation == value.optString('generation') &&
      value.optLong('frameSeq', -1) >= frameSequence;

  Map<String, Object?> _request(String route, String query, VscreenRequestScope scope) =>
      perform(snapshot(null, scope), route, query, false);

  /// 启动（原版 `start(orientation)`）。
  Map<String, Object?> start(String orientation,
      [VscreenRequestScope? scope, bool foreground = false]) {
    final s = scope ?? localScope();
    final outcome = startOrdered(orientation, s);
    rememberStartOutcome(outcome);
    return outcome;
  }

  /// 安全启动结果（原版 `safeStartOutcome`）：只保留可判定码。
  static Map<String, Object?> safeStartOutcome(Map<String, Object?>? value) {
    final safe = <String, Object?>{'ok': value != null && value.optBoolean('ok')};
    if (value == null) {
      safe.put('error', 'VSCREEN_START_RESULT_UNKNOWN');
      return safe;
    }
    for (final key in const ['error', 'reason']) {
      final code = value.optString(key);
      if (code.isNotEmpty) {
        final known = key == 'reason'
            ? const {'FRAME_NOT_OBSERVED', 'FRAME_EXPIRED', 'OBSERVATION_TIMEOUT'}
                    .contains(code) ||
                startNotSentReason(code) == code
            : !code.startsWith('VSCREEN_CORE_') &&
                code == VscreenBootstrap.diagnosticCode(code);
        safe.put(key, known ? code : 'UNCLASSIFIED_FAILURE');
      }
    }
    if (value.has('cause')) safe.put('causeOmitted', true);
    return safe;
  }

  void rememberStartOutcome(Map<String, Object?> value) {
    try {
      final safe = safeStartOutcome(value);
      final fields = <String, Object?>{};
      for (final key in const ['ok', 'error', 'reason', 'causeOmitted']) {
        if (safe.has(key)) fields[key] = safe[key];
      }
      final outcomeEpoch = epoch();
      fields
        ..put('state', lifecycleState.wireName)
        ..put('starting', starting)
        ..put('launchDispatched', launchDispatched)
        ..put('cleanupPending', lifecycleState.cleanupPending())
        ..put('coreKnown', core != null)
        ..put('pendingKnown', pendingCleanup != null)
        ..put('generationKnown', generation.isNotEmpty)
        ..put('channel', channel);
      lastStartOutcomeJson = jsonEncode(safe);
      recordDiagnostic('VSCREEN_START_RESULT', 'epoch=$outcomeEpoch ${jsonEncode(fields)}');
    } catch (e) {
      // 诊断保存失败不能改变本次动作或解除未确认的退出屏障。
    }
  }

  void recordStartException(String stage, Object? error) {
    final failureEpoch = epoch();
    try {
      worker.execute(() {
        try {
          final captured = failureCapture(stage, error, startExceptionSafeCodes);
          diagnostics(stage, 'epoch=$failureEpoch ${jsonEncode(captured ?? {})}');
        } catch (e) {
          // 原版吞掉。
        }
      });
    } catch (e) {
      // 原版吞掉。
    }
  }

  /// 启动流水线（原版 `startOrdered`）。
  Map<String, Object?> startOrdered(String orientation, VscreenRequestScope scope) {
    if (lowAndroid) return failure('VSCREEN_UNSUPPORTED_LOW');
    if (!supported()) return failure('VSCREEN_API_30_REQUIRED');
    if (orientation != 'portrait' && orientation != 'landscape') {
      return failure('INVALID_ORIENTATION');
    }
    if (!scope.current()) return failure('SCREEN_TARGET_CHANGED');
    if (pendingCleanup != null) closeDetached(pendingCleanup);
    if (lifecycleState == VscreenLifecycleState.startUnknown && bootChanged()) {
      lifecycleState = VscreenLifecycleState.stopped;
      attemptBoot = '';
      stateRevision++;
      saveJournal();
    }
    if (lifecycleState.cleanupPending()) {
      return decorate(failure('VSCREEN_${lifecycleState.wireName}'));
    }
    final width = orientation == 'landscape' ? 1792 : 1008;
    final height = orientation == 'landscape' ? 1008 : 1792;
    final existing = snapshot(null, scope);
    if (existing != null) {
      final result =
          perform(existing, '/vscreen/create', 'width=$width&height=$height', true);
      if (result.optBoolean('ok')) _visuals.present();
      return decorate(result);
    }
    int launchEpoch;
    if (starting) return failure('VSCREEN_START_IN_PROGRESS');
    if (token.isNotEmpty) return failure('VSCREEN_REVOKED');
    starting = true;
    launchDispatched = false;
    lifecycleState = VscreenLifecycleState.starting;
    launchEpoch = ++lifecycleEpoch;
    stateRevision++;
    VscreenChannel? selected;
    try {
      selected = channels.choose();
    } on Exception catch (unavailable) {
      recordStartException('VSCREEN_CHANNEL_SELECTION_FAILED', unavailable);
      failStart(launchEpoch);
      return failure('DEVICE_CHANNEL_UNAVAILABLE');
    }
    if (selected == null) {
      failStart(launchEpoch);
      return failure('DEVICE_CHANNEL_UNAVAILABLE');
    }
    final command = launcher.launchCommand();
    if (epoch() != launchEpoch || !starting) return failure('VSCREEN_START_CANCELLED');
    channel = selected.id();
    attemptBoot = currentBoot();
    stateRevision++;
    if (attemptBoot.isEmpty || !saveJournal()) {
      failStart(launchEpoch);
      return failure('VSCREEN_JOURNAL_UNAVAILABLE');
    }
    VscreenHandshake? launched;
    var dispatched = false;
    try {
      if (!scope.claim()) {
        failStart(launchEpoch);
        return failure('SCREEN_TARGET_CHANGED');
      }
      if (selected.id() == 'adb') reserveAdbLaunch(command, launchEpoch);
      if (epoch() != launchEpoch || !starting) {
        return decorate(failure('VSCREEN_START_CANCELLED'));
      }
      launchDispatched = true;
      dispatched = true;
      final receipt = selected.startTyped(command);
      if (receipt.state == TransportState.notSent &&
          selected.id() == receipt.transport &&
          receipt.localExitConfirmed &&
          receipt.outputComplete &&
          receipt.exitCode == null &&
          !receipt.remoteExitConfirmed) {
        final reason = startNotSentReason(receipt.code);
        final committed = persistStartNotSent(launchEpoch, selected.id(), reason);
        if (committed == CleanupCommit.superseded) return failure('VSCREEN_START_CANCELLED');
        if (committed == CleanupCommit.journalUnavailable) markStartUnknown(launchEpoch);
        final rejected = failure(committed == CleanupCommit.committed
            ? 'DEVICE_CHANNEL_UNAVAILABLE'
            : 'VSCREEN_JOURNAL_UNAVAILABLE');
        rejected
          ..put('state', 'NOT_SENT')
          ..put('reason', reason);
        return decorate(rejected);
      }
      final output = receipt.output;
      final launchedHandle = VscreenHandshake.started(output);
      if (launchedHandle == null) {
        markStartUnknown(launchEpoch);
        final reason = VscreenBootstrap.error(output);
        recordDiagnostic('VSCREEN_START',
            reason.isEmpty ? 'VSCREEN_START_RESULT_UNKNOWN' : 'VSCREEN_$reason');
        return decorate(failure('VSCREEN_START_UNKNOWN'));
      }
      launched = launchedHandle;
      registerKnownSecret(launched.token);
      final authorizedNow = scope.current();
      final admitted = epoch() == launchEpoch && starting && authorizedNow;
      if (admitted) {
        core = launched;
        token = launched.token;
        port = launched.port;
        activeEpoch = launchEpoch;
        stateRevision++;
      }
      if (!admitted || !saveJournal()) {
        cleanupLaunched(launched, selected.id());
        return decorate(failure('VSCREEN_START_CANCELLED'));
      }
      final created = requestAt(
          launched.port, launched.token, '/vscreen/create', 'width=$width&height=$height');
      recordCreateOutcome(created);
      final live = scope.current();
      final committed =
          live && epoch() == launchEpoch && identical(core, launched) && created.optBoolean('ok');
      if (committed) {
        starting = false;
        lifecycleState = VscreenLifecycleState.ready;
        generation = created.optString('generation');
        frameSequence = created.optLong('frameSeq', -1);
        stateRevision++;
        tagLocked(created);
      }
      if (!committed) {
        cleanupLaunched(launched, selected.id());
        return decorate(
            created.optBoolean('ok') ? failure('VSCREEN_START_CANCELLED') : created);
      }
      if (!saveJournal()) {
        cleanupLaunched(launched, selected.id());
        return decorate(failure('VSCREEN_JOURNAL_UNAVAILABLE'));
      }
      final scheduled = worker.scheduleWithFixedDelay(
          () => _heartbeatTick(launchEpoch), 10000, 10000);
      if (epoch() == launchEpoch && activeEpoch == launchEpoch) {
        heartbeat = scheduled;
      } else {
        scheduled.cancel();
      }
      _visuals.present();
      return decorate(created);
    } catch (error) {
      recordStartException('VSCREEN_START_EXCEPTION', error);
      if (launched != null) {
        cleanupLaunched(launched, selected.id());
      } else if (dispatched) {
        markStartUnknown(launchEpoch);
      } else {
        failStart(launchEpoch);
      }
      return decorate(
          failure(dispatched ? 'VSCREEN_START_UNKNOWN' : 'VSCREEN_START_CANCELLED'));
    } finally {
      cancelAdbLaunch(launchEpoch);
    }
  }

  void markStartUnknown(int launchEpoch) {
    if (core == null &&
        (epoch() == launchEpoch || lifecycleState == VscreenLifecycleState.startUnknown)) {
      starting = false;
      lifecycleState = VscreenLifecycleState.startUnknown;
      stateRevision++;
    }
    saveJournal();
  }

  /// Only a native typed pre-send fact can commit this exact launch as safely stopped.
  CleanupCommit persistStartNotSent(
      int launchEpoch, String transportId, String reason) {
    final storage = journal;
    if (storage == null) return CleanupCommit.journalUnavailable;
    try {
      if (!startNotSentCurrentLocked(launchEpoch, transportId)) {
        return CleanupCommit.superseded;
      }
      final revision = ++stateRevision;
      final terminal = <String, Object?>{
        'state': 'STOPPED',
        'boot': '',
        'channel': '',
        'handle': '',
        'lastStartOutcome': 'NOT_SENT',
        'lastStartReason': reason,
      };
      if (!storage.save(revision, terminal)) return CleanupCommit.superseded;
      if (!startNotSentCurrentLocked(launchEpoch, transportId) || stateRevision != revision) {
        return CleanupCommit.superseded;
      }
      starting = false;
      launchDispatched = false;
      lifecycleState = VscreenLifecycleState.stopped;
      token = '';
      channel = '';
      generation = '';
      port = 0;
      activeEpoch = -1;
      attemptBoot = '';
      frameSequence = -1;
      return CleanupCommit.committed;
    } catch (unavailable) {
      lastError = 'VSCREEN_JOURNAL_UNAVAILABLE';
      recordStartException('VSCREEN_JOURNAL_SAVE_FAILED', unavailable);
      return CleanupCommit.journalUnavailable;
    }
  }

  bool startNotSentCurrentLocked(int launchEpoch, String transportId) =>
      epoch() == launchEpoch &&
      starting &&
      core == null &&
      pendingCleanup == null &&
      channel == transportId;

  /// 未发送原因白名单（原版 `startNotSentReason`，逐字）。
  static String startNotSentReason(String code) => const {
        'ROOT_NOT_ENABLED',
        'ROOT_UNAVAILABLE',
        'DEVICE_POLICY_BLOCKED',
        'SELF_PACKAGE_UNVERIFIED',
        'DEVICE_CANCELLED_BEFORE_SEND',
        'DEVICE_RUNNER_BUSY',
        'SHIZUKU_SERVICE_NOT_READY',
        'VSCREEN_START_NOT_SENT',
        'VSCREEN_ADB_INVALID_TICKET',
        'VSCREEN_ADB_CANCELLED_BEFORE_START',
        'VSCREEN_ADB_ENVIRONMENT_BUSY',
        'VSCREEN_ADB_NOT_COMMITTED',
      }.contains(code)
          ? code
          : 'VSCREEN_START_NOT_SENT';

  void cleanupLaunched(VscreenHandshake launched, String selectedChannel) {
    core = launched;
    token = launched.token;
    port = launched.port;
    channel = selectedChannel;
    final closed = detachLocked();
    closeDetached(closed);
  }

  void _heartbeatTick(int launchEpoch) {
    final session = snapshot(null, VscreenRequestScope(null, null, null, ''));
    if (session == null || session.identity.epoch != launchEpoch) return;
    final selected = channels.find(session.channel);
    final available = selected != null && selected.available();
    final ping = available
        ? perform(session, '/vscreen/ping', '', false)
        : failure('DEVICE_CHANNEL_UNAVAILABLE');
    if (!ping.optBoolean('ok')) {
      if (currentLocked(session)) lifecycleState = VscreenLifecycleState.disconnected;
      stopIfCurrent(session);
    }
  }

  Map<String, Object?> status([VscreenRequestScope? scope]) =>
      decorate(_request('/vscreen/status', '', scope ?? localScope()));

  Map<String, Object?> preview([VscreenRequestScope? scope]) =>
      _request('/vscreen/preview', '', scope ?? localScope());

  /// agent see（原版 `agentSee`）：DISPLAY 证据外一律 `CORE_EVIDENCE_REQUIRED`。
  Map<String, Object?> agentSee(VscreenRequestScope scope) {
    final request = scope.request;
    final target = request?.target;
    if (target is VscreenTargetEvidence && target.observation != Observation.display) {
      return failure('CORE_EVIDENCE_REQUIRED');
    }
    if (request == null ||
        !semantics.service.isConnected() ||
        target is! VscreenTargetEvidence ||
        target.windowId < 0 ||
        target.consentRevision < 0) {
      final image = preview(scope);
      image
        ..put('anchoredAvailable', false)
        ..put('availabilityReason', 'ANCHOR_ACCESSIBILITY_UNAVAILABLE')
        ..put('sourceFrameSeq', image.optLong('frameSeq', -1));
      return image;
    }
    return observed('see', null, -1, '', -1, -1, scope);
  }

  /// 观察/锚点/受管点击编排（原版 `observed`）。
  Map<String, Object?> observed(String operation, String? gen, int source, String id,
      int x, int y, VscreenRequestScope scope) {
    final session = snapshot(gen, scope);
    if (session == null) return missingSnapshot(gen);
    if (scope.request == null) return failure('EXPLICIT_SCREEN_REQUEST_REQUIRED');
    final info = perform(session, '/vscreen/status', '', false, false);
    if (!info.optBoolean('ok')) return info;
    try {
      final args = <String, Object?>{
        'coreInstance': session.coreInstance,
        'generation': session.identity.generation,
        'frameSeq': source,
        'managerEpoch': session.identity.epoch,
        'managerRevision': session.identity.revision,
        operation == 'anchor' ? 'observationId' : 'anchorId': id,
        'x': x,
        'y': y,
      };
      final endpoint = core;
      if (endpoint == null || endpoint.identity.instance != session.coreInstance) {
        return failure('VSCREEN_CORE_IDENTITY_CHANGED');
      }
      final pixels = _ObservedPixelsBridge(this, session, endpoint);
      final result = semantics.observed(scope.broker, scope.request, () => current(session),
          info.optInt('displayId', -1), operation, args, pixels);
      return current(session)
          ? result
          : afterExecutionOrNotExecuted(
              result,
              operation == 'anchored-click',
              ScreenActionResult.runChangedAfterExecution,
              'VSCREEN_REVOKED');
    } catch (unavailable) {
      return failure('ANCHOR_NOT_AVAILABLE');
    }
  }

  /// 观察释放排队（原版 `queueObservationRelease`）：只走原始认证端点。
  void queueObservationRelease(VscreenHandshake endpoint, String id) {
    final key = '${endpoint.identity.instance}:$id';
    // Core 至多持有两份原始拷贝；被顶替的清理由其驱逐/TTL 覆盖——丢弃一次清理请求
    // 既不授权过期本地租约，也不证明字节已释放。
    while (observationReleases.length >= 2 && !observationReleases.containsKey(key)) {
      observationReleases.remove(observationReleases.keys.first);
    }
    observationReleases[key] = () {
      transport.request(
          endpoint, '/vscreen/observation-release', 'observationId=${encode(id)}');
    };
    if (!observationReleaseScheduled) scheduleObservationReleases();
  }

  void scheduleObservationReleases() {
    observationReleaseScheduled = true;
    try {
      worker.execute(drainObservationReleases);
    } catch (stopped) {
      observationReleaseScheduled = false;
      observationReleases.clear();
    }
  }

  void drainObservationReleases() {
    for (var count = 0; count < 2; count++) {
      void Function()? release;
      if (observationReleases.isEmpty) break;
      final key = observationReleases.keys.first;
      release = observationReleases.remove(key);
      try {
        release?.call();
      } catch (e) {
        // 原版吞掉。
      }
    }
    observationReleaseScheduled = false;
    if (observationReleases.isNotEmpty) scheduleObservationReleases();
  }

  /// 授权与语义操作只需要本次显示身份；旧像素元数据不能阻断它们。
  Map<String, Object?> targetStatus([VscreenRequestScope? scope]) =>
      perform(snapshot(null, scope ?? localScope()), '/vscreen/status', '', false, false);

  Map<String, Object?> previewSince(String gen, int seq, [VscreenRequestScope? scope]) =>
      _request('/vscreen/preview', 'since=$seq&generation=${encode(gen)}',
          scope ?? localScope());

  Map<String, Object?> touch(String gen, int seq, String stroke, int action, double x,
      double y,
      [VscreenRequestScope? scope]) {
    return performRequired(
        gen,
        '/vscreen/touch',
        'generation=${encode(gen)}&frameSeq=$seq&stroke=$stroke&action=$action&x=$x&y=$y',
        scope ?? localScope());
  }

  /// 编辑器编排（原版 `editor`）：edit/submit 可能已写入，只有只读 editor 报「未执行」（#140）。
  Map<String, Object?> editor(String gen, String operation, Map<String, Object?> args,
      [VscreenRequestScope? scope]) {
    final s = scope ?? localScope();
    final session = snapshot(gen, s);
    if (session == null) return missingSnapshot(gen);
    final info = perform(session, '/vscreen/status', '', false, false);
    if (!info.optBoolean('ok')) return info;
    if (!current(session)) return failure('VSCREEN_REVOKED');
    final result = semantics.control(s.broker, s.request, () => current(session),
        info.optInt('displayId', -1), operation, args);
    if (current(session)) return result;
    return afterExecutionOrNotExecuted(
        result,
        VscreenRoutes.mutates(operation),
        ScreenActionResult.targetChangedAfterExecution,
        'SCREEN_TARGET_CHANGED');
  }

  Map<String, Object?> tree([VscreenRequestScope? scope]) {
    final s = scope ?? localScope();
    final session = snapshot(null, s);
    final frame = perform(session, '/vscreen/status', '', false, false);
    if (!frame.optBoolean('ok')) return frame;
    if (!current(session)) return failure('VSCREEN_REVOKED');
    final result = semantics.control(s.broker, s.request, () => current(session),
        frame.optInt('displayId', -1), 'tree', <String, Object?>{});
    if (!current(session)) return failure('SCREEN_TARGET_CHANGED');
    result
      ..put('generation', frame.optString('generation'))
      ..put('frameSeq', frame.optLong('frameSeq'))
      ..put('displayId', frame.optInt('displayId'));
    return result;
  }

  /// node 编排（原版 `node`）：像素帧门只对坐标注入有意义，node 走无障碍树判定（issue #117）。
  Map<String, Object?> node(String gen, int seq, String node, String action, String text,
      [VscreenRequestScope? scope]) {
    final s = scope ?? localScope();
    final session = snapshot(gen, s);
    if (session == null) return missingSnapshot(gen);
    final info = perform(session, '/vscreen/status', '', false, false);
    if (!info.optBoolean('ok')) return info;
    if (!current(session)) return failure('VSCREEN_REVOKED');
    try {
      final result = semantics.control(s.broker, s.request, () => current(session),
          info.optInt('displayId', -1), 'node', {
        'nodeId': node,
        'action': action,
        'text': text,
      });
      return current(session)
          ? result
          : afterExecutionOrNotExecuted(result, true,
              ScreenActionResult.targetChangedAfterExecution, 'SCREEN_TARGET_CHANGED');
    } catch (invalid) {
      return failure('INVALID_NODE_ACTION');
    }
  }

  Map<String, Object?> launch(String? pkg, [VscreenRequestScope? scope]) {
    if (pkg == null ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+$').hasMatch(pkg)) {
      return failure('INVALID_PACKAGE');
    }
    final s = scope ?? localScope();
    if (!s.claim()) return failure('SCREEN_TARGET_CHANGED');
    semantics.clear();
    return _request('/vscreen/launch', 'package=${encode(pkg)}', s);
  }

  Map<String, Object?> action(String action, String gen, int seq, String params,
      [VscreenRequestScope? scope]) {
    return performRequired(
        gen,
        '/vscreen/$action',
        'generation=${encode(gen)}&frameSeq=$seq${params.isEmpty ? '' : '&$params'}',
        scope ?? localScope());
  }

  /// 文本输入（原版 `type`）：ASCII 走命令；Unicode 需要无障碍（原语义保留）。
  Map<String, Object?> type(String gen, int seq, String text,
      [VscreenRequestScope? scope]) {
    if (text.isEmpty || text.length > 2000) return failure('INVALID_TEXT');
    final s = scope ?? localScope();
    final session = snapshot(gen, s);
    if (session == null) return missingSnapshot(gen);
    final query = 'generation=${encode(gen)}&frameSeq=$seq';
    if (RegExp(r'^[\x20-\x7e]+$').hasMatch(text)) {
      return perform(session, '/vscreen/type', '$query&text=${encode(text)}', false);
    }
    if (!semantics.service.isConnected()) {
      return failure('ACCESSIBILITY_REQUIRED_FOR_UNICODE');
    }
    final check = perform(session, '/vscreen/check', query, false);
    if (!check.optBoolean('ok')) return check;
    if (!current(session)) return failure('VSCREEN_REVOKED');
    final result = semantics.type(s.broker, s.request, () => current(session),
        check.optInt('displayId', -1), text);
    return current(session)
        ? result
        : afterExecutionOrNotExecuted(result, true,
            ScreenActionResult.targetChangedAfterExecution, 'SCREEN_TARGET_CHANGED');
  }

  _ClosedSession? detachLocked() {
    final stopped = lifecycleEpoch++;
    semantics.invalidateObserved();
    cleanupProbe?.cancel();
    cleanupProbe = null;
    final unresolvedStart = starting && core == null && launchDispatched;
    starting = false;
    launchDispatched = false;
    cancelAdbLaunch(stopped);
    heartbeat?.cancel();
    heartbeat = null;
    final closed = core != null
        ? _ClosedSession(core, channel, stopped + 1)
        : pendingCleanup == null
            ? null
            : _ClosedSession(pendingCleanup!.handle, pendingCleanup!.channel, stopped + 1);
    if (closed != null) {
      pendingCleanup = closed;
      lifecycleState = lifecycleState == VscreenLifecycleState.disconnected
          ? VscreenLifecycleState.disconnected
          : VscreenLifecycleState.closing;
    } else if (unresolvedStart || lifecycleState == VscreenLifecycleState.startUnknown) {
      lifecycleState = VscreenLifecycleState.startUnknown;
    } else {
      lifecycleState = VscreenLifecycleState.stopped;
    }
    core = null;
    token = '';
    channel = '';
    generation = '';
    port = 0;
    activeEpoch = -1;
    stateRevision++;
    frameSequence = -1;
    return closed;
  }

  /// 拆除会话（原版 `closeDetached`）：close 回复只证明 release；只有绑定的只读出生探针关账。
  Map<String, Object?> closeDetached(_ClosedSession? closed) {
    semantics.clearObserved();
    saveJournal();
    if (closed == null) {
      final fence = epoch();
      if (epoch() == fence) semantics.clear();
      _visuals.stopped(fence);
      return decorate(lifecycleState == VscreenLifecycleState.stopped
          ? success()
          : failure('VSCREEN_${lifecycleState.wireName}'));
    }
    final release =
        requestAt(closed.port, closed.token, '/vscreen/close', '');
    final proof = probeClosed(closed, 3);
    final commit = proof == VscreenExit.exited
        ? persistCleanupExited(closed)
        : CleanupCommit.notProven;
    final completed = commit == CleanupCommit.committed;
    if (!completed && cleanupCurrentLocked(closed)) {
      lifecycleState = VscreenLifecycleState.closeUnknown;
      stateRevision++;
    }
    if (!completed) {
      saveJournal();
      scheduleCleanupProbe(closed, 0);
    }
    if (epoch() == closed.fence) semantics.clear();
    _visuals.stopped(closed.fence);
    final result = completed ? success() : failure('VSCREEN_CLOSE_UNKNOWN');
    result
      ..put('coreExitProof', proof.wireName)
      ..put('displayReleaseAcknowledged', release.optBoolean('ok'));
    if (commit == CleanupCommit.journalUnavailable) {
      result.put('reason', 'VSCREEN_JOURNAL_UNAVAILABLE');
    } else if (commit == CleanupCommit.superseded) {
      result.put('reason', 'VSCREEN_CLOSE_SUPERSEDED');
    }
    return decorate(result);
  }

  bool cleanupCurrentLocked(_ClosedSession closed) =>
      identical(pendingCleanup, closed) && epoch() == closed.fence && core == null;

  /// Read-only birth probes use the original channel and identity; never resend close or input.
  VscreenExit probeClosed(_ClosedSession closed, int attempts) {
    var proof = VscreenExit.unknown;
    final probeEpoch = closed.fence;
    try {
      if (!cleanupCurrentLocked(closed)) {
        closed.probeReason = 'IDENTITY_SUPERSEDED';
        return proof;
      }
      final selected = channels.find(closed.channel);
      if (selected == null || !selected.available()) {
        closed.probeReason = 'ORIGINAL_CHANNEL_UNAVAILABLE';
        return proof;
      }
      final command = launcher.probeCommand(closed.handle!.identity.encode());
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (!cleanupCurrentLocked(closed)) {
          closed.probeReason = 'IDENTITY_SUPERSEDED';
          return VscreenExit.unknown;
        }
        if (closed.channel == 'adb' &&
            !adbProbe.issue(randomToken(), command, probeEpoch, clock.millis(), _adbLaunchTtlMs)) {
          closed.probeReason = 'ADB_PROBE_AUTHORITY_UNAVAILABLE';
          return VscreenExit.unknown;
        }
        try {
          proof = closed.handle!.identity.proof(selected.start(command));
          closed.probeReason = proof == VscreenExit.exited
              ? 'EXIT_CONFIRMED'
              : proof == VscreenExit.alive
                  ? 'CORE_STILL_ALIVE'
                  : 'EXIT_PROBE_REPLY_UNKNOWN';
        } finally {
          adbProbe.cancel(probeEpoch);
        }
        if (proof != VscreenExit.alive || attempt + 1 == attempts) break;
        sleep(const Duration(milliseconds: 50)); // 原版 Thread.sleep(50)
      }
    } on VscreenInterruptedException {
      closed.probeReason = 'EXIT_PROBE_INTERRUPTED';
    } catch (unavailable) {
      proof = VscreenExit.unknown;
      closed.probeReason = 'EXIT_PROBE_UNAVAILABLE';
    } finally {
      adbProbe.cancel(probeEpoch);
    }
    return proof;
  }

  void scheduleCleanupProbe(_ClosedSession closed, int attempt) {
    if (!cleanupCurrentLocked(closed) ||
        lifecycleState != VscreenLifecycleState.closeUnknown ||
        attempt < 0 ||
        attempt >= _cleanupProbeAttempts) {
      return;
    }
    // Single lifecycle worker: at most one original-channel probe is in flight. Its existing
    // transport deadline still applies; a stalled/unknown transport never becomes exit proof.
    try {
      cleanupProbe = worker.schedule(
          () => reconcileCleanup(closed, attempt), cleanupProbeDelayMillis(attempt));
    } catch (stopped) {
      cleanupProbe = null;
    }
  }

  void reconcileCleanup(_ClosedSession closed, int attempt) {
    if (!cleanupCurrentLocked(closed) ||
        lifecycleState != VscreenLifecycleState.closeUnknown) {
      return;
    }
    final proof = probeClosed(closed, 1);
    if (proof == VscreenExit.exited && persistCleanupExited(closed) == CleanupCommit.committed) {
      return;
    }
    scheduleCleanupProbe(closed, attempt + 1);
  }

  /// Both the initial close and later read-only checks keep the barrier until durable commit.
  CleanupCommit persistCleanupExited(_ClosedSession closed) {
    final storage = journal;
    if (storage == null) return CleanupCommit.journalUnavailable;
    try {
      if (!cleanupCurrentLocked(closed)) return CleanupCommit.superseded;
      final revision = ++stateRevision;
      final terminal = <String, Object?>{
        'state': 'STOPPED',
        'boot': '',
        'channel': '',
        'handle': '',
      };
      if (!storage.save(revision, terminal)) return CleanupCommit.superseded;
      if (!cleanupCurrentLocked(closed) || stateRevision != revision) {
        return CleanupCommit.superseded;
      }
      pendingCleanup = null;
      lifecycleState = VscreenLifecycleState.stopped;
      attemptBoot = '';
      cleanupProbe = null;
      return CleanupCommit.committed;
    } catch (unavailable) {
      lastError = 'VSCREEN_JOURNAL_UNAVAILABLE';
      recordStartException('VSCREEN_JOURNAL_SAVE_FAILED', unavailable);
      return CleanupCommit.journalUnavailable;
    }
  }

  Map<String, Object?> stopResult() {
    final closed = detachLocked();
    return closeDetached(closed);
  }

  Map<String, Object?> closeExpected(String expectedCore) {
    final handle = core ?? pendingCleanup?.handle;
    if (handle != null && handle.identity.instance != expectedCore) {
      return identityFailure(expectedCore.isEmpty
          ? 'VSCREEN_CORE_IDENTITY_REQUIRED'
          : 'VSCREEN_CORE_IDENTITY_CHANGED');
    }
    if (handle == null && expectedCore.isNotEmpty) {
      return identityFailure('VSCREEN_CORE_IDENTITY_CHANGED');
    }
    return closeDetached(detachLocked());
  }

  Map<String, Object?> close() => stopResult();

  void stop() {
    stopResult();
  }

  void stopIfCurrent(VscreenSnapshot session) {
    if (!currentLocked(session)) return;
    closeDetached(detachLocked());
  }

  void discardObservations() {
    semantics.clearObserved();
  }

  void revoke() {
    final previous = lifecycleEpoch++;
    discardObservations();
    adbLaunch.cancel(previous);
    final revoked = previous + 1;
    worker.execute(() {
      if (epoch() != revoked) return;
      closeDetached(detachLocked());
    });
  }

  void failStart(int launchEpoch) {
    if (epoch() == launchEpoch) {
      starting = false;
      launchDispatched = false;
      lifecycleState = VscreenLifecycleState.stopped;
      token = '';
      channel = '';
      generation = '';
      port = 0;
      activeEpoch = -1;
      stateRevision++;
      frameSequence = -1;
    }
    saveJournal();
  }

  /// 结果装饰（原版 `decorate`）：生命周期信封 + 状态归类。
  Map<String, Object?> decorate(Map<String, Object?> value) {
    try {
      final cleanup = pendingCleanup;
      final state = lifecycleState;
      value
        ..put('lifecycleState', state.wireName)
        ..put('cleanupPending', state.cleanupPending())
        ..put('protocol', 1);
      if (state.cleanupPending()) {
        final recoverable = cleanup != null && cleanup.handle != null;
        final c = recoverable ? cleanup : null;
        value
          ..put('cleanupIdentityAvailable', recoverable)
          ..put(
              'cleanupChannel',
              c != null && const {'root', 'shizuku', 'adb'}.contains(c.channel)
                  ? c.channel
                  : 'UNKNOWN')
          ..put('cleanupProbeReason',
              c != null ? c.probeReason : 'IDENTITY_NOT_CAPTURED');
      }
      if (!value.has('state')) {
        value.put(
            'state',
            value.optBoolean('executionUnknown')
                ? 'UNKNOWN'
                : value.optBoolean('ok')
                    ? 'COMPLETED'
                    : 'REJECTED');
      }
      // 成功观察已带快照身份。绝不把 A 重新标成 B。
      final current = core;
      if (!value.has('coreInstance') && !value.optBoolean('ok')) {
        if (current != null) {
          value.put('coreInstance', current.identity.instance);
        } else if (cleanup != null) {
          value.put('coreInstance', cleanup.handle!.identity.instance);
        }
      }
    } catch (e) {
      // 原版忽略。
    }
    return value;
  }

  bool bootChanged() {
    final boot = currentBoot();
    return attemptBoot.isNotEmpty && boot.isNotEmpty && attemptBoot != boot;
  }

  String currentBoot() {
    try {
      final boot = bootSource();
      return RegExp('^$vscreenUuidPattern\$').hasMatch(boot) ? boot : '';
    } on Exception {
      return '';
    }
  }

  /// 日志恢复（原版 `restoreJournal`）。
  void restoreJournal() {
    final storage = journal;
    if (storage == null) return;
    try {
      final record = storage.load();
      if (record == null || record.optString('state') == 'STOPPED') return;
      attemptBoot = record.optString('boot');
      if (bootChanged()) return;
      final payload = record.optString('handle');
      if (payload.isEmpty) {
        lifecycleState = VscreenLifecycleState.startUnknown;
      } else {
        final handle = VscreenHandshake.parse(payload);
        pendingCleanup = _ClosedSession(handle, record.getString('channel'), epoch());
        lifecycleState = VscreenLifecycleState.disconnected;
      }
    } catch (invalid) {
      recordStartException('VSCREEN_JOURNAL_LOAD_FAILED', invalid);
      lifecycleState = VscreenLifecycleState.startUnknown;
      lastError = 'VSCREEN_JOURNAL_INVALID';
    }
  }

  bool saveJournal() {
    final storage = journal;
    if (storage == null) return false;
    try {
      final handle = core ?? pendingCleanup?.handle;
      final record = <String, Object?>{
        'state': lifecycleState.wireName,
        'boot': attemptBoot,
        'channel': core != null ? channel : (pendingCleanup?.channel ?? ''),
        'handle': handle == null ? '' : handle.payload(),
      };
      return storage.save(stateRevision, record);
    } catch (unavailable) {
      lastError = 'VSCREEN_JOURNAL_UNAVAILABLE';
      recordStartException('VSCREEN_JOURNAL_SAVE_FAILED', unavailable);
      return false;
    }
  }

  /// One-shot ADB start authority exists only while this native manager launch is pending.
  void reserveAdbLaunch(String command, int epoch) {
    if (!adbLaunch.issue(randomToken(), command, epoch, clock.millis(), _adbLaunchTtlMs)) {
      throw StateError('VSCREEN_ADB_LAUNCH_BUSY');
    }
  }

  String adbLaunchTicketFor(String command) {
    final ticket = adbLaunch.ticketFor(command, epoch(), clock.millis());
    return ticket.isEmpty
        ? adbProbe.ticketFor(command, epoch(), clock.millis())
        : ticket;
  }

  bool authorizeAdbLaunchPlan(String ticket, String command) =>
      adbLaunch.authorize(ticket, command, epoch(), clock.millis()) ||
      adbProbe.authorize(ticket, command, epoch(), clock.millis());

  bool commitAdbLaunch(String ticket) =>
      adbLaunch.commit(ticket, epoch(), clock.millis()) ||
      adbProbe.commit(ticket, epoch(), clock.millis());

  /// Native helper completion only: no HTTP route can manufacture this pre-send proof.
  bool withdrawUncommittedAdbLaunch(String ticket, String command) {
    final owner = epoch(), now = clock.millis();
    return adbLaunch.withdrawUncommitted(ticket, command, owner, now) ||
        adbProbe.withdrawUncommitted(ticket, command, owner, now);
  }

  void cancelAdbLaunch(int epoch) {
    adbLaunch.cancel(epoch);
  }

  /// 桥入口（原版 `bridge` 三态）。
  String bridge(String route, String query) {
    try {
      return bridgeRequest(VscreenBridgeRequest.query(route, query));
    } on BridgeRequestFailure catch (invalid) {
      return jsonEncode(failure(invalid.code));
    }
  }

  String bridgeRequest(VscreenBridgeRequest request) {
    if (request.operation != VscreenOperation.status &&
        request.operation != VscreenOperation.close) {
      return jsonEncode(failure('EXPLICIT_SCREEN_REQUEST_REQUIRED'));
    }
    return dispatch(request, localScope());
  }

  String bridgeAuthorized(VscreenBridgeRequest request, VscreenRequestScope scope) {
    final caller = request.parameters['coreInstance'] ?? '';
    if (request.requiresExistingCore() || caller.isNotEmpty) {
      if (caller.isEmpty) return jsonEncode(identityFailure('VSCREEN_CORE_IDENTITY_REQUIRED'));
      final target = scope.request?.target;
      if (target is! VscreenTargetEvidence) {
        return jsonEncode(identityFailure('CORE_EVIDENCE_REQUIRED'));
      }
      final handle = core ??
          (request.operation == VscreenOperation.close ? pendingCleanup?.handle : null);
      if (handle == null ||
          caller != handle.identity.instance ||
          caller != target.coreInstance) {
        return jsonEncode(identityFailure('VSCREEN_CORE_IDENTITY_CHANGED'));
      }
      final generation = request.parameters['generation'] ?? '';
      if (generation.isNotEmpty && generation != target.generation) {
        return jsonEncode(identityFailure('VSCREEN_GENERATION_CHANGED'));
      }
    }
    return dispatch(request, scope);
  }

  /// 派发（原版 `dispatch` + `Actions` 实现）。
  String dispatch(VscreenBridgeRequest request, VscreenRequestScope scope) {
    return jsonEncode(decorate(request.execute(_BridgeActions(this, scope, request))));
  }

  /// 创建结果留痕（原版 `recordCreateOutcome`）：失败写稳定码 + 根因摘要；同签名只写一次。
  void recordCreateOutcome(Map<String, Object?>? value) {
    if (value == null) return;
    if (value.optBoolean('ok')) {
      lastCreateFailure = '';
      return;
    }
    try {
      final code = safeStartOutcome(value).optString('error', 'UNCLASSIFIED_FAILURE');
      final graph = value['failure'];
      final origin = value.optString('failureOrigin');
      final nativeGraph = graph is Map<String, Object?> &&
          const {'ANDROID_DISPLAY_CREATE', 'NATIVE_OPERATION'}.contains(origin);
      final signature = '$code:${nativeGraph ? jsonEncode(graph).hashCode : 'omitted'}';
      if (signature == lastCreateFailure) return;
      lastCreateFailure = signature;
      final fields = <String, Object?>{
        'error': code,
        'channel': channel,
        ...failureCaptureMetadata(nativeGraph ? graph : null),
      };
      if (nativeGraph) {
        fields['failureOrigin'] = origin;
        fields['failure'] = graph;
      }
      diagnostics('VSCREEN_CREATE', 'epoch=${epoch()} ${jsonEncode(fields)}');
    } catch (unavailable) {
      recordStartException('VSCREEN_CREATE_DIAGNOSTIC_FAILED', unavailable);
    }
  }

  /// 嵌套生产者图不是顶层 Throwable（原版 `failureCaptureMetadata`）。
  static Map<String, Object?> failureCaptureMetadata(Map<String, Object?>? graph) {
    final omissions = failureGraphOmissions(graph);
    final fields = <String, Object?>{'messageOmitted': (omissions & 2) != 0};
    if ((omissions & 1) != 0) fields['capture'] = 'PARTIAL';
    return fields;
  }

  static int failureGraphOmissions(Map<String, Object?>? graph) {
    if (graph == null) return 3;
    final messageOmitted = graph.optString('messageOmissionReason').isNotEmpty ||
        graph.optLong('omittedMessageChars') > 0;
    var omissions = messageOmitted ? 3 : 0;
    if (graph.optBoolean('truncated') ||
        graph.optBoolean('cycle') ||
        graph.optLong('omittedFrames') > 0 ||
        graph.optLong('omittedSuppressed') > 0) {
      omissions |= 1;
    }
    final cause = graph['cause'];
    if (cause is Map<String, Object?>) omissions |= failureGraphOmissions(cause);
    final suppressed = graph['suppressed'];
    if (suppressed is List) {
      for (final item in suppressed) {
        if (item is Map<String, Object?>) omissions |= failureGraphOmissions(item);
      }
    }
    return omissions;
  }

  Map<String, Object?> requestAt(int port, String token, String route, String query) {
    var endpoint = core;
    final cleanup = pendingCleanup;
    if (endpoint == null || endpoint.port != port || endpoint.token != token) {
      endpoint = cleanup?.handle;
    }
    if (endpoint == null || endpoint.port != port || endpoint.token != token) {
      return failure('VSCREEN_CORE_IDENTITY_REQUIRED');
    }
    return transport.request(endpoint, route, query);
  }

  /// 预览字节（原版 `previewBitmap` 的解码段；Bitmap 实例化留缝）。
  static List<int>? previewBytes(Map<String, Object?> value) {
    try {
      return base64Decode(value.getString('previewB64'));
    } catch (e) {
      return null;
    }
  }

  static Map<String, Object?> responseFailure(String route, String code) {
    final value = failure(VscreenRoutes.mutatesCore(route) ? 'INPUT_RESULT_UNKNOWN' : code);
    if (VscreenRoutes.mutatesCore(route)) value.put('executionUnknown', true);
    return value;
  }

  static String encode(String v) {
    try {
      return Uri.encodeQueryComponent(v);
    } catch (e) {
      return '';
    }
  }

  String randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, Object?> success() => <String, Object?>{'ok': true};

  /// 失败一律给稳定码；`INPUT_RESULT_UNKNOWN`/`VIRTUAL_INPUT_RESULT_UNKNOWN` 带 executionUnknown。
  static Map<String, Object?> failure(String code) {
    final j = <String, Object?>{'ok': false, 'error': code};
    if (code == 'INPUT_RESULT_UNKNOWN' || code == 'VIRTUAL_INPUT_RESULT_UNKNOWN') {
      j['executionUnknown'] = true;
    }
    return j;
  }

  static Map<String, Object?> identityFailure(String code) {
    final value = failure(code);
    value
      ..put('state', 'NOT_SENT')
      ..put('code', code);
    return value;
  }
}

/// 观察像素桥（原版 `observed()` 内的匿名 `ObservedPixels`）。
class _ObservedPixelsBridge implements ObservedPixelsApi {
  _ObservedPixelsBridge(this.manager, this.session, this.endpoint);

  final VscreenManager manager;
  final VscreenSnapshot session;
  final VscreenHandshake endpoint;

  @override
  Map<String, Object?> capture(bool retain) {
    var frame = manager.perform(
        session,
        '/vscreen/observe',
        'generation=${VscreenManager.encode(session.identity.generation)}&retain=$retain',
        false,
        false);
    if (retain &&
        !frame.optBoolean('ok') &&
        const {'OBSERVATION_IMAGE_BUDGET', 'OBSERVATION_IMAGE_UNAVAILABLE'}
            .contains(frame.optString('error'))) {
      final reason = frame.optString('error');
      frame = manager.perform(
          session,
          '/vscreen/observe',
          'generation=${VscreenManager.encode(session.identity.generation)}&retain=false',
          false,
          false);
      frame.put('availabilityReason', reason);
    }
    return frame;
  }

  @override
  Map<String, Object?> region(String observationId, VscreenRect bounds) {
    return manager.perform(
        session,
        '/vscreen/observation-region',
        'generation=${VscreenManager.encode(session.identity.generation)}'
            '&observationId=${VscreenManager.encode(observationId)}'
            '&left=${bounds.left}&top=${bounds.top}&right=${bounds.right}&bottom=${bounds.bottom}',
        false,
        false);
  }

  @override
  void release(String observationId) {
    // Teardown uses only the original authenticated endpoint, never a newly selected core.
    manager.queueObservationRelease(endpoint, observationId);
  }

  @override
  ExpiryHandle expireAfter(void Function() callback, int delayMs) {
    final handle = manager.worker.schedule(callback, delayMs);
    return _WorkerExpiry(handle);
  }
}

class _WorkerExpiry implements ExpiryHandle {
  _WorkerExpiry(this._handle);

  final ScheduledCancellable _handle;

  @override
  void cancel() => _handle.cancel();
}

class _DefaultVisuals implements VscreenVisuals {
  const _DefaultVisuals();

  @override
  void present() {}

  @override
  void stopped(int fence) {}
}

/// 中断异常缝（原版 `InterruptedException`；通道执行面抛出）。
class VscreenInterruptedException implements Exception {}

/// bridge 派发表（原版匿名 `Actions<JSONObject>`）。
class _BridgeActions implements VscreenBridgeActions<Map<String, Object?>> {
  _BridgeActions(this.manager, this.scope, this.request);

  final VscreenManager manager;
  final VscreenRequestScope scope;
  final VscreenBridgeRequest request;

  @override
  Map<String, Object?> create(String orientation) => manager.start(orientation, scope);

  @override
  Map<String, Object?> status() => manager.status(scope);

  @override
  Map<String, Object?> launch(String pkg) => manager.launch(pkg, scope);

  @override
  Map<String, Object?> tree() => manager.tree(scope);

  @override
  Map<String, Object?> node(String generation, int frame, String id, String action, String text) =>
      manager.node(generation, frame, id, action, text, scope);

  @override
  Map<String, Object?> editor(String generation, String mode, String editorId, String text,
          int start, int end) =>
      manager.editor(generation, mode, {
        'editorId': editorId,
        'text': text,
        'start': start,
        'end': end,
      }, scope);

  @override
  Map<String, Object?> touch(String generation, int frame, String stroke, int action,
          double x, double y) =>
      manager.touch(generation, frame, stroke, action, x, y, scope);

  @override
  Map<String, Object?> preview() {
    final result = manager.preview(scope);
    return !result.optBoolean('ok') || manager.frameCurrent(result)
        ? result
        : VscreenManager.failure('VSCREEN_REVOKED');
  }

  @override
  Map<String, Object?> see() => manager.agentSee(scope);

  @override
  Map<String, Object?> anchor(String generation, int frame, String observation, int x, int y) =>
      manager.observed('anchor', generation, frame, observation, x, y, scope);

  @override
  Map<String, Object?> anchoredClick(String generation, int frame, String anchor) =>
      manager.observed('anchored-click', generation, frame, anchor, -1, -1, scope);

  @override
  Map<String, Object?> action(String mode, String generation, int frame, String query) =>
      manager.action(mode, generation, frame, query, scope);

  @override
  Map<String, Object?> type(String generation, int frame, String text) =>
      manager.type(generation, frame, text, scope);

  @override
  Map<String, Object?> close() =>
      manager.closeExpected(request.parameters['coreInstance'] ?? '');
}

/// bootstrap 诊断面直连 `VscreenBootstrap`（D3-2 已移植，此处注释保留原衔接点）。

