//! 一键自动测试（更新后验收链）：启动冒烟 + 更新链自检 + DSH 运行时自检
//!
//! 语义：每步独立、互不阻塞；结果三态（通过 / 失败 / 跳过——如 DSH 环境
//! 未安装、平台不支持热更）。任一步失败 → 自动 Sentry 上报（kind:
//! 'selftest'，带全部步骤明细），Hermes 侧 cron 轮询 Sentry 自动分析修复；
//! 全部通过只留 breadcrumb（不产生噪音 issue）。
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../core/ffi/rust_core_stub.dart'
    if (dart.library.io) '../../core/ffi/rust_core.dart';
import '../../core/logging/sentry_bridge.dart';
import '../update/apk_installer.dart';
import '../update/update_service.dart';

/// 单步结果三态：跳过 ≠ 通过（如实呈现），跳过也不算失败
enum SelfTestOutcome { passed, failed, skipped }

class SelfTestStepResult {
  const SelfTestStepResult({
    required this.id,
    required this.label,
    required this.outcome,
    this.detail = '',
  });

  final String id;
  final String label;
  final SelfTestOutcome outcome;
  final String detail;

  Map<String, Object> toJson() =>
      {'id': id, 'label': label, 'outcome': outcome.name, 'detail': detail};
}

class SelfTestReport {
  const SelfTestReport({required this.version, required this.results});

  /// version+build 全号（与 patch 的 release 同口径）
  final String version;
  final List<SelfTestStepResult> results;

  /// 只要有失败就算失败；跳过不影响结论
  bool get passed => !results.any((r) => r.outcome == SelfTestOutcome.failed);

  int get failedCount =>
      results.where((r) => r.outcome == SelfTestOutcome.failed).length;
}

class SelfTestRunner {
  SelfTestRunner._();

  /// 跑全部步骤；[onStatus] 回报进行中文案（UI 展示用）
  static Future<SelfTestReport> run({
    void Function(String status)? onStatus,
  }) async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';
    final results = <SelfTestStepResult>[];

    Future<void> step(
      String id,
      String label,
      Future<SelfTestStepResult> Function() body,
    ) async {
      onStatus?.call('正在测试：$label');
      SelfTestStepResult result;
      try {
        result = await body();
      } catch (e) {
        result = SelfTestStepResult(
          id: id,
          label: label,
          outcome: SelfTestOutcome.failed,
          detail: '$e',
        );
      }
      results.add(result);
    }

    await step('boot', '启动冒烟', () async => _boot(info));
    await step('manifest', '更新链 · manifest', () async => _manifest());
    await step('apk', '更新链 · 安装包', () async => _apk());
    await step('patch', '更新链 · 热更通道', () async => _patch());
    await step('dsh', 'DSH 运行时', () async => _dsh());
    await step('rustCore', 'Rust 核心自检', () async => _rustCore());

