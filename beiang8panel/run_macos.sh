#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：macOS 运行配置文件，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
BEIANG_CONFIG="${BEIANG_CONFIG:-}"
BEIANG_CONFIG_2="${BEIANG_CONFIG_2:-}"
BEIANG_CONFIG_3="${BEIANG_CONFIG_3:-}"
BEIANG_CONFIG_4="${BEIANG_CONFIG_4:-}"
# -----------------------------------------------------------------------------

# 运行 build_macos.sh 已经生成的 macOS 应用。
# 此处配置只用于运行，不能改变已编译 App。
# 在终端按 Ctrl+C 会结束本次运行。

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
CONFIG_PATH="${BEIANG_CONFIG:-$ROOT_DIR/config/FactoryConfig.json}"
CONFIG_PATH_2="${BEIANG_CONFIG_2:-$ROOT_DIR/config/FactoryConfig_2.json}"
CONFIG_PATH_3="${BEIANG_CONFIG_3:-$ROOT_DIR/config/FactoryConfig_3.json}"
CONFIG_PATH_4="${BEIANG_CONFIG_4:-$ROOT_DIR/config/FactoryConfig_4.json}"
MODE="${1:-release}"

case "$MODE" in
  release)
    PRODUCT_MODE_DIR="release"
    ;;
  debug)
    PRODUCT_MODE_DIR="debug"
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

[ -f "$CONFIG_PATH" ] || {
  echo "错误：缺少 BeiAng8Panel 配置：$CONFIG_PATH" >&2
  exit 1
}

APP="$ROOT_DIR/out/macos/$PRODUCT_MODE_DIR/BeiAng8Panel"
EXECUTABLE="$APP"

if [ ! -x "$EXECUTABLE" ]; then
  echo "错误：缺少 $MODE 构建产物，请先运行：" >&2
  echo "  ./build_macos.sh $MODE" >&2
  exit 1
fi

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
echo "配置文件：$CONFIG_PATH"
echo "配置文件：$CONFIG_PATH_2"
echo "配置文件：$CONFIG_PATH_3"
echo "配置文件：$CONFIG_PATH_4"
"$EXECUTABLE" \
  -c "$CONFIG_PATH" \
  -c "$CONFIG_PATH_2" \
  -c "$CONFIG_PATH_3" \
  -c "$CONFIG_PATH_4" &
APP_PID=$!

set +e
wait "$APP_PID"
STATUS=$?
set -e
APP_PID=""

echo "应用已退出。"
exit "$STATUS"
