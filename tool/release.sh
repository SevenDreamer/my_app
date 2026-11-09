#!/usr/bin/env bash
# 发版脚本：Shorebird release 构建 → 上传安装包到 Cloudflare R2 → 刷新 manifest。
# 免设备码分发：用户端匿名 GET manifest 即可检查更新并下载安装包。
#
# 用法：tool/release.sh ["更新说明"]
#   例：tool/release.sh "修复机器人眼睛渲染"
#   （兼容旧用法：tool/release.sh [stable|dev] ["更新说明"]，首参通道名被忽略——
#     app 内「更新通道」已移除，所有版本收同一 manifest 推送）
# 前置：pubspec 版本号已 bump（+N 必须自增，脚本会检测同号并拒绝）。
#
# 依赖环境变量（可写入 tool/r2.env，脚本自动加载；该文件不入库）：
#   S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY  必填：R2 的 S3 API 凭据
#   R2_BASE_URL            必填：公开访问地址
#                          （本项目：https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist）
#   R2_BUCKET              选填：默认 my-app-apks
#   R2_PREFIX              选填：桶内目录前缀，默认 my_app_dist
#
# manifest 格式（脚本自动生成，App 端 ManifestUpdateSource 解析）：
#   {"version": "...", "notes": "...", "page": "下载页",
#    "apks": {"arm64-v8a": "url", "universal": "url"},
#    "patch": {"release": "version+build", "number": N, "notes": "...", "time": "..."}}
#   （patch 节由 tool/patch.sh 发热更时刷新，app 后台巡检据此发「热更就绪」通知；
#     release.sh 发版时不写该节——新 release 自然清空旧 patch 记录）
set -e
cd "$(dirname "$0")/.."

# 首参兼容：stable|dev 为旧通道名（已无意义，忽略），其余视为更新说明
if [ "$1" = "stable" ] || [ "$1" = "dev" ]; then
  shift
fi
NOTES=${1:-}

# 本地私密配置（tool/r2.env，不入库）优先加载
if [ -f tool/r2.env ]; then
  . tool/r2.env
fi
# Sentry ingest 配置（tool/sentry.env，不入库；DSN 可公开，只发不读）
if [ -f tool/sentry.env ]; then
  . tool/sentry.env
fi

: "${S3_ACCESS_KEY_ID:?需要 S3_ACCESS_KEY_ID（R2 的 S3 凭据），可写入 tool/r2.env}"
: "${S3_SECRET_ACCESS_KEY:?需要 S3_SECRET_ACCESS_KEY（R2 的 S3 凭据），可写入 tool/r2.env}"
: "${R2_BASE_URL:?需要 R2_BASE_URL（公开访问地址，如 https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist）}"
R2_BUCKET="${R2_BUCKET:-my-app-apks}"
R2_PREFIX="${R2_PREFIX:-my_app_dist}"
# R2 的 S3 API 端点（账号级，固定值）
R2_ENDPOINT="${R2_ENDPOINT:-0a5e8b01a70285a19456d23671233de8.r2.cloudflarestorage.com}"
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
NAME="${VER%%+*}"
APP_ID=$(grep '^app_id:' shorebird.yaml | awk '{print $2}')

# 同号防线：version+build 已注册过就拒绝（Shorebird release 唯一 + Android versionCode 单调）
if tool/shorebird.sh releases list --app-id "$APP_ID" 2>/dev/null | grep -q "$VER"; then
  echo "版本 $VER 已存在于 Shorebird——请先在 pubspec.yaml bump 版本号（至少 +N 自增）" >&2
  exit 1
fi

# 1) Shorebird release：注册 release 并产出 APK（arm64 单包，与 CI 一致）
SENTRY_DEFINES=""
if [ -n "${SENTRY_DSN:-}" ]; then
  SENTRY_DEFINES="--dart-define=SENTRY_DSN=$SENTRY_DSN --dart-define=SENTRY_ENV=production --dart-define=SENTRY_RELEASE=my_app@$VER"
fi
tool/shorebird.sh release android --artifact=apk --target-platform=android-arm64 --flavor arm64 $SENTRY_DEFINES

APK=build/app/outputs/flutter-apk/app-arm64-release.apk
ASSET="my_app-v$NAME-android-arm64-v8a.apk"

# 2) 上传安装包（curl aws-sigv4 直传；wrangler 的 r2 object 默认本地模式，勿用。
#    python urllib 传 56MB 大文件会被掐断（代理 Broken pipe / 直连 SSLEOFError），
#    curl 实测稳定——见 PITFALLS）
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

r2_put "$R2_PREFIX/$ASSET" "$APK" application/vnd.android.package-archive

# 3) 生成并上传 manifest（双写两份同内容：新版本固定读 manifest.json；
#    manifest-dev.json 供老版本（按旧「更新通道」读取）继续收到更新）
MANIFEST=manifest.json
# 解释器探测：不能只看 command -v——WindowsApps 的 python3 是商店占位
# stub（运行即静默退出 49），必须试跑 --version 验证真的可用
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" --version >/dev/null 2>&1; then
    PY="$c"
    break
  fi
done
[ -n "$PY" ] || { echo "需要可用的 python3 或 python" >&2; exit 1; }
"$PY" - "$NAME" "$NOTES" "$R2_BASE_URL/$ASSET" "build/$MANIFEST" <<'PY'
import json, sys
version, notes, url, out = sys.argv[1:5]
manifest = {
    "version": version,
    "notes": notes,
    "page": url,
    "apks": {"arm64-v8a": url, "universal": url},
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
print(f"manifest 已生成：{out}")
PY
r2_put "$R2_PREFIX/$MANIFEST" "build/$MANIFEST" application/json
cp "build/$MANIFEST" build/manifest-dev.json
r2_put "$R2_PREFIX/manifest-dev.json" build/manifest-dev.json application/json

echo "发布完成："
echo "  安装包：$R2_BASE_URL/$ASSET"
echo "  manifest：$R2_BASE_URL/$MANIFEST"

# 4) 回读验证（2026-11-06，agent 收尾协议）：上传成功 ≠ 文件可用——
#    匿名 GET manifest 比对版本 + HEAD 安装包核大小，全过输出
#    RELEASE_VERIFIED 标记（agent 进程完成通知据此执行收尾清单）。
sleep 3
REMOTE_VER=$(curl -sS --noproxy '*' "$R2_BASE_URL/manifest.json" | grep -o '"version"[^,]*' | head -1 | sed 's/.*"version"[^"]*"\([^"]*\)".*/\1/')
if [ "$REMOTE_VER" != "$NAME" ]; then
  echo "❌ 回读验证失败：manifest version=$REMOTE_VER，期望 $NAME" >&2
  exit 1
fi
REMOTE_SIZE=$(curl -sS --noproxy '*' -I "$R2_BASE_URL/$ASSET" | grep -i '^content-length' | tr -dc '0-9')
LOCAL_SIZE=$(wc -c < "$APK" | tr -dc '0-9')
if [ "$REMOTE_SIZE" != "$LOCAL_SIZE" ]; then
  echo "❌ 回读验证失败：APK 大小远端 $REMOTE_SIZE ≠ 本地 $LOCAL_SIZE" >&2
  exit 1
fi
echo "RELEASE_VERIFIED:$VER"
