#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：首次使用只需要修改下面这一行绝对路径
# -----------------------------------------------------------------------------
FLUTTER337_SDK_PATH="/opt/flutter_3.3.7"
# Linux PC 配置目录可在执行前通过 FLUTTER_BOARD_CONFIG_ROOT 覆盖。
# -----------------------------------------------------------------------------

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-$ROOT_DIR/config}"
LINUX_CMAKE="$ROOT_DIR/linux/CMakeLists.txt"
FLUTTER337_SDK="${FLUTTER337_SDK:-$FLUTTER337_SDK_PATH}"
OFFLINE_PUB_CACHE="${FLUTTER337_PUB_CACHE:-$ROOT_DIR/third_party/pub-cache}"
MODE="${1:-release}"

usage() {
  cat <<'EOF'
用法：./build_linux.sh [release|debug]

首次使用：修改脚本顶部的 FLUTTER337_SDK_PATH 绝对路径。
该脚本只在 Linux PC 本机生成同架构 GTK 桌面程序，不执行交叉编译。
可用 FLUTTER_BOARD_CONFIG_ROOT=/writable/config 覆盖配置目录。
EOF
}

case "$MODE" in
  release|debug) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "错误：模式只能是 release 或 debug。" >&2; usage >&2; exit 2 ;;
esac

[ "$(uname -s)" = "Linux" ] || {
  echo "错误：Linux PC 版本必须在 Linux 主机上本机构建。" >&2
  exit 1
}
case "$(uname -m)" in
  x86_64|amd64) FLUTTER_ARCH="x64" ;;
  aarch64|arm64) FLUTTER_ARCH="arm64" ;;
  *) echo "错误：暂不支持的 Linux 主机架构：$(uname -m)" >&2; exit 1 ;;
esac
case "$FLUTTER337_SDK" in
  /*) ;;
  *) echo "错误：Flutter SDK 必须使用绝对路径。" >&2; exit 1 ;;
esac

FLUTTER="$FLUTTER337_SDK/bin/flutter"
[ -x "$FLUTTER" ] || { echo "错误：找不到 Flutter：$FLUTTER" >&2; exit 1; }
[ "$(cat "$FLUTTER337_SDK/version" 2>/dev/null || true)" = "3.3.7" ] || {
  echo "错误：该脚本固定要求 Flutter 3.3.7。" >&2
  exit 1
}
[ -d "$OFFLINE_PUB_CACHE/hosted/pub.dartlang.org" ] || {
  echo "错误：缺少离线 Pub 缓存：$OFFLINE_PUB_CACHE" >&2
  exit 1
}
for command_name in cmake ninja pkg-config; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少命令：$command_name" >&2
    exit 1
  }
done
BINARY_NAME="$(sed -n 's/^[[:space:]]*set(BINARY_NAME[[:space:]]*"\([^"]*\)".*/\1/p' "$LINUX_CMAKE" | head -n 1)"
[ -n "$BINARY_NAME" ] || {
  echo "错误：无法从 $LINUX_CMAKE 读取 BINARY_NAME。" >&2
  exit 1
}
mkdir -p "$FLUTTER_BOARD_CONFIG_ROOT"

echo "$BINARY_NAME Linux PC 本机构建：$MODE（离线，$FLUTTER_ARCH）"
echo "配置目录：$FLUTTER_BOARD_CONFIG_ROOT"
(
  cd "$ROOT_DIR"
  export PUB_CACHE="$OFFLINE_PUB_CACHE"
  export PUB_HOSTED_URL="https://pub.dartlang.org"
  export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:9"
  export FLUTTER_SUPPRESS_ANALYTICS=true
  "$FLUTTER" pub get --offline
  "$FLUTTER" build linux --no-pub "--$MODE" \
    "--dart-define=DASHBOARD_CONFIG_ROOT=$FLUTTER_BOARD_CONFIG_ROOT"
)

EXECUTABLE="$ROOT_DIR/build/linux/$FLUTTER_ARCH/$MODE/bundle/$BINARY_NAME"
[ -x "$EXECUTABLE" ] || { echo "错误：未找到产物：$EXECUTABLE" >&2; exit 1; }
echo "构建完成：$EXECUTABLE"
