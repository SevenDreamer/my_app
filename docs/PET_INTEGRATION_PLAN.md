# pet（桌宠）集成方案 · 立项草案

> 2026-11-12 · 全权推进落账。`rust/pet`（gpui 桌宠）与 my_app 桌面端的集成形态。

## 形态对比

| 形态 | 描述 | 评估 |
|---|---|---|
| **A. 独立进程**（推荐） | pet 保持 gpui 独立可执行；my_app 管生命周期（启动/停止/崩溃重启）+ 进程间通信（stdio/socket） | gpui 投入全保留、隔离好、实现快 |
| B. Flutter 多窗口桌宠 | 用 Flutter Desktop Windowing API（官方多窗口，`multiview_desktop` 包佐证生态）重写桌宠 UI | UI 统一但**重写 pet**（gpui 白做）、窗口 API 新（3.47 新特性风险） |
| C. gpui 窗口嵌入 Flutter 窗口 | HWND 互嵌 | 易碎（DPI/消息循环冲突），不推荐 |

## 推荐：形态 A 的接线面

```
my_app（Flutter 桌面）
  └─ PetService（data/services/）
       ├─ 启动：Process.start('pet.exe')（与 exe 同目录/资源目录）
       ├─ 通信：stdio JSON 行协议（Y 项目 stdout 惯例——PING/PONG 风格命令）
       └─ 守护：崩溃自动重启（带退避）+ 随 app 退出联动

pet（gpui，rust/pet）
  ├─ 保持 Y 项目架构（windows/components/pages）
  └─ 加 stdio 命令通道（情绪/动作/位置指令——LookSource 之外的控制面）
```

## 分批

| 批 | 内容 | 前置 |
|---|---|---|
| P0 | PetService 生命周期管理（启停/守护）+ pet.exe 随包分发链 | — |
| P1 | stdio 命令协议（app 控制桌宠情绪/动作） | P0 |
| P2 | 底座/DshGo 状态联动（桌宠反馈系统状态） | P1 |

## 未决（待用户拍）

1. pet.exe 的分发形态：随 my_app 安装包（体积+~10MB）还是独立下载（R2）？
2. pet 与 Y 项目的关系：pet 在 my_app 仓里已经分叉演化，还是继续双仓同步？
3. 桌宠默认开还是默认关（产品语义——「个性」域的定位）？
