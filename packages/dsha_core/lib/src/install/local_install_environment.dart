// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.InstallPipeline.LocalEnvironment
// —— 现代化重构，行为契约不变。
//! 本地环境实现：对 [RuntimeBootstrap] 与基础工具安装器的薄委托
//! （原版 `InstallPipeline.LocalEnvironment` 一一对应）。
library;

import 'dart:io' as io;

import 'install_pipeline.dart';
import 'install_probe.dart';
import 'install_process.dart';
import 'install_stage.dart';
import 'runtime_bootstrap.dart';

/// 操作边界本地实现（原版 `LocalEnvironment`）。
class LocalInstallEnvironment implements InstallEnvironment {
  LocalInstallEnvironment(this.bootstrap, this.tools);

  final RuntimeBootstrap bootstrap;
  final BasicToolsInstaller tools;

  @override
  Future<bool> ready() => bootstrap.isEnvironmentReady();

  @override
  Future<bool> canExtractFresh() async {
    final root = bootstrap.getRootfsDir();
    final exists = root.existsSync();
    final empty = !exists || root.listSync().isEmpty;
    return empty && await bootstrap.hasOfflineBundle();
  }

  @override
  Future<void> extract(void Function(int done) progress) =>
      bootstrap.extractOfflineBundle((done, total) => progress(done));

  @override
  Future<void> repairTools(InstallProbeResults checked, InstallTask task) =>
      tools.repair(checked, task);

  @override
  Future<bool> repairPnpm() => bootstrap.ensureBundledPnpm();

  @override
  Future<void> repairGroups() => bootstrap.ensureAndroidGroups();

  @override
  Future<void> repairPatches() async {
    // 原版 RuntimeTools.invalidate() + RuntimeTools.prepare(context, rootfsDir)。
    await bootstrap.prepareRuntimeTools();
  }

  @override
  Future<int> execute(
    String script,
    int timeoutMs, {
    required bool cancellable,
    required InstallTask task,
    required void Function(String line) output,
  }) async {
    final process = await bootstrap.execRootfsForInstall(script);
    return InstallProcess.read(process,
        timeoutMs: timeoutMs,
        cancellable: cancellable,
        cancelled: task.cancellationRequested,
        output: output,
        destroy: (proc) => proc.kill(io.ProcessSignal.sigkill));
  }
}
