//! 启动更新门 ViewModel：进主界面前的自动更新编排（热更 patch + 大版本）
//!
//! MVVM：View 只读状态快照 + 调命令方法；更新检查/下载走注入的既有服务，
//! 不改动既有更新代码。流程：并行查热更/大版本 → 热更只下载（生效交给
//! 下次启动；仅「patch 早已下载完」的状态尝试自动重启且有护栏）→ 有大
//! 版本自动下载并调起安装器（同版本只拦一次）→ 都没有秒过（不打扰）。
//!
//! 防回环三底线（dev.10 实测踩过"下载→杀进程重启→patch 未生效→再下载"
//! 的死循环，根因：update() 完立即 Runtime.exit(0) 会截断 patch 落盘/
//! 生效确认，patch 永远不生效、每轮重下重杀）：
//! 1. 下载完**不立即杀进程**——下次启动自然生效；
//! 2. 重启尝试持久护栏（普通文件 flush 落盘，扛 exit(0) 硬杀；
//!    FlutterSecureStorage 异步落盘会被截断导致护栏失效），
//!    同一 patch 最多 2 次；
//! 3. 任何分支最终都 _finish() 放行，「跳过」按钮全程可见。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_log.dart';
import 'apk_installer.dart';
import 'update_service.dart';

/// 启动门阶段（View 据此渲染）
enum BootGatePhase {
  /// 检查更新中（并行：热更 patch + 大版本 manifest）
  checking,

  /// 热更 patch 下载中
  patchDownloading,

  /// 热更就绪，正在重启应用以生效
  restarting,

  /// 重启未执行（如旧包缺原生通道），等用户手动重启或放行
  restartPending,

  /// 大版本下载中（带进度）
  versionDownloading,

  /// 无更新/跳过/异常——放行进主界面
  done,
}

/// 重启应用的可注入实现（默认走原生通道）
typedef AppRestarter = Future<void> Function();

/// 默认重启实现：原生通道拉起全新任务并结束当前进程（热更需整进程重启
/// 才生效）。旧包没有该通道时抛 [MissingPluginException]，由控制器降级处理。
Future<void> restartApp() =>
    const MethodChannel('my_app/lifecycle').invokeMethod<void>('restart');

class BootGateController extends ChangeNotifier {
  BootGateController({
    UpdateService? updateService,
    ShorebirdUpdater? updater,
    AppRestarter? restarter,
  })  : _updateService = updateService ?? UpdateService(),
        _updater = updater ?? ShorebirdUpdater(),
        _restarter = restarter ?? restartApp;

  final UpdateService _updateService;
  final ShorebirdUpdater _updater;
  final AppRestarter _restarter;

  static const _storage = FlutterSecureStorage();

  /// 同一 patch 的最大自动重启次数（超过就放行，热更等下次自然生效）
  static const _maxRestartsPerPatch = 2;

  /// 上次自动拦截的大版本号（同版本只拦一次——装/不装都不该反复
  /// 下载整包、反复调起安装器把用户堵在启动门外）
  static const _kOfferedVersionKey = 'boot_gate_offered_version';

  /// 网络检查超时：超时一律放行——更新检查绝不拦启动
  static const _checkTimeout = Duration(seconds: 8);

  BootGatePhase _phase = BootGatePhase.checking;
  String _status = '正在检查更新…';
  double _progress = 0;
  String? _message;
  bool _disposed = false;

  /// 状态快照
  BootGatePhase get phase => _phase;
  String get status => _status;

  /// 大版本下载进度（0..1）
  double get progress => _progress;

  /// 补充说明（错误/提示），null 表示无
  String? get message => _message;

  /// 是否可以放行进主界面
  bool get done => _phase == BootGatePhase.done;

  /// 启动门主流程
  Future<void> start() async {
    try {
      // 并行检查（先起跑再依次等——热更/大版本互不阻塞）
      final patchFuture = _checkPatch();
      final versionFuture = _checkVersion();
      final patchStatus = await patchFuture;
      final info = await versionFuture;

      // 1) 热更优先：补丁小下载快。下载完**不杀进程**（底线 1）——
      //    下次启动自然生效；只有「patch 早已下载完」才尝试自动重启
      if (patchStatus == UpdateStatus.outdated) {
        _set(phase: BootGatePhase.patchDownloading, status: '正在下载热更新…');
        await _updater.update().timeout(const Duration(seconds: 120));
        _message = '热更新已下载，重启应用后生效';
        _finish();
        return;
      }
      if (patchStatus == UpdateStatus.restartRequired) {
        await _restartForPatch();
        return;
      }

      // 2) 大版本：仅 Android 自动下载安装（其他平台交既有提示路径）
      //    同版本只自动拦一次：上次已提示过（装/没装都算）就不再重复
      //    下载整包、重复调起安装器——更新提示交主页弹窗，不堵门
      if (info != null && _isAndroid) {
        final offered = await _storage.read(key: _kOfferedVersionKey) ?? '';
        if (offered == info.version) {
          _finish();
          return;
        }
        await _storage.write(
          key: _kOfferedVersionKey,
          value: info.version,
        );
        await _downloadVersion(info);
        return;
      }

      _finish();
    } catch (e) {
      // 任何异常都不拦启动：落盘备查后放行
      await ErrorLog.record(AppError.from(e, context: '启动更新门'));
      _finish();
    }
  }

