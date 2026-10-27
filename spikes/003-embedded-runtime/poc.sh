#!/data/data/com.termux/files/usr/bin/bash
# M-R R0 PoC：在手机上验证 rootfs + proot + hermes-agent 链路（Termux 里跑）
#
# 这是验证脚本不是产品代码——产品化（R1-R4）见 docs/EMBEDDED_HERMES_RUNTIME.md。
# 用法：bash poc.sh    （约 15-30 分钟，需网络；rootfs ~30MB + hermes 依赖若干）
set -euo pipefail

UBUNTU_VER=24.04.5
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-${UBUNTU_VER}-base-arm64.tar.gz"
UBUNTU_SHA=a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2
WORK="$HOME/hermes-runtime"
ROOTFS="$WORK/rootfs"

echo "==> [0/6] Termux 依赖（proot 是 GPL-2.0 独立工具）"
pkg install -y proot tar coreutils curl

mkdir -p "$WORK"
cd "$WORK"

echo "==> [1/6] 下载 ubuntu-base ${UBUNTU_VER}（约 30MB）"
if [ ! -f ubuntu-base.tar.gz ]; then
  curl -L --retry 3 -o ubuntu-base.tar.gz "$UBUNTU_URL"
fi
echo "${UBUNTU_SHA} *ubuntu-base.tar.gz" | sha256sum -c -

echo "==> [2/6] 解包 rootfs（事务式：全新目录，完成即就绪）"
if [ ! -x "$ROOTFS/bin/bash" ]; then
  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"
  tar -xzf ubuntu-base.tar.gz -C "$ROOTFS"
fi

echo "==> [3/6] DNS / hosts（proot 不虚拟化网络）"
printf 'nameserver 223.5.5.5\nnameserver 8.8.8.8\n' > "$ROOTFS/etc/resolv.conf"
grep -q hermes-poc "$ROOTFS/etc/hosts" || printf '127.0.0.1 localhost hermes-poc\n' >> "$ROOTFS/etc/hosts"

# 在 rootfs 里跑命令（假 root + --link2symlink，Termux proot 标准姿势）
run_in() {
  proot --link2symlink -0 -r "$ROOTFS" \
    -b /dev -b /proc -b /sys \
    -w /root \
    /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash --login -c "$1"
}

echo "==> [4/6] 基础工具"
run_in "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl git ca-certificates"

echo "==> [5/6] 安装 hermes-agent（MIT，官方 install.sh——rootfs 是 glibc Ubuntu，原生支持）"
run_in "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"

echo "==> [6/6] 开 webapp（稳定端口 9120，/api/ws 同口）"
run_in "hermes config set webapp.enabled true || true"

echo ""
echo "✅ 环境就绪。下一步：bash enter.sh 进入系统并启动 gateway，"
echo "   然后在 my_app「Hermes」页点「检测本机网关」。"
