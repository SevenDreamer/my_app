#!/usr/bin/env bash
# 发热更 patch（与 tool/release.sh 同源注入 SENTRY_DEFINES）。
#
# 坑（真机实证）：patch 替换整个 Dart 快照——构建时漏 --dart-define 会把
# SENTRY_DSN 抹空，app 里「上报诊断」直接显示「Sentry 未启用」。patch 的
# defines 必须与目标 release 一致。
#
# 用法：tool/patch.sh <release-version>   如 tool/patch.sh 1.3.0-dev.25+69
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "用法：tool/patch.sh <release-version>（如 1.3.0-dev.25+69）" >&2
  exit 1
fi
REL="$1"

if [ -f tool/sentry.env ]; then
  . tool/sentry.env
fi

SENTRY_DEFINES=""
if [ -n "${SENTRY_DSN:-}" ]; then
  SENTRY_DEFINES="--dart-define=SENTRY_DSN=$SENTRY_DSN --dart-define=SENTRY_ENV=production --dart-define=SENTRY_RELEASE=my_app@$REL"
fi

exec tool/shorebird.sh patch android --release-version="$REL" $SENTRY_DEFINES
