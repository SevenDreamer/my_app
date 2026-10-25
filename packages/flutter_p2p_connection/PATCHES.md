# flutter_p2p_connection —— vendor 补丁副本

来源：pub.dev `flutter_p2p_connection` 3.0.3（2026-10-26 vendor）。
用 `dependency_overrides` 指向本目录，保证构建可复现（不依赖本机 pub-cache 状态）。

## 与上游的差异（1 处）

**`android/.../PermissionsManager.kt`：NEARBY_WIFI_DEVICES 检查门槛 S → TIRAMISU**

上游 `hasP2pPermissions()` 在 API 31+ 就强查 `NEARBY_WIFI_DEVICES`，
但该权限 **API 33 才引入**——Android 12 设备上系统报 `Unknown permission`，
检查永远 false → `createGroup`/`connectToHotspot` 永远 `PERMISSION_DENIED`。
改为 API 33+ 才检查（3 处同源判断：hasP2pPermissions / hasBluetoothConnectPermission / 服务检查）。

验证：K40（Android 12）+ K80（Android 16）双机实测建组/发现/连接/双向文本全通
（见 `spikes/002-p2p-connection/README.md`）。

后续：给上游提 PR 后可删除本副本，恢复 pub.dev 版本。
