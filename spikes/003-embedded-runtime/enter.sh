#!/data/data/com.termux/files/usr/bin/bash
# 进入 PoC 容器并启动 hermes gateway（前台，日志直出）
# 用法：bash enter.sh
set -euo pipefail

WORK="$HOME/hermes-runtime"
ROOTFS="$WORK/rootfs"

[ -x "$ROOTFS/bin/bash" ] || { echo "rootfs 未就绪——先跑 bash poc.sh"; exit 1; }

echo "==> 启动 hermes gateway（webapp :9120）；Ctrl+C 停止"
proot --link2symlink -0 -r "$ROOTFS" \
  -b /dev -b /proc -b /sys \
  -w /root \
  /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash --login -c "hermes gateway restart && sleep 2 && echo '--- gateway 状态 ---' && (hermes gateway status || true) && echo '' && echo '现在打开 my_app → Hermes → 检测本机网关' && echo '保持本终端运行；要看前台日志：hermes webapp' && exec bash"