  /// 跳过更新门，直接进主界面
  void skip() => _finish();

  /// 退出应用（「重启未生效」降级态用）：用户重开即应用热更
  void exitApp() => exit(0);

  /// 热更状态查询：不可用/超时/异常一律返回 null（静默跳过）
  Future<UpdateStatus?> _checkPatch() async {
    if (!_updater.isAvailable) return null;
    try {
      return await _updater.checkForUpdate().timeout(_checkTimeout);
    } catch (_) {
      return null;
    }
  }

  /// 大版本查询：复用既有 UpdateService.check()（含忽略本版过滤）
  Future<UpdateInfo?> _checkVersion() async {
    try {
      return await _updateService
          .check()
          .timeout(_checkTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// 为热更重启（仅「patch 早已下载完」的状态走这里）：带持久护栏——
  /// 同一 patch 最多 [_maxRestartsPerPatch] 次，防"重启后仍判定待重启"
  /// 的回环把用户堵在门外。
  Future<void> _restartForPatch() async {
    final next = await _readNextPatchNumber();
    if (next == null) {
      _finish();
      return;
    }
    final guard = await _readGuard();
    if (guard.patch == next && guard.restarts >= _maxRestartsPerPatch) {
      _message = '热更新稍后生效，先进应用';
      _finish();
      return;
    }
    await _writeGuard(
      next,
      guard.patch == next ? guard.restarts + 1 : 1,
    );
    _set(phase: BootGatePhase.restarting, status: '正在重启以应用热更新…');
    try {
      await _restarter().timeout(const Duration(seconds: 3));
    } catch (_) {
      // 重启未执行（旧包缺原生通道等）：降级为手动重启提示
      _set(
        phase: BootGatePhase.restartPending,
        status: '热更新已就绪，重启应用后生效',
      );
    }
  }

  /// 待生效 patch 号（读不到按无 patch 处理：放行，绝不猜）
  Future<int?> _readNextPatchNumber() async {
    try {
      return (await _updater.readNextPatch())?.number;
    } catch (_) {
      return null;
    }
  }

  /// 大版本自动下载并调起安装器（D1 游戏式更新：全程可见）
  Future<void> _downloadVersion(UpdateInfo info) async {
    final url = info.resolveApk(await deviceAbi());
    if (url == null) {
      _message = '新版本暂无 Android 安装包';
      _finish();
      return;
    }
    _set(
      phase: BootGatePhase.versionDownloading,
      status: '发现新版本 ${info.version}，正在下载…',
    );
    final err = await downloadAndInstallApk(
      url,
      onProgress: (p) => _set(progress: p),
    );
    if (err != null) {
      // 下载失败不拦启动：落盘后放行（既有弹窗路径还能再试）
      await ErrorLog.record(err);
      _message = err.message;
      _finish();
      return;
    }
    // 调起安装器即放行进主页：装完重开自然是新版；用户取消安装也不该
    // 被堵在门外（更新提示交主页弹窗）。安装器本身盖在 app 上层。
    _finish();
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ---- 重启护栏（普通文件，flush 立即落盘，扛 exit(0) 硬杀）----

  Future<File> _guardFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/boot_gate_guard.json');
  }

  /// 读护栏；任何失败按"无记录"处理（宁可多试一次也不拦启动）
  Future<({int patch, int restarts})> _readGuard() async {
    try {
      final f = await _guardFile();
      if (!await f.exists()) return (patch: -1, restarts: 0);
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (
        patch: (j['patch'] as num?)?.toInt() ?? -1,
        restarts: (j['restarts'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (patch: -1, restarts: 0);
    }
  }

  Future<void> _writeGuard(int patch, int restarts) async {
    try {
      final f = await _guardFile();
      await f.writeAsString(
        jsonEncode({'patch': patch, 'restarts': restarts}),
        flush: true,
      );
    } catch (_) {
      // 护栏写失败不拦启动
    }
  }

  void _set({
    BootGatePhase? phase,
    String? status,
    double? progress,
    String? message,
  }) {
    if (_disposed) return;
    if (phase != null) _phase = phase;
    if (status != null) _status = status;
    if (progress != null) _progress = progress;
    if (message != null) _message = message;
    notifyListeners();
  }

  void _finish() {
    _set(phase: BootGatePhase.done, status: '');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
