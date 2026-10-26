#!/usr/bin/env bash
# Shorebird CLI 本地调用包装（跨平台：macOS / Linux / Windows(Git Bash·MSYS·Cygwin)）。
#
# 职责：
#   1. 补齐构建环境变量（ANDROID_HOME / JAVA_HOME）——部分终端不继承用户级环境，
#      缺了报 "No Android SDK found"。
#   2. Windows 下绕过官方 bash shim 的 MSYS 路径 bug（shim 会把 MSYS 路径喂给
#      原生 dart 直接报错），改为直接用 dart 跑 shorebird.snapshot。
#      macOS/Linux 的 shim 无此问题，走正常入口。
#
# 用法：tool/shorebird.sh <shorebird 参数...>
#   例：tool/shorebird.sh patch android --release-version=1.3.0-dev.6+50
#       tool/shorebird.sh releases list --app-id <uuid>
#
# 环境变量一律「已设则不覆盖」，便于 CI 或用户自行指定。
set -e

cd "$(dirname "$0")/.."

# ─────────────────────────────────────────────────────────────
# 判定运行平台
# ─────────────────────────────────────────────────────────────
case "$(uname -s 2>/dev/null || echo Windows)" in
  Darwin)                  OS=macos ;;
  Linux)                   OS=linux ;;
  MINGW*|MSYS*|CYGWIN*|"") OS=windows ;;
  *)                       OS=other ;;
esac

# ─────────────────────────────────────────────────────────────
# 构建环境变量：按平台探测，已有值一律不覆盖
# ─────────────────────────────────────────────────────────────
if [ -z "${ANDROID_HOME:-}" ]; then
  case "$OS" in
    macos)
      for d in "$HOME/Library/Android/sdk" /opt/homebrew/share/android-commandlinetools; do
        [ -d "$d" ] && export ANDROID_HOME="$d" && break
      done
      ;;
    linux)
      for d in "$HOME/Android/Sdk" "$HOME/android-sdk" /opt/android-sdk; do
        [ -d "$d" ] && export ANDROID_HOME="$d" && break
      done
      ;;
    windows)
      # 注意：必须原生盘符形式（D:/...）——这些值以环境变量传给原生
      # flutter/gradle，MSYS 形式（/d/...）在不做路径转换的终端里会报
      # "No Android SDK found"（bash 的 [ -d ] 同样认 D:/ 形式）
      for d in "C:/AndroidSdk" "D:/AndroidSdk" "C:/Users/${USERNAME:-}/AppData/Local/Android/Sdk"; do
        [ -d "$d" ] && export ANDROID_HOME="$d" && break
      done
      ;;
  esac
fi

if [ -z "${JAVA_HOME:-}" ]; then
  case "$OS" in
    macos)
      # Homebrew temurin/jdk 都会挂这个软链；没有就交给 java 在 PATH 上找
      for d in /opt/homebrew/opt/openjdk@17 /opt/homebrew/opt/openjdk /Library/Java/JavaVirtualMachines/*/Contents/Home; do
        [ -d "$d" ] && export JAVA_HOME="$d" && break
      done
      ;;
    windows)
      for d in "C:/Users/${USERNAME:-}/scoop/apps/temurin17-jdk/current"; do
        [ -d "$d" ] && export JAVA_HOME="$d" && break
      done
      ;;
  esac
fi

# ─────────────────────────────────────────────────────────────
# 定位 shorebird 可执行入口
# ─────────────────────────────────────────────────────────────
SB_HOME="${SHOREBIRD_HOME:-$HOME/.shorebird}"

if [ "$OS" = "windows" ]; then
  # Windows：绕过 bash shim，直接用 shorebird 自带的 dart 跑 snapshot。
  # 跳过 .tmp 目录（安装中断会留下半成品，选中它会启动失败）。
  WIN_SB_HOME="C:/Users/${USERNAME:-}/.shorebird/bin"
  DART=$(ls "$WIN_SB_HOME"/cache/flutter/*/bin/cache/dart-sdk/bin/dart.exe 2>/dev/null \
        | grep -v '\.tmp' | head -1)
  if [ -z "$DART" ]; then
    echo "找不到 shorebird 缓存的 dart.exe（$WIN_SB_HOME/cache/flutter/）——" >&2
    echo "先运行一次 ~/.shorebird/bin/shorebird.bat 完成 bootstrap" >&2
    exit 1
  fi
  exec "$DART" run "$WIN_SB_HOME/cache/shorebird.snapshot" "$@"
fi

# macOS / Linux：优先用 PATH 上的 shorebird（官方 shim 在类 Unix下正常工作）
if command -v shorebird >/dev/null 2>&1; then
  exec shorebird "$@"
fi

# PATH 上没有 → 直接用安装目录里的 shim（无需导出 PATH）
# 实际布局：~/.shorebird/bin/shorebird（shim）、~/.shorebird/bin/cache/shorebird.snapshot
if [ -x "$SB_HOME/bin/shorebird" ]; then
  exec "$SB_HOME/bin/shorebird" "$@"
fi

# shim 损坏时的兜底：直接用 snapshot（注意 snapshot 在 bin/cache/ 下，不是 cache/）
SNAPSHOT=$(ls "$SB_HOME"/bin/cache/shorebird.snapshot 2>/dev/null | head -1)
DART=$(ls "$SB_HOME"/bin/cache/flutter/*/bin/cache/dart-sdk/bin/dart 2>/dev/null \
      | grep -v '\.tmp' | head -1)
if [ -n "$SNAPSHOT" ] && [ -n "$DART" ]; then
  exec "$DART" run "$SNAPSHOT" "$@"
fi

echo " Shorebird 未安装（未找到 $SB_HOME/bin/shorebird，PATH 上也没有 shorebird）" >&2
echo "   安装：curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash" >&2
exit 1
