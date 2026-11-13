//! VscreenViewModel 单测（测试安全网收尾 7/7 全覆盖，2026-11-13）。
//!
//! 覆盖纯变换计算面（视口/缩放/平移）——不依赖 manager/平台通道。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/vscreen/vscreen_view_model.dart';

void main() {
  test('onViewport：视口尺寸落位', () {
    final vm = VscreenViewModel();
    vm.onViewport(1080, 1920);
    expect(vm.transform.screenW, 1080);
    expect(vm.transform.screenH, 1920);
    vm.dispose();
  });

  test('onScale：缩放因子夹紧正数', () {
    final vm = VscreenViewModel();
    vm.onScale(1.5);
    expect(vm.transform.zoom, 1.5);
    vm.dispose();
  });

  test('onPan：平移累计', () {
    final vm = VscreenViewModel();
    vm.onPan(10, 20);
    expect(vm.transform.offsetX, 10);
    expect(vm.transform.offsetY, 20);
    vm.dispose();
  });
}
