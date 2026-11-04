# 自动更新 · 自动测试 · 自动修复链（AUTO_UPDATE_CHAIN）

> 状态：v1（2026-11-04）｜定位：工程底座（`lib/app/update/` + `lib/app/selftest/`，不进 feature registry）
> 动机：发版本来就是高频动作（融合计划批次 0–8 每批都要发），把「感知更新 →
> 更新 → 验证 → 报错 → 修复」整条链自动化，人只在必要时点一下。

## 一、链路全景

```
tool/patch.sh 发 patch ──刷──▶ R2 manifest.patch 节
tool/release.sh 发版 ──刷──▶ R2 manifest（version/apks/notes）
        │
        ▼
App WorkManager 后台巡检（2h 周期，app 被杀也能跑）
  ├─ manifest.version 领先 ──▶ 通知「发现新版本」──▶ 点击进 App，启动门自动下载安装
  ├─ manifest.patch 领先当前 Patch ──▶ 通知「热更就绪」──▶ 点击进 App，启动门自动应用
  └─ 同版本/同 patch 只通知一次（bg_notified_* 去重）
        │ 更新后首启（版本号变化）或点击「更新完成」通知
        ▼
一键自动测试（SelfTestRunner）：启动冒烟 + 更新链自检（manifest/安装包/热更通道）
  + DSH 六步探针（复用 DshaSystemViewModel.probeAll 只查不装）
  ├─ 全部通过 → breadcrumb 留痕，结束
  └─ 任一失败 → SentryBridge.captureDiagnostics(kind: 'selftest') 自动上报
        │
        ▼
Hermes cron「Sentry 自测失败自动修复」（每 2h，job 7fd46f25c1f6）
  查 Sentry 新 issue → 分析 → 修代码 → 双绿 → git push → 下版带上
```

## 二、组件清单

| 组件 | 位置 | 职责 |
|---|---|---|
| `PatchInfo` + manifest `patch` 节 | `lib/app/update/update_service.dart` | 热更发布元数据解析（release 全号/number/notes/time） |
| `UpdateNotifier` | `lib/app/update/update_notifier.dart` | 「更新提醒」渠道三类通知 + 点击 payload 路由（'selftest'） |
| `BackgroundUpdateCheck` | `lib/app/update/background_check.dart` | WorkManager 周期任务（2h，网络约束，keep 策略）+ 去重 |
| `SelfTestRunner` | `lib/app/selftest/self_test_runner.dart` | 五步自动测试 + 三态结果（通过/失败/跳过）+ 失败自动上报 |
| 自测对话框 / 入口 | `lib/app/selftest/self_test_dialog.dart`、`self_test_prompt.dart` | 一键跑测；更新后首启/通知点击弹出 |
| `DshaSystemViewModel.probeAll()` | `lib/features/dsha_system/dsha_system_view_model.dart` | 六步探针「只查不装」（InstallProbe 协议复用） |
| `tool/patch.sh` manifest 刷新 | `tool/patch.sh` | 发 patch 后解析 Patch N → 更新 manifest.patch → 双写上传 |
| Hermes cron | `7fd46f25c1f6`（每 2h） | Sentry 轮询 → 自动分析修复推送（continuity 去重） |

## 三、manifest `patch` 节 schema

```json
"patch": {
  "release": "1.3.0-dev.26+70",   // 目标 release（version+build 全号）
  "number": 8,                    // Shorebird Patch N
  "notes": "修复六步探针超时",      // tool/patch.sh 第二参数（可空）
  "time": "2026-11-04T10:00:00Z"  // UTC 打点
}
```

- **patch 只对同 `release` 设备有意义**——巡检用 `${version}+${buildNumber}` 全号比对；
- release.sh 发版不写该节（新 release 天然清空旧 patch 记录）；
- patch.sh 刷新失败只警告（patch 本身已发布不受影响）。

## 四、设计约束（别破坏）

- **更新链绝不拦启动**：通知/巡检/自测任何异常静默落盘（ErrorLog），WorkManager 任务恒返回 true 免重试风暴。
- **零新增 Lucide 字形 / 零新增资产**（PITFALLS #27：资产变更拦住 patch）——自测 UI 纯文字，
  通知图标复用 `@mipmap/ic_launcher`。
- **测试三态语义**：跳过（如 DSH 环境未安装）≠ 通过 ≠ 失败；只有失败触发 Sentry 上报。
- **Sentry 上报聚合一条**（kind: `selftest`，steps 明细全量入 context），避免按步骤刷 issue。
- 双状态去重都用 FlutterSecureStorage 键（`bg_notified_version` / `bg_notified_patch` /
  `selftest_last_run_version`）——跨进程/后台 isolate 一致。

## 五、真机验证清单（发版后）

1. 手机收到/收不到通知先查通知权限（Android 13+ 首启会请求）。
2. `tool/patch.sh <ver> "测试说明"` 发一个 patch → 手机 2h 内（或手动触发 WorkManager）应收到「热更 Patch N 已就绪」。
3. 更新后首启弹自动测试 → 五步跑完；故意断网测「更新链」失败 → Sentry 出现 kind:selftest issue。
4. cron 侧：`hermes` cron 列表看 `7fd46f25c1f6` 运转；issue 处理结果回本会话。

## 六、与融合计划的关系

批次 3（运行时域）会退役 `DshaSystemViewModel` 所在的 F1 链——届时「DSH 六步探针」步骤
改为对 dsh-go 形态运行时的等价检查；通知/巡检/自测/Sentry/cron 底座不动。
