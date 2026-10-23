#!/usr/bin/env bash
# Shorebird CLI 本地调用包装。
# 职责：注入构建环境变量 + 绕过官方 shim 的 MSYS 路径 bug，一条命令直用。
# 用法：tool/shorebird.sh <shorebird 参数...>
#   例：tool/shorebird.sh patch android --release-version=1.3.0-dev.4+48
set -e

cd "$(dirname "$0")/.."

# 构建环境：部分终端不继承用户级环境变量，缺了报 "No Android SDK found"。
# 已在别处设置时不覆盖。
export ANDROID_HOME="${ANDROID_HOME:-D:/AndroidSdk}"
export JAVA_HOME="${JAVA_HOME:-C:/Users/${USERNAME}/scoop/apps/temurin17-jdk/current}"

# 官方 ~/.shorebird/bin/shorebird 的 bash shim 会把 MSYS 路径喂给原生 dart 直接报错，
# 这里绕过 shim，直接用 dart.exe 跑 shorebird.snapshot（跳过 .tmp 半成品目录）。
SB_HOME="C:/Users/${USERNAME}/.shorebird/bin"
DART=$(ls "$SB_HOME"/cache/flutter/*/bin/cache/dart-sdk/bin/dart.exe 2>/dev/null | grep -v '\.tmp' | head -1)
if [ -z "$DART" ]; then
  echo "找不到 shorebird 缓存的 dart.exe（$SB_HOME/cache/flutter/）——先运行一次 ~/.shorebird/bin/shorebird.bat 完成 bootstrap" >&2
  exit 1
fi

exec "$DART" run "$SB_HOME/cache/shorebird.snapshot" "$@"
