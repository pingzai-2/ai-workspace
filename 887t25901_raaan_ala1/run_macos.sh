#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：macOS 运行窗口尺寸，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
FLUTTER_WINDOW_WIDTH="${FLUTTER_WINDOW_WIDTH:-800}"
FLUTTER_WINDOW_HEIGHT="${FLUTTER_WINDOW_HEIGHT:-500}"
# -----------------------------------------------------------------------------

# 运行 build_macos.sh 已经生成的 macOS 应用。
# 此处配置只用于运行前准备和显示，不能改变已编译 App；必须与 build_macos.sh 的编译值一致。
# Command+Q、关闭应用或在终端按 Ctrl+C 都会结束本次运行。

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-$ROOT_DIR/config}"
APP_INFO_CONFIG="$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig"
MODE="${1:-release}"

case "$MODE" in
  release)
    PRODUCT_MODE_DIR="Release"
    ;;
  debug)
    PRODUCT_MODE_DIR="Debug"
    ;;
  -h|--help)
    echo "用法：./run_macos.sh [release|debug]"
    exit 0
    ;;
  *)
    echo "错误：不支持的运行模式：$MODE" >&2
    echo "用法：./run_macos.sh [release|debug]" >&2
    exit 2
    ;;
esac

[ -f "$APP_INFO_CONFIG" ] || {
  echo "错误：缺少 macOS App 配置：$APP_INFO_CONFIG" >&2
  exit 1
}
PRODUCT_NAME="$(awk -F= '/^[[:space:]]*PRODUCT_NAME[[:space:]]*=/ {sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]\r]+$/, ""); print; exit}' "$APP_INFO_CONFIG")"
[ -n "$PRODUCT_NAME" ] || {
  echo "错误：无法从 $APP_INFO_CONFIG 读取 PRODUCT_NAME。" >&2
  exit 1
}

APP="$ROOT_DIR/build/macos/Build/Products/$PRODUCT_MODE_DIR/$PRODUCT_NAME.app"
EXECUTABLE="$APP/Contents/MacOS/$PRODUCT_NAME"

if [ ! -x "$EXECUTABLE" ]; then
  echo "错误：缺少 $MODE 构建产物，请先运行：" >&2
  echo "  ./build_macos.sh $MODE" >&2
  exit 1
fi
mkdir -p "$FLUTTER_BOARD_CONFIG_ROOT"
export FLUTTER_WINDOW_WIDTH FLUTTER_WINDOW_HEIGHT

APP_PID=""
cleanup() {
  trap - EXIT INT TERM HUP
  if [ -n "$APP_PID" ]; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM HUP

echo "启动：$APP"
echo "配置目录：$FLUTTER_BOARD_CONFIG_ROOT"
echo "运行窗口：${FLUTTER_WINDOW_WIDTH}x${FLUTTER_WINDOW_HEIGHT}"
"$EXECUTABLE" &
APP_PID=$!

set +e
wait "$APP_PID"
STATUS=$?
set -e
APP_PID=""

echo "应用已退出。"
exit "$STATUS"
