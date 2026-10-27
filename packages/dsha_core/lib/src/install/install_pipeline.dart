// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.InstallPipeline —— 现代化重构，行为契约不变。
//! 安装六步编排：先一次探测，仅在明确请求修复且检查失败时写入，完成后复验。
//!
//! 操作边界 [InstallEnvironment] 可替换，独立测试能验证不发生多余修复、
//! 清环境或取消后的写入。本地实现绑定 proot/工具安装（运行时接线轮移植）。
import 'install_probe.dart';
import 'install_process.dart';
import 'install_stage.dart';
/// 操作边界可替换（原版 `InstallPipeline.Environment`）。
/// IO 型操作在 Dart 中为异步；语义与原版一一对应。
abstract interface class InstallEnvironment {
  /// 环境就绪（解压标记、版本与 bash 在位）。
  Future<bool> ready();

  /// 只有 rootfs 不存在或为空且有离线包时才准首次解压（绝不重置已有数据）。
  Future<bool> canExtractFresh();

  /// 解压离线环境；progress 回报已读字节数。
  Future<void> extract(void Function(int done) progress);

  Future<void> repairTools(InstallProbeResults checked, InstallTask task);

  /// 补齐离线 pnpm；false = 失败（调用方转 IOException 文案）。
  Future<bool> repairPnpm();

  Future<void> repairGroups();

  Future<void> repairPatches();

  /// 在容器内执行探测脚本，返回退出码；逐行输出到 [output]。
  Future<int> execute(
    String script,
    int timeoutMs, {
    required bool cancellable,
    required InstallTask task,
    required void Function(String line) output,
  });
}

class InstallPipeline {
  InstallPipeline(this.environment);

  final InstallEnvironment environment;

  /// 六步编排入口。[selected] 0 = 全部，1..6 = 只跑该步。
  Future<void> run(InstallTask task,
      {required bool repair, required int selected}) async {
    task.stage(1, '检查第 1 步：Linux 解压标记、版本与 bash', cancellable: true);
    var ready = await environment.ready();
    if (!ready && repair && (selected == 0 || selected == 1)) {
      // 版本迁移会删除旧目录；只准首次空环境进入，绝不重置已有数据。
      if (await environment.canExtractFresh()) {
        task.stage(1, '安装第 1 步：首次解压离线环境（当前解压完成后可停止）',
            cancellable: false);
        var last = 0;
        await environment.extract((done) {
          if (done - last >= 8 * 1024 * 1024) {
            task.append('已读取离线包 ${done ~/ (1024 * 1024)} MiB');
            last = done;
          }
        });
        ready = await environment.ready();
      }
    }
    task.result(
        1,
        ok: ready,
        detail: ready
            ? '标记、版本和 bash 在位'
            : '环境未就绪；保留现有文件，不自动重解压或清除，请先备份后恢复环境');
    task.checkCancelled();
    if (!ready) {
      for (var step = 2; step <= 6; step++) {
        if (selected == 0 || selected == step) {
          task.result(step,
              ok: false,
              detail: '无法验证：Linux 环境未就绪，请先处理第 1 项');
        }
      }
      task.finish(InstallOutcome.failed,
          '检查完成：Linux 环境未就绪，其余组件无法验证；现有文件已保留');
      return;
    }
    if (selected == 1) {
      task.finish(InstallOutcome.succeeded, '第 1 步检查通过');
      return;
    }
    final checked = await _probe(task, selected);
    var failed = false;
    var repaired = 0;
    for (final stage in InstallStage.ordered) {
      final step = stage.id;
      if (stage == InstallStage.environment) continue;
      if (selected != 0 && selected != step) continue;
      task.checkCancelled();
      if (checked.okStep(step)) continue;
      if (!repair) {
        failed = true;
        continue;
      }
      try {
        switch (step) {
          case 2: // TOOLS
            await environment.repairTools(checked, task);
            break;
          case 4: // PNPM
            task.stage(4, '修复第 4 步：补齐离线 pnpm', cancellable: false);
            if (!await environment.repairPnpm()) {
              throw const InstallIoException('离线 pnpm 修复失败，请检查可用空间');
            }
            task.append('离线 pnpm 文件已核对，开始复验');
            break;
          case 6: // PATCHES
            if (!checked.ok('dns') ||
                !checked.ok('session') ||
                !checked.ok('settings')) {
              task.stage(6, '修复第 6 步：DNS、会话写入与局域网设置补丁',
                  cancellable: false);
              await environment.repairPatches();
            }
            task.checkCancelled();
            if (!checked.ok('groups')) {
              task.stage(6, '修复第 6 步：补齐 Android 用户组', cancellable: false);
              await environment.repairGroups();
              task.append('Android 用户组已核对，开始复验');
            }
            break;
          default: // NODE(3) / DSH(5)：不覆盖用户升级的内置组件
            task.result(step,
                ok: false,
                detail: '内置组件无法运行；本页不覆盖用户升级的 Node/dsh，请备份后修复该组件');
            failed = true;
            continue;
        }
        task.checkCancelled();
        final verified = await _probe(task, step);
        if (!verified.okStep(step)) {
          failed = true;
        } else {
          repaired++;
        }
      } on InstallCancelled {
        rethrow;
      } catch (error) {
        if (installCleanupFailure(error) != null) rethrow;
        if (isCancellation(error)) throw const InstallCancelled();
        task.result(step,
            ok: false, detail: InstallFailure.from(stage, error).display());
        failed = true;
      }
    }
    task.checkCancelled();
    task.finish(
        failed ? InstallOutcome.failed : InstallOutcome.succeeded,
        failed
            ? '检查完成，仍有步骤未通过；失败项与详细输出已保留'
            : repaired > 0
                ? '已按需修复 $repaired 步，并通过复验'
                : '检查全部通过，无需修复');
  }

