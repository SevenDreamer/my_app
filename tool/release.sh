#!/usr/bin/env bash
# 发版脚本：Shorebird release 构建 → 上传安装包到 Cloudflare R2 → 刷新 manifest。
# 免设备码分发：用户端匿名 GET manifest 即可检查更新并下载安装包。
#
# 用法：tool/release.sh [stable|dev] ["更新说明"]
#   例：tool/release.sh dev "修复机器人眼睛渲染"
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
#    "apks": {"arm64-v8a": "url", "universal": "url"}}
set -e
cd "$(dirname "$0")/.."

CHANNEL=${1:-dev}
NOTES=${2:-}
case "$CHANNEL" in
  stable|dev) ;;
  *) echo "用法：tool/release.sh [stable|dev] [\"更新说明\"]" >&2; exit 1 ;;
esac

# 本地私密配置（tool/r2.env，不入库）优先加载
if [ -f tool/r2.env ]; then
  . tool/r2.env
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
tool/shorebird.sh release android --artifact=apk --target-platform=android-arm64

APK=build/app/outputs/flutter-apk/app-release.apk
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

# 3) 生成并上传 manifest（stable/dev 各一份，App 按通道取）
MANIFEST=manifest.json
[ "$CHANNEL" = "dev" ] && MANIFEST=manifest-dev.json
python3 - "$NAME" "$NOTES" "$R2_BASE_URL/$ASSET" "build/$MANIFEST" <<'PY'
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

echo "发布完成（通道 $CHANNEL）："
echo "  安装包：$R2_BASE_URL/$ASSET"
echo "  manifest：$R2_BASE_URL/$MANIFEST"
