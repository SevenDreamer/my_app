# 002: p2p-connection —— flutter_p2p_connection 真机验证

## 问题（Given/When/Then）

| # | 验证 | 状态 |
|---|---|---|
| 建组 | Given K40，When createGroup(advertise:true)，Then 拿到 SSID/PSK/IP | ✅ `AndroidShare_xxxx` / PSK / `192.168.49.1` |
| BLE 发现 | Given K80，When startScan，Then 发现 K40（`5B:D5:05:2A:4B:9E`） | ✅ |
| 连接 | When connectWithDevice，Then 连接完成 | ✅ |
| 组网成员 | K40 的 streamClientList 出现 K80（`24122RKC7C`） | ✅ |
| 双向文本 | 双方 broadcastText → streamReceivedTexts | ✅ K80↔K40 双向收到 |
| 文件传输 | broadcastFile + downloadFile | ⏳ 未测（收发文本已够里程碑①） |

## Verdict: VALIDATED

### What worked
- 建组（SSID/PSK 自动分配，IP 落在 WiFi Direct 标准网段 192.168.49.x）
- BLE 扫描发现 + connectWithDevice 一步连接
- streamClientList 组网成员管理、streamReceivedTexts 双向文本
- 全程无需 GMS ✅

### What didn't（库的坑，正课必须处理）
1. **插件 bug：`hasP2pPermissions()` 在 API 31+ 就强查 `NEARBY_WIFI_DEVICES`**
   ——该权限 API 33 才引入，Android 12 上永远 `PERMISSION_DENIED`。
   spike 绕法：patch pub-cache `PermissionsManager.kt` 的 `VERSION_CODES.S` → `TIRAMISU`。
   **正课处理**：dependency_overrides 指向打补丁的本地副本，或给上游提 PR。
2. **插件权限辅助方法会挂死 platform channel**（`checkBluetoothPermissions` 不返回，
   后续所有插件调用全排队挂死——K80/HyperOS 实测）。**正课别调插件的 check/ask 系列**，
   权限用系统弹窗/设置页一次性授全（manifest 声明 + 运行时申请走 permission_handler 自己控）。
3. `streamClientList`/`streamHotspotState` 会反复推同内容 → 必须自己去重，否则刷屏。
4. MIUI 装包要开「USB安装」（开发者选项，需小米账号）；权限弹窗在 `com.lbe.security.miui`。

### Surprises
- `input text` 弹键盘后布局上移，tap 旧坐标会点空——每次 dump 现取坐标
- Flutter semantics 节点文本在 **content-desc** 不是 text；ListView 懒加载滚出屏的节点
  dump 不到——日志 UI 要**倒序**（最新在顶）才能被 dump 读到
- `uiautomator dump` 在 K40 上偶发静默失败/`could not get idle state`，重试即可

### Recommendation for the real build
- 里程碑①用 `flutter_p2p_connection` 可行（核心链路全通），但必须绕开上述两个坑
- Host/Client 双角色封装成 Transport 层，UI 侧只认「发现/连接/收发」抽象（对齐 v0.1 方案稿）
- 文件传输（broadcastFile/downloadFile）留待正课验证
