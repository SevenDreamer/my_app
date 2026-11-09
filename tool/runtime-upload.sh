#!/usr/bin/env bash
# 运行时镜像上传（Linux 底座镜像上 R2，2026-11-09）：
# 把 runtime/out/<abi>/assets/runtime/ 的 rootfs+manifest+licenses 直传
# R2 的 my_app_dist/runtime/<abi>/——镜像按需下载（APK 不再内置 rootfs）。
#
# 用法：tool/runtime-upload.sh [arm64-v8a|x86_64|all]（默认 all）
# 依赖：tool/r2.env（S3_ACCESS_KEY_ID/S3_SECRET_ACCESS_KEY/R2_BASE_URL）
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f tool/r2.env ]; then . tool/r2.env; fi
: "${S3_ACCESS_KEY_ID:?需要 S3_ACCESS_KEY_ID（tool/r2.env）}"
: "${S3_SECRET_ACCESS_KEY:?需要 S3_SECRET_ACCESS_KEY（tool/r2.env）}"
R2_BUCKET="${R2_BUCKET:-my-app-apks}"
R2_PREFIX="${R2_PREFIX:-my_app_dist}"
R2_ENDPOINT="${R2_ENDPOINT:-0a5e8b01a70285a19456d23671233de8.r2.cloudflarestorage.com}"
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY

ABIS="${1:-all}"
[ "$ABIS" = all ] && ABIS="arm64-v8a x86_64"

r2_put() { # r2_put <bucket-key> <本地文件> <content-type>
  local key="$1" file="$2" ctype="$3"
  curl -sS --noproxy '*' --aws-sigv4 "aws:amz:auto:s3" \
    --user "$S3_ACCESS_KEY_ID:$S3_SECRET_ACCESS_KEY" \
    -H "Content-Type: $ctype" \
    --upload-file "$file" \
    "https://$R2_ENDPOINT/$R2_BUCKET/$key" \
    -w "已上传：$key（%{size_upload} 字节，HTTP %{http_code}）\n"
}

for abi in $ABIS; do
  SRC="runtime/out/$abi/assets/runtime"
  [ -d "$SRC" ] || { echo "跳过 $abi（$SRC 不存在——先跑 runtime/build-runtime.sh）" >&2; continue; }
  echo "== 上传 $abi 镜像 =="
  for f in "$SRC"/*; do
    name=$(basename "$f")
    if [ -d "$f" ]; then
      for sub in "$f"/*; do
        [ -f "$sub" ] && r2_put "$R2_PREFIX/runtime/$abi/$name/$(basename "$sub")" "$sub" "text/plain"
      done
    else
      case "$name" in
        *.json) ctype=application/json ;;
        *.xz) ctype=application/octet-stream ;;
        *) ctype=text/plain ;;
      esac
      r2_put "$R2_PREFIX/runtime/$abi/$name" "$f" "$ctype"
    fi
  done
done
echo "镜像上传完成：$R2_BASE_URL/runtime/"
