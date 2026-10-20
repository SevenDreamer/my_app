//! "我"页面：个人信息与设置（占位阶段）
//!
//! 身份区 + 设置/关于/更新授权入口；后续接账号、偏好设置、设备管理等。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../design/widgets/app_app_bar.dart';
import '../design/widgets/app_list_tile.dart';
import 'update/download_qr.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshAuth();
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

  /// Device Flow：申请设备码 → 打开浏览器 → 后台轮询直到完成
  Future<void> _authorize() async {
    if (_authorizing) return;
    setState(() => _authorizing = true);
    try {
      final auth = GithubAuthService();
      final code = await auth.requestDeviceCode();
      await launchUrl(
        Uri.parse(code.verificationUriComplete),
        mode: LaunchMode.externalApplication,
      );
      _toast('已打开授权页，完成后自动生效（配对码 ${code.userCode}）');
      await auth.pollForToken(code);
      _toast('GitHub 授权成功');
    } catch (e) {
      _toast('授权未完成：$e');
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
