//! PetService 单测（P0 生命周期——缺席降级路径）。
//!
//! 真进程启动不在单测范围（集成测试域）；这里验「pet.exe 不在时优雅降级」
//! 与「stop 幂等」——守护/重启逻辑经由产品自测与真机验证。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/services/pet_service.dart';

void main() {
  test('pet.exe 缺席：start 返回 false 不抛出', () async {
    final svc = PetService();
    // 测试环境 exe 旁无 pet.exe——走缺失分支
    final ok = await svc.start();
    expect(ok, isFalse);
    expect(svc.running, isFalse);
  });

  test('stop 幂等：未启动时调用不炸', () async {
    final svc = PetService();
    await svc.stop();
    await svc.stop();
    expect(svc.running, isFalse);
  });
}
