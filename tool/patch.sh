#!/usr/bin/env bash
# 发热更 patch（与 tool/release.sh 同源注入 SENTRY_DEFINES）。
#
# 坑（真机实证）：patch 替换整个 Dart 快照——构建时漏 --dart-define 会把
# SENTRY_DSN 抹空，app 里「上报诊断」直接显示「Sentry 未启用」。patch 的
# defines 必须与目标 release 一致。
#
# 用法：tool/patch.sh <release-version> ["patch 更新说明"]
#   如 tool/patch.sh 1.3.0-dev.25+69 "修复六步探针超时"
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

tool/shorebird.sh patch android --release-version="$REL" $SENTRY_DEFINES

# ---- 刷新 R2 manifest 的 patch 节（app 后台巡检据此发「热更就绪」通知） ----
# 凭据缺失/解析失败只跳过刷新（警告退出），不影响 patch 本身已发布。
if [ -f tool/r2.env ]; then
  . tool/r2.env
fi
if [ -z "${S3_ACCESS_KEY_ID:-}" ] || [ -z "${S3_SECRET_ACCESS_KEY:-}" ] || [ -z "${R2_BASE_URL:-}" ]; then
  echo "⚠️ 跳过 manifest patch 节刷新（缺 S3_ACCESS_KEY_ID/S3_SECRET_ACCESS_KEY/R2_BASE_URL）" >&2
  exit 0
fi
R2_BUCKET="${R2_BUCKET:-my-app-apks}"
R2_PREFIX="${R2_PREFIX:-my_app_dist}"
R2_ENDPOINT="${R2_ENDPOINT:-0a5e8b01a70285a19456d23671233de8.r2.cloudflarestorage.com}"
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY

r2_put() { # r2_put <bucket-key> <本地文件> <content-type>
  local key="$1" file="$2" ctype="$3"
  # --noproxy：R2 直连可达；代理传大文件易断（Broken pipe），上传固定走直连
  curl -sS --noproxy '*' --aws-sigv4 "aws:amz:auto:s3" \
    --user "$S3_ACCESS_KEY_ID:$S3_SECRET_ACCESS_KEY" \
    -H "Content-Type: $ctype" \
    --upload-file "$file" \
    "https://$R2_ENDPOINT/$R2_BUCKET/$key" \
    -w "已上传：$key（%{size_upload} 字节，HTTP %{http_code}）\n"
}

APP_ID=$(grep '^app_id:' shorebird.yaml | awk '{print $2}')
# patch 号：从 patches list 只解析数字取最大号（不抄版本/日期串——
# 工具输出的串有打码坑，PITFALLS #31）
PATCH_NUMBER=$(tool/shorebird.sh patches list --app-id "$APP_ID" --release-version "$REL" 2>/dev/null \
  | grep -oE '[Pp]atch [0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1 || true)
if [ -z "$PATCH_NUMBER" ]; then
  echo "⚠️ 未能解析 patch 号，跳过 manifest patch 节刷新（不影响 patch 本身）" >&2
  exit 0
fi

mkdir -p build
curl -sS --noproxy '*' -o build/manifest.json "$R2_BASE_URL/manifest.json" || true
if [ ! -s build/manifest.json ]; then
  echo "⚠️ 拉取现 manifest 失败，跳过 patch 节刷新" >&2
  exit 0
fi

# 解释器探测（同 release.sh：WindowsApps python3 是商店占位 stub，试跑验证）
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" --version >/dev/null 2>&1; then
    PY="$c"
    break
  fi
done
[ -n "$PY" ] || { echo "需要可用的 python3 或 python" >&2; exit 1; }

"$PY" - "build/manifest.json" "$REL" "$PATCH_NUMBER" "$PATCH_NOTES" <<'PY'
import datetime
import json
import sys

path, release, number, notes = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    m = json.load(f)
m["patch"] = {
    "release": release,
    "number": int(number),
    "notes": notes,
    "time": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
print(f"manifest patch 节已更新：Patch {number} → {release}")
PY

# 双写（与 release.sh 同规）：新版本读 manifest.json，老版本读 manifest-dev.json
r2_put "$R2_PREFIX/manifest.json" build/manifest.json application/json
cp build/manifest.json build/manifest-dev.json
r2_put "$R2_PREFIX/manifest-dev.json" build/manifest-dev.json application/json
echo "manifest 已刷新：$R2_BASE_URL/manifest.json"
