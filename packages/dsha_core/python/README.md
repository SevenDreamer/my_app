# dsha_core · Python 运行时资产

> 来源：DSHA（MIT）`app/src/main/assets/` —— 保留原语义的现代化重构。
> 版权归原作者；合入声明见 my_app `THIRD_PARTY_NOTICES.md`。
> 运行位置：rootfs 容器内（Python 3）。运行时 pip 依赖（`setup.sh` 的 `PIP_PKGS`
> 为权威清单，离线 wheels 注入）：`adb_shell_wifi`、`pyopenssl`、`spake2-cffi`、
> `aiofiles`、`async_timeout`、`zeroconf`。部署布局：注入 `/root/.dsh/adb/`。

## 结构约定（拆 importlib 动态耦合）

原 DSHA 用 `importlib.util.spec_from_file_location` 互相加载（文件名带连字符
不能普通 import）。重构后：

```
python/
├── _adb_common.py     共享面：密钥路径、连接重试、mDNS 发现、异常、策略引用
├── pair.py            ← adb-pair.py（无线配对 + 连接验证 + 保活授权）
├── shell.py           ← adb-shell.py（执行链 / 三态退出码 / 重放保护）
├── policy.py          ← device-shell-policy.py（命令白名单 / 路径校验）
└── setup.sh           ← adb-setup.sh（环境准备）
```

- `_adb_common.py` 用合法模块名 → 同目录普通 `import`，无 importlib；
- 入口脚本保持单文件可执行（部署契约不变：注入 rootfs 后命令行调用）。

## 输出协议 = API

`PAIR_OK` / `CONNECT_OK` / `CONNECT_WARN` / `PAIR_FAIL` / `SPAKE2_ERROR` /
`TLS_ERROR` / `NO_*` / `INVALID_*` 等前缀行由宿主（AdbBridge 等价物）解析，
**逐字节保留，重构不得改文案与退出码**（0 成功 / 1 失败 / 2 参数错）。

## 文件状态

| 文件 | 状态 |
|---|---|
| pair.py | ✅ 已现代化 |
| _adb_common.py | ✅ 已落地（机器面：三态边界/发现/桥客户端） |
| shell.py | ✅ 已现代化（CLI + 桥路由 + vscreen 通道） |
| policy.py | ✅ 已现代化（白名单/路径校验/STOP/VIRTUAL_SCREEN） |
| setup.sh | ✅ 已现代化（离线 wheels 安装 + 包装命令） |