  /// 启动一次容器探测，逐项检查实际运行结果；无论何种退出都为每个选中组件发布结论。
  Future<InstallProbeResults> _probe(InstallTask task, int selected) async {
    final checks = InstallProbe.checks(selected);
    final result = InstallProbeResults(checks);
    task.stage(selected == 0 ? 2 : selected, '启动一次容器探测，逐项检查实际运行结果',
        cancellable: true);
    InstallCheck? active;
    late int code;
    try {
      code = await environment.execute(
        InstallProbe.script(checks),
        checks.length * 22000 < 30000 ? 30000 : checks.length * 22000,
        cancellable: true,
        task: task,
        output: (line) {
          final begin = result.beginning(line);
          if (begin != null) {
            if (active != null && active!.stage.id != begin.stage.id) {
              task.result(active!.stage.id,
                  ok: result.okStep(active!.stage.id),
                  detail: result.detail(active!.stage.id));
            }
            active = begin;
            task.stage(begin.stage.id, '检查第 ${begin.stage.id} 步：${begin.label}',
                cancellable: true);
          } else if (result.accept(line)) {
            if (active != null) {
              task.append(result.ok(active!.key)
                  ? '${active!.label}：通过'
                  : '${active!.label}：失败（退出码 ${line.substring(line.lastIndexOf(':') + 1)}）');
            }
          } else {
            task.append(line);
          }
        },
      );
    } finally {
      // 进程提前退出、没有 BEGIN 或漏结果时，也要为每个选中组件发布结论。
      // 取消保留已完成结果，剩余步骤由 finish 标为未完成。
      if (!task.cancellationRequested()) {
        for (var step = 2; step <= 6; step++) {
          if (selected == 0 || selected == step) {
            task.result(step,
                ok: result.okStep(step), detail: result.detail(step));
          }
        }
      }
    }
    if (code != 0) {
      throw InstallIoException('容器探测退出码 $code，检查未完整执行');
    }
    return result;
  }
}
