//! DSH 系统 ViewModel：安装/修复任务的唯一入口
//!
//! MVVM 分层（官方架构技能）：View 只读 [snapshot] + 调用命令方法。
//! 任务编排语义与原版 `InstallRepository` 逐字对齐：单飞启动、
//! 取消、清理失败回收循环（「本次进程尚未退出…」链路），六步文案
//! 与自救语义逐字保留（D6 约定：可换排版不得改语义）。
import 'dart:io' as io;

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DshaSystemViewModel extends ChangeNotifier {
  /// 环境经构造注入（测试给假环境；缺省 = 桌面引导模式）。
  DshaSystemViewModel({InstallEnvironment? environment})
      : _environment = environment;

  InstallEnvironment? _environment;

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

  /// 所用解包引擎（UI 显式展示——不许静默降级）。
  String get extractorName => _extractorName;

  /// 准备环境（解析应用目录 + 解包引擎选型 + 就绪查询）；页面打开时调用一次。
  Future<void> prepare() async {
    if (_environment == null) {
      final support = await getApplicationSupportDirectory();
      final base = io.Directory('${support.path}/dsha-system');
      // 解包引擎选型（显式记录，UI 可见）：Rust 硬化引擎优先，缺库用系统 tar。
      final unpacker = RustUnpacker.load();
      final ArchiveExtractor extractor;
      if (unpacker != null) {
        extractor = RustArchiveExtractor(unpacker);
      } else {
        extractor = const TarCommandExtractor();
      }
      _extractorName = extractor.name;
      // 原版 LocalEnvironment：bootstrap 与工具安装器共享同一实例。
      final bootstrap = DesktopBootstrap(
        baseDir: base,
        offlineBundle: null,
        expectedVersion: '1.0.0',
        extractor: extractor,
      );
      _environment = LocalInstallEnvironment(
        bootstrap,
        // 资产接缝（guest 脚本/离线工具）F1-4 随 rootfs 烘制接入。
        BasicToolsInstaller(bootstrap, null),
      );
    }
    _ready = await _environment!.ready();
    _preparing = false;
    notifyListeners();
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
