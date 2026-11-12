//! 页面级黄金测试——整屏 UI 基准（重构的 UI 安全网下半场）。
//!
//! 首页（registry 真数据）+ Linux 底座页（fake service 驱动快照态）——
//! 布局/间距/分组改动都会在基准图上现形。更新基准须设计走查：
//! `flutter test --update-goldens`。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:my_app/app/features_page.dart';
import 'package:my_app/design/theme.dart';
import 'package:my_app/features/linux_base/linux_base_page.dart';
import 'package:my_app/features/linux_base/linux_base_view_model.dart';
import 'package:my_app/data/services/linux_base_service.dart';

/// 假服务：展示态（已安装未运行 + 一条快照）——静态画面可拍
class _FakeService implements LinuxBaseService {
  @override
  Future<Map<Object?, Object?>> getStatus() async =>
      {'phase': 'installed', 'runtimeVersion': 'r15-x64'};
  @override
  Future<Map<Object?, Object?>> baseStats() async => {
        'memTotalMb': 2472,
        'memAvailableMb': 1900,
        'rootfsBytes': 812 * 1024 * 1024,
        'processes': [
          {'name': 'proot', 'pid': 1}
        ],
        'prootUptimeSec': 0,
        'load1': 0.2,
      };
  @override
  Future<List<SnapshotInfo>> snapshotList() async => [
        SnapshotInfo.tryParse({
          'name': 'snap-golden',
          'createdAt': 1762740000000,
          'bytes': 1024 * 1024,
          'note': '基准快照',
        })!,
      ];
  @override
  Future<Map<Object?, Object?>> snapshotCreate({String? note}) async => {};
  @override
  Future<SnapshotProgress?> snapshotProgress() async => null;
  @override
  Future<Map<Object?, Object?>> snapshotRestore(String name) async => {};
  @override
  Future<bool> snapshotDelete(String name) async => true;
  @override
  Future<void> install({bool dropKept = false}) async {}
  @override
  Stream<InstallProgress> installProgress() => const Stream.empty();
  @override
  Future<void> resetSystem() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

/// 固定尺寸拍图（响应式断点锁定在 expanded 档）
const _goldenKey = Key('golden-root');

Widget _shot(Widget child) => RepaintBoundary(
      key: _goldenKey,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF18181B)),
          useMaterial3: true,
        ),
        home: ShadTheme(
          data: AppTheme.shadLight,
          child: SizedBox(
            width: 1120,
            height: 900,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1120, 900)),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('首页整屏基线（registry 真数据 · expanded 档）', (tester) async {
    await tester.pumpWidget(_shot(const Scaffold(body: FeaturesPage())));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/page_features.png'),
    );
  });

  testWidgets('Linux 底座页整屏基线（已安装态 + 快照列表）', (tester) async {
    final vm = LinuxBaseViewModel(_FakeService());
    await vm.refresh();
    await tester.pumpWidget(_shot(Scaffold(body: LinuxBasePage(vm: vm))));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/page_linux_base.png'),
    );
    // 不主动 dispose：页面仍在监听（测试 VM 泄漏无害，golden 不验销毁链）
  });
}
