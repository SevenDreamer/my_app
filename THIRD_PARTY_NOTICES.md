# Third-Party Notices

本仓库包含以下第三方开源组件的派生代码。MIT 许可要求保留版权声明与许可文本，
逐份声明如下。

---

## DSHA

- 来源：<https://github.com/DSH-APP/DSHA>
- 许可：MIT License
- 版权：Copyright (c) 2026 qiannianhuanxiang
- 派生文件（带逐文件归因头）：
  - `packages/dsha_core/python/`（pair.py / shell.py / policy.py / _adb_common.py / setup.sh）
  - `packages/dsha_core/lib/src/install/`（install_stage.dart / sensitive_data.dart）
  - 后续批次派生文件同样登记于此。

MIT License 全文：

```
MIT License

Copyright (c) 2026 qiannianhuanxiang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## proot（计划中，独立分发）

- 许可：GPL-2.0（随运行时层独立分发 + COPYING，不并入本仓树，见
  `docs/EMBEDDED_HERMES_RUNTIME.md` 第 2 节）

---

## Rust 原生依赖（dsha_runtime / libdsha_runtime.so，随 APK 分发）

以下 crate 编译进 `libdsha_runtime.so`（许可经 cargo metadata 逐包核实）：

| crate | 版本 | 许可 |
|---|---|---|
| adler2 | 2.0.1 | 0BSD OR MIT OR Apache-2.0 |
| bitflags | 2.13.2 | MIT OR Apache-2.0 |
| block-buffer | 0.10.4 | MIT OR Apache-2.0 |
| cfg-if | 1.0.5 | MIT OR Apache-2.0 |
| cpufeatures | 0.2.17 | MIT OR Apache-2.0 |
| crc32fast | 1.5.2 | MIT OR Apache-2.0 |
| crypto-common | 0.1.7 | MIT OR Apache-2.0 |
| digest | 0.10.7 | MIT OR Apache-2.0 |
| errno | 0.3.14 | MIT OR Apache-2.0 |
| flate2 | 1.1.10 | MIT OR Apache-2.0 |
| generic-array | 0.14.7 | MIT |
| miniz_oxide | 0.9.1 | MIT OR Zlib OR Apache-2.0 |
| rustix | 1.1.5 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT |
| sha2 | 0.10.9 | MIT OR Apache-2.0 |
| simd-adler32 | 0.3.10 | MIT |
| tinyvec | 1.13.3 | Zlib OR Apache-2.0 OR MIT |
| typenum | 1.20.1 | MIT OR Apache-2.0 |
| unicode-normalization | 0.1.26 | (MIT OR Apache-2.0) AND Unicode-3.0 |
| windows-link | 0.2.1 | MIT OR Apache-2.0 |

（Rust 标准库运行时按 MIT/Apache-2.0 双许可随产物分发；cargo tree 中的
重复低版本条目如 bitflags 1.3.2 / miniz_oxide 0.8.9 为间接锁版本，未实际
编译进本产物的以构建闭包为准。）
