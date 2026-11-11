#!/usr/bin/env bash
# Rust core 开发链一键：cargo 测试 → release 构建 → 拷 dll 进桌面构建目录。
#
# 用法：tool/rust-dev.sh [--test-only]
# 说明：Flutter 热重载不覆盖 Rust——改了 rust/ 就跑本脚本，然后在 flutter run
# 终端按 R 热重启（dll 被运行中 app 锁定时需先退出 app 再跑）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> cargo test"
(cd rust/core && cargo test)

if [ "${1:-}" = "--test-only" ]; then
  exit 0
fi

echo "==> cargo build --release"
(cd rust/core && cargo build --release)

DLL="rust/target/release/core.dll"
DEST="build/windows/x64/runner/Debug"
if [ -d "$DEST" ]; then
  cp "$DLL" "$DEST/" && echo "==> core.dll -> $DEST（记得 flutter run 终端按 R 热重启）"
else
  echo "==> $DEST 不存在（桌面端未构建过）——dll 留在 $DLL"
fi
echo "RUST_DEV_DONE"
