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

# Android 双 ABI（cargo-ndk -> runtime/out/<abi>/jniLibs/<abi>/，Gradle flavor 读取）
# 注意：cargo-ndk 的 -o 必须 Windows 风格路径（MSYS 会把 /d/ 转成 D:\d\——
# 换机即坏的写死路径教训，2026-11-10 用户指正）——pwd -W 动态推导
REPO_WIN=$(pwd -W 2>/dev/null || pwd)
echo "==> cargo ndk（arm64-v8a + x86_64）-> $REPO_WIN/runtime/out/..."
(cd rust/core &&   cargo ndk -t arm64-v8a -o "$REPO_WIN/runtime/out/arm64-v8a/jniLibs" build --release &&   cargo ndk -t x86_64 -o "$REPO_WIN/runtime/out/x86_64/jniLibs" build --release)

echo "RUST_DEV_DONE"
