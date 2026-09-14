#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：Linux PC 运行窗口尺寸，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
FLUTTER_WINDOW_WIDTH="${FLUTTER_WINDOW_WIDTH:-800}"
FLUTTER_WINDOW_HEIGHT="${FLUTTER_WINDOW_HEIGHT:-500}"
# -----------------------------------------------------------------------------

# 运行 build_linux.sh 已生成的同架构 Linux PC 应用。
# 此处配置只用于运行前准备和显示，不能改变已编译 App；必须与 build_linux.sh 的编译值一致。

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-$ROOT_DIR/config}"
LINUX_CMAKE="$ROOT_DIR/linux/CMakeLists.txt"
MODE="${1:-release}"

case "$MODE" in
  release|debug) ;;
  -h|--help) echo "用法：./run_linux.sh [release|debug]"; exit 0 ;;
  *) echo "错误：模式只能是 release 或 debug。" >&2; exit 2 ;;
esac
[ "$(uname -s)" = "Linux" ] || {
  echo "错误：Linux PC 版本必须在 Linux 主机上本机运行。" >&2
  exit 1
}
case "$(uname -m)" in
  x86_64|amd64) FLUTTER_ARCH="x64" ;;
  aarch64|arm64) FLUTTER_ARCH="arm64" ;;
  *) echo "错误：暂不支持的 Linux 主机架构：$(uname -m)" >&2; exit 1 ;;
esac

BINARY_NAME="$(sed -n 's/^[[:space:]]*set(BINARY_NAME[[:space:]]*"\([^"]*\)".*/\1/p' "$LINUX_CMAKE" | head -n 1)"
[ -n "$BINARY_NAME" ] || {
  echo "错误：无法从 $LINUX_CMAKE 读取 BINARY_NAME。" >&2
  exit 1
}

EXECUTABLE="$ROOT_DIR/build/linux/$FLUTTER_ARCH/$MODE/bundle/$BINARY_NAME"
[ -x "$EXECUTABLE" ] || {
  echo "错误：缺少产物，请先运行 ./build_linux.sh $MODE" >&2
  exit 1
}
mkdir -p "$FLUTTER_BOARD_CONFIG_ROOT"
export FLUTTER_WINDOW_WIDTH FLUTTER_WINDOW_HEIGHT
echo "启动：$EXECUTABLE"
echo "配置目录：$FLUTTER_BOARD_CONFIG_ROOT"
echo "运行窗口：${FLUTTER_WINDOW_WIDTH}x${FLUTTER_WINDOW_HEIGHT}"
exec "$EXECUTABLE"
