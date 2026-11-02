//! Manager 装配（原版 VirtualScreenManager 的 Flutter 壳接线）。
//!
//! 轻件全装（Clock/Launcher/Journal/诊断/失败捕获），语义面（无障碍服务）
//! 与 Channels/Transport 按诚实占位：语义未接报 `ACCESSIBILITY_SERVICE_
//! UNAVAILABLE`，Transport 未接抛 `TRANSPORT_NOT_WIRED`（F2-4 requestAt
//! HTTP 落地后替换）。
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'shizuku_channel.dart';
import 'dart:io' as io;

import 'package:dsha_core/dsha_core.dart';

/// 无障碍服务占位（语义控制面随 F2-3b 真实现；未接不给假结果）。
class NullAccessibilityService implements AccessibilityServiceApi {
  const NullAccessibilityService();

  @override
  bool isConnected() => false;

  @override
  Map<String, Object?> virtualControl(
          VscreenAccessibility session,
          CapabilityBrokerApi broker,
          CapabilityRequestApi request,
          bool Function() current,
          int display,
          String operation,
          Map<String, Object?> args) =>
      vscreenFailure('ACCESSIBILITY_SERVICE_UNAVAILABLE', false);

  @override
  Map<String, Object?> virtualObservedControl(
          VscreenAccessibility session,
          CapabilityBrokerApi broker,
          CapabilityRequestApi request,
          bool Function() current,
          int display,
          String operation,
          Map<String, Object?> args,
          ObservedPixelsApi pixels) =>
      vscreenFailure('ACCESSIBILITY_SERVICE_UNAVAILABLE', false);

  @override
  Map<String, Object?> typeVirtual(CapabilityBrokerApi broker,
          CapabilityRequestApi request, bool Function() current, int display,
          String text) =>
      vscreenFailure('ACCESSIBILITY_SERVICE_UNAVAILABLE', false);

  @override
  Map<String, Object?> typeVirtualUser(
          int display, String text, bool Function() current) =>
      vscreenFailure('ACCESSIBILITY_SERVICE_UNAVAILABLE', false);
}

/// Manager 装配五参（channel `my_app/runtime` 契约输入）。
class VscreenRuntimeInputs {
  const VscreenRuntimeInputs({
    required this.sourceDir,
    required this.packageName,
    required this.root,
    required this.installation,
  });
  final String sourceDir;
  final String packageName;
  final io.Directory root;

  /// 安装根标识（journal 身份缝；app 私有数据目录）。
  final String installation;
}

/// 从宿主收集装配五参（Android channel；桌面 fallback 走 dataDir）。
Future<VscreenRuntimeInputs> loadVscreenRuntimeInputs() async {
  const channel = MethodChannel('my_app/runtime');
  final sourceDir = await channel.invokeMethod<String>('sourceDir') ?? '';
  final packageName = await channel.invokeMethod<String>('packageName') ?? '';
  final dataDir = await channel.invokeMethod<String>('dataDir') ?? '';
  return VscreenRuntimeInputs(
    sourceDir: sourceDir,
    packageName: packageName,
    root: io.Directory('$dataDir/vscreen_session')..createSync(recursive: true),
    installation: dataDir,
  );
}

class NullTransport implements VscreenTransportApi {
  const NullTransport();
  @override
  Future<Map<String, Object?>> request(
          VscreenHandshake endpoint, String route, String query) =>
      throw StateError('TRANSPORT_NOT_WIRED'); // F2-4 接入前不给假结果
}

class NullChannels implements VscreenChannelsApi {
  const NullChannels();
  @override
  VscreenChannel? choose() => null;
  @override
  VscreenChannel? find(String id) => null;
}

/// 装配工厂：[sourceDir] = APK 路径（ApplicationInfo.sourceDir），
/// [packageName] = 包名（Kotlin channel 供）；[root] = 应用目录（journal）。
/// fallback boot id（进程启动生成一次，保持一次开机内稳定）。
final String _fallbackBootId = _uuidV4();

