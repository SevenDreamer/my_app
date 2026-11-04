//! DSH 系统 ViewModel：安装/修复任务的唯一入口
//!
//! MVVM 分层（官方架构技能）：View 只读 [snapshot] + 调用命令方法。
//! 任务编排语义与原版 `InstallRepository` 逐字对齐：单飞启动、
//! 取消、清理失败回收循环（「本次进程尚未退出…」链路），六步文案
//! 与自救语义逐字保留（D6 约定：可换排版不得改语义）。
import 'dart:io' as io;

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/sentry_bridge.dart';
import 'dsha_asset_staging.dart';

class DshaSystemViewModel extends ChangeNotifier {
  /// 环境经构造注入（测试给假环境；缺省 = 桌面引导模式）。
  DshaSystemViewModel({InstallEnvironment? environment})
      : _environment = environment;

  InstallEnvironment? _environment;
  BackgroundRustArchiveExtractor? _extractor;
  String _runnerName = '宿主 bash';

  final InstallTask _task = InstallTask();
  bool _running = false;
  bool _preparing = true;
  bool _ready = false;
  String _extractorName = '—';

  /// 只读任务快照（六步状态/日志/结局/耗时）。
  InstallSnapshot get snapshot => _task.snapshot();

  bool get running => _running;
  bool get preparing => _preparing;

  /// 环境就绪（解压标记、版本与 bash 在位）。
  bool get ready => _ready;

  @override
  void dispose() {
    _extractor?.close();
    super.dispose();
  }

  /// 所用解包引擎（UI 显式展示——不许静默降级）。
  String get extractorName => _extractorName;

  /// 容器执行面（UI 显式展示）：proot（内置）/ 宿主 bash。
  String get runnerName => _runnerName;

  /// 上报诊断结果（「上报诊断」按钮反馈文案；空 = 未上报过）。
  String get reportNote => _reportNote;
  String _reportNote = '';

  /// 把当前任务快照（六步状态/详细输出/日志/失败/环境选型）上报 Sentry。
  /// 返回是否已发出（Sentry 未启用时 false，UI 如实提示）。
  Future<bool> reportDiagnostics() async {
    final s = snapshot;
    final sent = await SentryBridge.captureDiagnostics(<String, Object>{
      'steps': <String>[
        for (var i = 0; i < s.steps.length; i++) '${i + 1}:${s.steps[i].name}',
      ].join(','),
      'details': s.details.join('\n'),
      'log': _headTail(s.log),
      'failure': s.failure,
      'phase': s.phase,
      'outcome': s.outcome.name,
      'extractor': _extractorName,
      'runner': _runnerName,
      'ready': _ready,
      'elapsedSeconds': s.elapsedSeconds,
      'platform': io.Platform.operatingSystem,
    });
    _reportNote = sent ? '已上报到 Sentry' : 'Sentry 未启用，未上报';
    notifyListeners();
    return sent;
  }

  /// 上报体量控制：Sentry 单事件有上限，长日志截中间保头尾
  /// （apt/dpkg 的死亡输出在尾部，头部是步骤脉络——真机截断实证）。
  static String _headTail(String log, {int head = 2048, int tail = 12288}) {
    if (log.length <= head + tail) return log;
    final omitted = log.length - head - tail;
    return '${log.substring(0, head)}\n[……中间 $omitted 字节省略……]\n'
        '${log.substring(log.length - tail)}';
  }