    final report = SelfTestReport(version: version, results: results);
    if (report.passed) {
      SentryBridge.breadcrumb('selftest', '自动测试全部通过 v$version');
    } else {
      await reportToSentry(report);
    }
    return report;
  }

  /// 失败自动上报（聚合一条，步骤明细全量入 context；脱敏由 SentryBridge 统一做）
  static Future<void> reportToSentry(SelfTestReport report) async {
    await SentryBridge.captureDiagnostics({
      'version': report.version,
      'passed': report.passed,
      'failed': report.failedCount,
      'results': jsonEncode(
        [for (final r in report.results) r.toJson()],
      ),
    }, kind: 'selftest');
  }

  /// 启动冒烟：应用活着且版本/诊断底座可读
  /// Rust core FFI 自检：心跳 + NIST SHA-256 向量（通路与算法双验）。
  /// 缺 dll（未打包 Rust 的构建）记 skipped 不算失败。
  static SelfTestStepResult _rustCore() {
    final rc = RustCore.ensureLoaded();
    if (rc == null) {
      return const SelfTestStepResult(
        id: 'rustCore',
        label: 'Rust 核心自检',
        outcome: SelfTestOutcome.skipped,
        detail: '当前构建未包含 Rust 核心（core.dll 缺席）',
      );
    }
    final ver = rc.version() ?? '?';
    final addOk = rc.add(2, 3) == 5;
    final hashOk = rc.sha256Hex(const []) ==
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    if (addOk && hashOk) {
      return SelfTestStepResult(
        id: 'rustCore',
        label: 'Rust 核心自检',
        outcome: SelfTestOutcome.passed,
        detail: '$ver · 算术/SHA-256 NIST 向量过界验证通过',
      );
    }
    return SelfTestStepResult(
      id: 'rustCore',
      label: 'Rust 核心自检',
      outcome: SelfTestOutcome.failed,
      detail: '$ver · add=$addOk sha256=$hashOk',
    );
  }

  /// 桌宠分发链自检：pet.exe 在位（进程启动/命令协议归集成验证，不在此闪窗）。
  static SelfTestStepResult _pet() {
    final exe = File(Platform.resolvedExecutable).parent
        .path;
    final path = Platform.isWindows ? '$exe\\pet.exe' : '$exe/pet';
    final exists = File(path).existsSync();
    return SelfTestStepResult(
      id: 'pet',
      label: '桌宠分发链',
      outcome: exists ? SelfTestOutcome.passed : SelfTestOutcome.skipped,
      detail: exists ? 'pet.exe 在位（$path）' : 'pet.exe 不在 exe 旁（P0 分发链未就绪）',
    );
  }

  static SelfTestStepResult _boot(PackageInfo info) {
    return SelfTestStepResult(
      id: 'boot',
      label: '启动冒烟',
      outcome: SelfTestOutcome.passed,
      detail: 'v${info.version}+${info.buildNumber} / '
          '${io.Platform.operatingSystem} / '
          'Sentry ${SentryBridge.enabled ? '已启用' : '未启用'}',
    );
  }

  /// 更新链 · manifest：R2 manifest 可达且可解析
  static Future<SelfTestStepResult> _manifest() async {
    final info = await UpdateService().latest();
    if (info == null) {
      return const SelfTestStepResult(
        id: 'manifest',
        label: '更新链 · manifest',
        outcome: SelfTestOutcome.failed,
        detail: 'manifest 不可达或解析失败',
      );
    }
    final patch = info.patch;
    return SelfTestStepResult(
      id: 'manifest',
      label: '更新链 · manifest',
      outcome: SelfTestOutcome.passed,
      detail: '远端 v${info.version}'
          '${patch == null ? '' : ' / patch ${patch.number}（${patch.release}）'}',
    );
  }

  /// 更新链 · 安装包：按 ABI 解析出下载地址且可访问（HEAD 200）
  static Future<SelfTestStepResult> _apk() async {
    final info = await UpdateService().latest();
    final url = info?.resolveApk(await deviceAbi());
    if (url == null) {
      return const SelfTestStepResult(
        id: 'apk',
        label: '更新链 · 安装包',
        outcome: SelfTestOutcome.failed,
        detail: 'manifest 无可用安装包地址',
      );
    }
    final resp = await http
        .head(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    return SelfTestStepResult(
      id: 'apk',
      label: '更新链 · 安装包',
      outcome: resp.statusCode == 200
          ? SelfTestOutcome.passed
          : SelfTestOutcome.failed,
      detail: 'HTTP ${resp.statusCode} / $url',
    );
  }

  /// 更新链 · 热更通道：Shorebird 可用且查询不异常
  static Future<SelfTestStepResult> _patch() async {
    final updater = ShorebirdUpdater();
    if (!updater.isAvailable) {
      return const SelfTestStepResult(
        id: 'patch',
        label: '更新链 · 热更通道',
        outcome: SelfTestOutcome.skipped,
        detail: '当前平台不支持热更',
      );
    }
    final status = await updater
        .checkForUpdate()
        .timeout(const Duration(seconds: 8));
    final current = (await updater.readCurrentPatch())?.number ?? 0;
    return SelfTestStepResult(
      id: 'patch',
      label: '更新链 · 热更通道',
      outcome: SelfTestOutcome.passed,
      detail: 'status=$status / 当前 Patch $current',
    );
  }

  /// DSH 运行时自检（F1 六步退役后的等价物）：dsh/runtime 通道 getStatus（7 态）。
  /// notInstalled=跳过（未安装）；error=失败；其余（installed/starting/running/
  /// stopping）=运行时链在。
  static Future<SelfTestStepResult> _dsh() async {
    try {
      const channel = MethodChannel('dsh/runtime');
      final status = await channel
          .invokeMethod<Map<Object?, Object?>>('getStatus')
          .timeout(const Duration(seconds: 8));
      final phase = '${status?['phase'] ?? ''}';
      final error = '${status?['error'] ?? ''}';
      if (phase == 'notInstalled') {
        return const SelfTestStepResult(
          id: 'dsh',
          label: 'DSH 运行时',
          outcome: SelfTestOutcome.skipped,
          detail: '运行时未安装，跳过',
        );
      }
      final ok = phase != 'error' && error.isEmpty;
      return SelfTestStepResult(
        id: 'dsh',
        label: 'DSH 运行时',
        outcome: ok ? SelfTestOutcome.passed : SelfTestOutcome.failed,
        detail: 'phase=$phase${error.isEmpty ? '' : ' / error=$error'}',
      );
    } on MissingPluginException {
      return const SelfTestStepResult(
        id: 'dsh',
        label: 'DSH 运行时',
        outcome: SelfTestOutcome.skipped,
        detail: '当前平台无运行时通道',
      );
    } catch (e) {
      return SelfTestStepResult(
        id: 'dsh',
        label: 'DSH 运行时',
        outcome: SelfTestOutcome.failed,
        detail: '$e',
      );
    }
  }
}
