//! "我"页面：个人信息与设置（占位阶段）
//!
//! 身份区 + 设置/关于/更新授权入口；后续接账号、偏好设置、设备管理等。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../design/widgets/app_app_bar.dart';
import '../design/widgets/app_list_tile.dart';
import '../core/errors/app_error.dart';
import '../core/errors/error_dialog.dart';
import 'error_log_page.dart';
import 'update/auth_webview_page.dart';
import 'update/download_qr.dart';
import 'update/update_service.dart';
import 'update/github_auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 版本信息从 pubspec.yaml 读取
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  /// GitHub 授权状态：null=查询中 / true=已授权 / false=未授权
  bool? _authorized;
  bool _authorizing = false;

  /// 更新通道：stable / dev
  String _channel = 'stable';

  @override
  void initState() {
    super.initState();
    _refreshAuth();
    _loadChannel();
  }

  Future<void> _loadChannel() async {
    final ch = await UpdateService().channel();
    if (mounted) setState(() => _channel = ch);
  }

  /// 切换更新通道（稳定版 / 开发版）
  void _pickChannel() {
    Widget btn(String value, String label, String desc) {
      final active = _channel == value;
      final widget = active ? ShadButton.new : ShadButton.outline;
      return widget.call(
        child: Text(label),
        onPressed: () async {
          await UpdateService().setChannel(value);
          if (!mounted) return;
          setState(() => _channel = value);
          Navigator.of(context).pop();
          _toast('已切换到$label');
        },
      );
    }

    showShadDialog<void>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('更新通道'),
        description: const Text(
          '稳定版：只推送正式发布的版本（推荐）。\n'
          '开发版：可收到预发布测试版本（新功能抢先体验，可能不稳定）。',
        ),
        actions: [
          btn('dev', '开发版', ''),
          btn('stable', '稳定版', ''),
          ShadButton.outline(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAuth() async {
    try {
      final ok = await GithubAuthService().isAuthorized;
      if (mounted) setState(() => _authorized = ok);
    } catch (_) {
      // 读取失败按未授权处理：保证入口始终可点（可重新走授权流程）
      if (mounted) setState(() => _authorized = false);
    }
  }

  /// 打开授权链接（指定方式）：preferApp=true 强制找非浏览器应用（GitHub App），
  /// false 走浏览器；系统匹配不上返回 false（由调用方提示用户换方式）
  Future<bool> _openAuthUri(String uriString, {required bool preferApp}) async {
    final uri = Uri.tryParse(uriString);
    if (uri == null) return false;
    return launchUrl(
      uri,
      mode: preferApp
          ? LaunchMode.externalNonBrowserApplication // 强制非浏览器应用
          : LaunchMode.externalApplication, // 普通浏览器
    );
  }

  /// Device Flow：申请设备码 → 弹配对码框（可复制/手动打开）→ 轮询授权结果
  Future<void> _authorize() async {
    if (_authorizing) return;
    setState(() => _authorizing = true);
    var dialogOpen = false;
    try {
      final auth = GithubAuthService();
      final code = await auth.requestDeviceCode();
      if (!mounted) return;

      // 先弹配对码框：码可见、可复制；浏览器跳不跳都能手动完成
      dialogOpen = true;
      // ignore: unawaited_futures
      showShadDialog<void>(
        context: context,
        builder: (ctx) => ShadDialog(
          title: const Text('授权 GitHub'),
          actions: [
            ShadButton.outline(
              child: const Text('复制配对码'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code.userCode));
                ShadSonner.of(ctx).show(
                  ShadToast(
                    id: DateTime.now().microsecondsSinceEpoch,
                    title: Text('配对码已复制：${code.userCode}'),
                  ),
                );
              },
            ),
            ShadButton.outline(
              child: const Text('GitHub App 打开'),
              onPressed: () async {
                final ok =
                    await _openAuthUri(code.verificationUriComplete, preferApp: true);
                if (!ok && mounted) {
                  _toast('没找到可用的 GitHub App —— 请用「浏览器打开」');
                }
              },
            ),
            ShadButton(
              child: const Text('浏览器打开'),
              onPressed: () => _openAuthUri(code.verificationUriComplete, preferApp: false),
            ),
            ShadButton(
              child: const Text('取消'),
              onPressed: () {
                dialogOpen = false;
                Navigator.of(ctx).pop();
              },
            ),
          ],
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 大字配对码：核心诉求——先看得到
                Text(
                  code.userCode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '装了 GitHub App 点「GitHub App 打开」直接一键授权；\n没装就点「浏览器打开」（会自动填码）。\n若都没反应，请访问 github.com/login/device\n手动输入上面的配对码。\n\n授权完成后本窗口自动关闭。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // 自动打开授权页：Android 走内置 webview（受控，不被外部浏览器打断），
      // 桌面走系统浏览器
      if (defaultTargetPlatform == TargetPlatform.android) {
        // ignore: unawaited_futures
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AuthWebviewPage(
              url: code.verificationUriComplete,
              userCode: code.userCode,
            ),
          ),
        );
      } else {
        await _openAuthUri(code.verificationUriComplete, preferApp: false);
      }
      _toast('已打开授权页，等待授权（配对码 ${code.userCode}）');

      // 后台轮询直到授权完成/超时
      await auth.pollForToken(code);
      if (mounted && dialogOpen) {
        dialogOpen = false;
        Navigator.of(context).pop(); // 关配对码框
      }
      _toast('GitHub 授权成功');
    } catch (e) {
      if (mounted && dialogOpen) {
        dialogOpen = false;
        Navigator.of(context).pop();
      }
      if (mounted) {
        // 错误弹窗完整展示（异常自动归码：如 DNS 解析失败=E1001）
        await showErrorDialog(
          context,
          AppError.from(e, context: '授权', message: '授权未完成'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _authorizing = false);
        await _refreshAuth();
      }
    }
  }

  /// 已授权时点击：查看状态并可撤销
  void _authInfo() {
    showShadDialog<void>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('更新检查已授权'),
        description: const Text(
          '本设备已获授权访问私有仓库的 Release（token 仅存于本机安全存储）。'
          '应用启动 3 秒后会静默检查更新。',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('重新授权'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _authorize();
            },
          ),
          ShadButton.outline(
            child: const Text('撤销授权'),
            onPressed: () {
              GithubAuthService().revoke();
              Navigator.of(ctx).pop();
              _refreshAuth();
              _toast('已撤销本机授权');
            },
          ),
          ShadButton(
            child: const Text('关闭'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ShadSonner.of(context).show(
      ShadToast(
        id: DateTime.now().microsecondsSinceEpoch,
        title: Text(message),
      ),
    );
  }

  /// 占位动作：敬请期待
  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('敬请期待')),
    );
  }

  /// 扫码下载是桌面端入口（手机自己不需要下载自己）
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  String get _authSubtitle {
    if (_authorizing) return '等待浏览器授权中……';
    final auth = _authorized;
    if (auth == null) return '查询授权状态……';
    return auth ? '已授权 · 启动时自动检查新版本' : '未授权 · 点击后在浏览器授权（私有仓库）';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppAppBar(title: '我'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 身份区
          ShadCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'my_app',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('个人工具箱', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 设置与关于
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListTile(
                  icon: LucideIcons.settings,
                  title: '设置',
                  showDivider: true,
                  onTap: _comingSoon,
                ),
                AppListTile(
                  icon: LucideIcons.bug,
                  title: '错误日志',
                  subtitle: '查看最近的报错记录（带错误码）',
                  showDivider: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ErrorLogPage(),
                    ),
                  ),
                ),
                AppListTile(
                  icon: LucideIcons.refreshCw,
                  title: '更新检查',
                  subtitle: _authSubtitle,
                  showDivider: true,
                  // 未授权/查询中 → 授权流程；已授权 → 状态框；授权中禁点
                  onTap: _authorizing
                      ? null
                      : (_authorized == true ? _authInfo : _authorize),
                ),
                if (_isDesktop)
                  AppListTile(
                    icon: LucideIcons.qrCode,
                    title: '手机下载',
                    subtitle: '显示 Android 安装包下载二维码',
                    showDivider: true,
                    onTap: () => showDownloadQrDialog(context),
                  ),
                AppListTile(
                  icon: LucideIcons.gitBranch,
                  title: '更新通道',
                  subtitle: _channel == 'dev'
                      ? '开发版 · 可收到预发布测试版本'
                      : '稳定版 · 只推送正式发布版本',
                  showDivider: true,
                  onTap: _pickChannel,
                ),
                AppListTile(
                  icon: LucideIcons.info,
                  title: '关于',
                  subtitle: '个人工具箱 · 遵循 DESIGN.md 视觉规范',
                  trailing: FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? 'v${snapshot.data!.version}'
                          : '…',
                      style: textTheme.labelSmall,
                    ),
                  ),
                  showDivider: false,
                  onTap: _comingSoon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
