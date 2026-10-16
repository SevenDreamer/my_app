# 局域网发现与网络扫描 · 生态调研

> 服务 device_link（Phase1 设备互联）的发现层设计，及未来"网络工具"功能的选型备忘。
> 调研日期 2026-10-16；标注"已核实"的包来自 pub.dev 实查，Rust 侧为生态常识、接入前须再核 crates.io。

## 一、"扫描网络"的三种能力

| 能力 | 用途 | 典型协议/手段 |
|---|---|---|
| **服务发现** | 谁在线、各提供什么服务（本项目 Phase1 正统入口） | mDNS / DNS-SD（RFC 6762）、SSDP/UPnP |
| **存活主机** | 网段里哪些 IP 活着 | ARP 扫描、ICMP ping |
| **端口扫描** | 活着的机器开了哪些服务 | TCP connect / SYN 扫描 |

## 二、生态现成货

### Dart / Flutter（优先——零新语言）

- **`multicast_dns`**（已核实，pub.dev · Flutter 官方 core-packages）：
  RFC 6762 mDNS 纯 Dart 实现，`MDnsClient` 查询 Bonjour/Avahi 服务——**桌面可用，
  设备发现的首选起步件**。
- **`nsd`**（已核实，pub.dev）：Flutter 插件，DNS-SD **发现 + 注册**双能力
  （被控端广播自己的形态）；权限说明覆盖 Android/iOS，**偏移动端**，桌面支持需实测。
- 子进程调用：Dart `Process.run` 直接使外部扫描器（见 nmap）。

### Rust（深度扫描再引入；接入前先核 crates.io）

- **RustScan**：Rust 高速端口扫描器（知名项目）——"网络工具"页可子进程调用。
- **pnet`**：Rust 网络包构造/嗅探标准件（ARP/ICMP 自造包）。
- **mdns-sd / zeroconf**：mDNS 的 Rust 实现（与 multicast_dns 同域，桌面 Rust helper 备选）。
- 集成模式：**sidecar 子进程**（JSON over stdio 通信）优先于 FFI（Y 项目经验可复用）。

### 成品工具（不写代码直接用）

- **nmap**：扫描王者，桌面客户端以子进程调用 + 解析其输出/XML 即可。

## 三、接进 my_app 的路线

```
发现层（mDNS，先于一切连接）
  被控端：启动广播  _myapp._tcp（服务名 + 端口 + TXT 元数据）
  控制端：multicast_dns 监听 → 「可用设备」列表（device_link 页的数据源）
连接层：mDNS 得到 IP:Port → 走链路层直连（ROADMAP Phase1：BLE/WiFi）
重武器（后期独立功能）：nmap/RustScan 子进程调用 →「网络工具」页（存活主机/端口扫描）
```

1. **第一步（纯 Dart）**：`multicast_dns` 一个依赖出"发现同网段 my_app 设备" demo。
2. **Rust 时机**：需要 ARP 构包 / 高并发端口扫描时再抽 sidecar。
3. **安全边界**：面向自己有权限的局域网；不做广域网扫描、不绕过认证。

## 四、待办（挂 ROADMAP Phase1）

- [ ] mDNS 发现 demo（multicast_dns，控制端列表页数据源）
- [ ] 被控端服务广播（_myapp._tcp 注册）
- [ ] `nsd` 桌面支持实测（若可用，移动端广播直接复用）
- [ ] RustScan/nmap 调用可行性（目标机是否需预装 → 分发策略）
