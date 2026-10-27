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
