#!/data/data/com.termux/files/usr/bin/bash
# 001a：两台手机验证 ADB 无线调试控制链路（在手机 A 的 Termux 跑）
# 用法: bash termux_probe.sh <配对IP:端口> <6位配对码> <连接IP:端口>
set -u

PAIR_ADDR="${1:?用法: bash termux_probe.sh <配对IP:端口> <配对码> <连接IP:端口>}"
PAIR_CODE="${2:?缺配对码（手机B弹窗里的6位数字）}"
CONN_ADDR="${3:?缺连接地址（手机B无线调试主页的IP:端口，注意不是配对端口）}"

echo "== 1/5 装 adb（已装则跳过）=="
pkg install -y android-tools || { echo "❌ pkg install 失败"; exit 1; }
adb version | head -1

echo "== 2/5 起 adb server =="
adb start-server

echo "== 3/5 配对 $PAIR_ADDR =="
if adb pair "$PAIR_ADDR" "$PAIR_CODE"; then
  echo "✅ 配对成功"
else
  echo "❌ 配对失败——检查配对码是否过期（约30秒）、端口是否为弹窗端口"
  exit 1
fi

echo "== 4/5 连接 $CONN_ADDR =="
if adb connect "$CONN_ADDR"; then
  echo "✅ 连接成功"
else
  echo "❌ 连接失败——检查端口是否为无线调试主页端口"
  exit 1
fi

SERIAL="$CONN_ADDR"
echo "== 5/5 控制测试（手机B应出现点击反馈）=="
adb -s "$SERIAL" shell getprop ro.product.model && echo "✅ shell 通"
adb -s "$SERIAL" shell input tap 500 1000 && echo "✅ input tap 已发（看手机B有没有点）"
adb -s "$SERIAL" shell screencap -p /sdcard/spike001.png && echo "✅ 截图已存手机B: /sdcard/spike001.png"

echo ""
echo "全部通过 → 001a 命门验证成功（app 内 adb_client 连 127.0.0.1:5037 即可复用此链路）"