  /// 准备环境（解析应用目录 + 解包引擎选型 + 就绪查询）；页面打开时调用一次。
  Future<void> prepare() async {
    if (_environment == null) {
      final support = await getApplicationSupportDirectory();
      final base = io.Directory('${support.path}/dsha-system');
      // 解包引擎选型（显式记录，UI 可见）：Rust 硬化引擎优先且跑后台隔离岛
      // （同步 FFI + 逐文件 fsync 直跑 UI 岛会 ANR——真机 MY-APP-2 实证），
      // 缺库显式降级系统 tar。
      final background = await BackgroundRustArchiveExtractor.open();
      final ArchiveExtractor extractor;
      if (background != null) {
        _extractor = background;
        extractor = background;
      } else {
        final unpacker = RustUnpacker.load();
        extractor = unpacker != null
            ? RustArchiveExtractor(unpacker)
            : const TarCommandExtractor();
      }
      _extractorName = extractor.name;
      // 资产暂存（rootBundle → 本地文件；幂等）：DesktopBootstrap 吃文件路径。
      final staged = await DshaAssetStaging.stage(
          io.Directory('${support.path}/dsha-assets'));
      // proot 容器 runner（Android W^X：proot 藏 jniLibs、从
      // nativeLibraryDir 执行）；组装失败如实留空 = 宿主 bash 直跑。
      ProotRunnerPlan? proot;
      var deviceDns = const <String>[];
      if (io.Platform.isAndroid) {
        try {
          const channel = MethodChannel('my_app/runtime');
          final libDir =
              await channel.invokeMethod<String>('nativeLibraryDir');
          if (libDir != null) {
            proot = ProotRunner.plan(
              nativeLibDir: libDir,
              rootfsPath: '${base.path}/rootfs',
              tmpDir: '${support.path}/dsha-tmp',
              libDir: '${support.path}/dsha-lib',
            );
          }
          final dns =
              await channel.invokeMethod<List<Object?>>('deviceDns');
          deviceDns = <String>[
            for (final s in dns ?? const <Object?>[])
              if (s is String) s,
          ];
        } catch (_) {}
      }
      _runnerName = !io.Platform.isAndroid
          ? '宿主 bash'
          : proot != null
              ? 'proot（内置）'
              : '宿主 bash（proot 不可用）';
      // 原版 LocalEnvironment：bootstrap 与工具安装器共享同一实例。
      final bootstrap = DesktopBootstrap(
        baseDir: base,
        offlineBundle: staged.file('offline-rootfs.bin'),
        expectedVersion: '1.0.0',
        uid: _selfUid(),
        extractor: extractor,
        runner: proot?.argv,
        environment: proot?.environment,
        deviceDns: deviceDns,
        guestScripts: FileGuestScriptSource(staged.dir),
        offlineTools: ArchiveOfflineToolSource(
          // 顺序语义：glibc-python 先、python-support 后补 soname。
          python: <String>[
            staged.path('glibc-python.tar.gz'),
            staged.path('python-support.bin'),
          ],
          pnpm: <String>[staged.path('pnpm-runtime.bin')],
          dsh: <String>[staged.path('dsh-runtime.bin')],
        ),
      );
      _environment = LocalInstallEnvironment(
        bootstrap,
        BasicToolsInstaller(bootstrap, FileGuestScriptSource(staged.dir)),
      );
    }
    _ready = await _environment!.ready();
    _preparing = false;
    notifyListeners();
  }

  /// 六步探针「只查不装」（自动测试链路用）：与 [InstallPipeline] 内部
  /// 探测同一协议（DSHA_CHECK_BEGIN/RESULT），环境未构造返回 null。
  /// 独立 [InstallTask] 承载输出回调，不与安装任务抢单飞锁。
  Future<InstallProbeResults?> probeAll() async {
    final environment = _environment;
    if (environment == null) return null;
    final checks = InstallProbe.checks(0);
    final results = InstallProbeResults(checks);
    final task = InstallTask();
    if (!task.start(repair: false, selected: 0)) return null;
    try {
      await environment.execute(
        InstallProbe.script(checks),
        checks.length * 22000 < 30000 ? 30000 : checks.length * 22000,
        cancellable: true,
        task: task,
        output: results.accept,
      );
    } catch (_) {
      // 进程异常退出：已收集结果仍有效，缺失键按「未收到结果」（≠ 成功）
    }
    return results;
  }

  /// 宿主 UID（原版 `android.os.Process.myUid()`；从 /proc/self/status
  /// 取真值——Android 与 Linux 桌面都可读；读不到用 10000 兜底）。
  static int _selfUid() {
    try {
      final text = io.File('/proc/self/status').readAsStringSync();
      final match =
          RegExp(r'^Uid:\t(\d+)', multiLine: true).firstMatch(text);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 10000;
  }

  /// 启动一次安装任务（原版 `InstallRepository.start` 语义）：
  /// 单飞、selected 0—6、异常分派（清理失败回收 / 取消 / 失败）。
  Future<void> start({required bool repair, required int selected}) async {
    if (_running) return;
    if (selected < 0 || selected > 6) {
      throw ArgumentError('安装步骤必须为 0—6');
    }
    final environment = _environment;
    if (environment == null || _preparing) return;
    if (!_task.start(repair: repair, selected: selected)) return;
    _running = true;
    notifyListeners();
    try {
      await InstallPipeline(environment).run(_task,
          repair: repair, selected: selected);
    } catch (error) {
      final cleanup = installCleanupFailure(error);
      if (cleanup != null) {
        _task.cleaningUp('本次进程尚未退出，正在继续回收；其他环境任务暂不可开始');
        while (!await cleanup.awaitExitFor(1000)) {
          cleanup.retry();
        }
        _task.finish(
            InstallOutcome.failed, '本次进程已回收，检查未完成，请重新检查');
      } else if (isCancellation(error)) {
        _task.finish(
            InstallOutcome.cancelled, '任务已取消，已完成的结果与修复保留');
      } else {
        _task.append('任务异常：$error');
        _task.finish(InstallOutcome.failed, '任务失败：$error');
      }
    } finally {
      if (_task.snapshot().outcome == InstallOutcome.running) {
        _task.finish(
            InstallOutcome.failed, '任务异常结束，请查看详细输出后重试');
      }
      _ready = await environment.ready();
      _running = false;
      notifyListeners();
    }
  }

  /// 请求取消（已到达安全点后生效；原版 requestCancel）。
  void cancel() {
    _task.requestCancel();
    notifyListeners();
  }
}