String _uuidV4() {
  final rand = List<int>.generate(16, (_) => 0); // 占位，下方用 Random 填充
  final random = _secureishRandom();
  for (var i = 0; i < 16; i++) {
    rand[i] = random.nextInt(256);
  }
  rand[6] = (rand[6] & 0x0f) | 0x40; // v4
  rand[8] = (rand[8] & 0x3f) | 0x80; // variant
  final hex = rand.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

Random _secureishRandom() {
  final seed = DateTime.now().microsecondsSinceEpoch ^
      (DateTime.now().millisecondsSinceEpoch << 20);
  return Random(seed);
}

VscreenManager buildVscreenManager({
  required String sourceDir,
  required String packageName,
  required io.Directory root,
  required String installation,
  required String applicationId,
  VscreenTransportApi transport = const NullTransport(),
  VscreenChannelsApi? channels,
  AccessibilityServiceApi accessibility = const NullAccessibilityService(),
  int sdkInt = 30,
  bool lowAndroid = false,
}) {
  return VscreenManager(
    clock: _SystemClock(),
    channels: channels ?? ShizukuChannels(),
    worker: _MicrotaskWorker(),
    transport: transport,
    semantics: VscreenSemanticAdapter(accessibility),
    launcher: VscreenLauncher(sourceDir: sourceDir, packageName: packageName),
    journal: VscreenSessionJournal(
      root: root,
      installation: installation,
      applicationId: applicationId,
    ),
    diagnostics: (stage, detail) {
      // 诊断缝：面包屑进 Sentry（脱敏在桥内）。
      try {
        // 延迟导入面：桥在 app 层，这里保持 dsha_core 无 Flutter 依赖——
        // 调用方也可注入覆盖；默认落 Zone 打印。
        // ignore: avoid_print
        print('[vscreen:$stage] $detail');
      } catch (_) {}
    },
    failureCapture: (stage, error, safeCodes) {
      // 启动异常捕获缝：仅透出白名单消息码（原版 safeCodes 语义）。
      final message = error?.toString() ?? '';
      for (final code in safeCodes) {
        if (message.contains(code)) return <String, Object?>{'code': code};
      }
      return null;
    },
    // boot 标识契约：UUID 格式（vscreenUuidPattern 校验）+ 一次开机稳定。
    // 正源 /proc/sys/kernel/random/boot_id（系统 boot id 天生 UUID）；
    // 读不到时进程启动生成一次（开机会话语义不变）。
    bootSource: () {
      try {
        final bootId = File('/proc/sys/kernel/random/boot_id')
            .readAsStringSync()
            .trim();
        if (bootId.length == 36) return bootId;
      } catch (_) {}
      return _fallbackBootId;
    },
    lowAndroid: lowAndroid,
    sdkInt: sdkInt,
  );
}

class _SystemClock implements VscreenClock {
  @override
  int millis() => DateTime.now().millisecondsSinceEpoch;
}

class _MicrotaskWorker implements VscreenWorkerApi {
  @override
  void execute(void Function() task) => scheduleMicrotask(task);

  @override
  ScheduledCancellable schedule(void Function() task, int delayMs) =>
      _TimerCancellable(Timer(Duration(milliseconds: delayMs), task));

  @override
  ScheduledCancellable scheduleWithFixedDelay(
      void Function() task, int initialDelayMs, int delayMs) {
    Timer? timer;
    Timer? initial;
    initial = Timer(Duration(milliseconds: initialDelayMs), () {
      task();
      timer = Timer.periodic(Duration(milliseconds: delayMs), (_) => task());
    });
    return _TimerCancellable(_CompositeTimer(initial, () => timer));
  }
}

class _TimerCancellable implements ScheduledCancellable {
  _TimerCancellable(this._timer);
  final dynamic _timer;
  @override
  void cancel() {
    final t = _timer;
    if (t is Timer) {
      t.cancel();
    } else if (t is _CompositeTimer) {
      t.cancel();
    }
  }
}

class _CompositeTimer {
  _CompositeTimer(this.initial, this.periodic);
  final Timer initial;
  final Timer? Function() periodic;
  void cancel() {
    initial.cancel();
    periodic()?.cancel();
  }
}
