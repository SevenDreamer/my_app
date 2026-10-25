//! 启动更新门 ViewModel：进主界面前的自动更新编排（热更 patch + 大版本）
//!
//! MVVM：View 只读状态快照 + 调命令方法；更新检查/下载走注入的既有服务，
//! 不改动既有更新代码，只补三件事：启动时机（进门前）、过程可见（状态画面）、
//! 热更下载完自动重启生效。流程：并行查热更/大版本 → 有热更先下完并重启
//! 生效 → 有大版本自动下载并调起安装器 → 都没有秒过（不打扰）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  /// 上次为热更重启的时刻（重启回环保护用）
  static const _kRestartAtKey = 'boot_gate_restart_at';

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

      // 1) 热更优先：补丁小下载快，先生效再谈大版本
      //    回环保护前移：90 秒内为热更重启过就直接放行——不重复下载、
      //    不反复闪启动门（patch 反复判定 outdated 时曾把用户堵在门外）
      if (patchStatus == UpdateStatus.restartRequired) {
        await _restartForPatch();
        return;
      }
      if (patchStatus == UpdateStatus.outdated) {
        if (await _restartedRecently()) {
          _finish();
          return;
        }
        _set(phase: BootGatePhase.patchDownloading, status: '正在下载热更新…');
        await _updater.update().timeout(const Duration(seconds: 120));
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

  /// 为热更重启：带 90 秒回环保护（防 patch 反复判定 outdated 卡启动）
  Future<void> _restartForPatch() async {
    if (await _restartedRecently()) {
      _finish();
      return;
    }
    // 时间戳只在真正重启前写（查询函数必须无副作用，否则正常流程
    // 会被自己的写入判定成"刚重启过"而永远不重启）
    final now = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _kRestartAtKey, value: '$now');
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

  /// 90 秒内是否刚为热更重启过（回环保护判定；纯查询无副作用）
  Future<bool> _restartedRecently() async {
    final last =
        int.tryParse(await _storage.read(key: _kRestartAtKey) ?? '') ?? 0;
    return DateTime.now().millisecondsSinceEpoch - last < 90 * 1000;
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
