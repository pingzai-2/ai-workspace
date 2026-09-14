#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：Linux PC 运行配置文件，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
BEIANG_CONFIG="${BEIANG_CONFIG:-}"
BEIANG_CONFIG_2="${BEIANG_CONFIG_2:-}"
BEIANG_CONFIG_3="${BEIANG_CONFIG_3:-}"
BEIANG_CONFIG_4="${BEIANG_CONFIG_4:-}"
# -----------------------------------------------------------------------------

# 运行 build_linux.sh 已生成的同架构 Linux PC 应用。
# 此处配置只用于运行，不能改变已编译 BeiAng8Panel。

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
CONFIG_PATH="${BEIANG_CONFIG:-$ROOT_DIR/config/FactoryConfig.json}"
CONFIG_PATH_2="${BEIANG_CONFIG_2:-$ROOT_DIR/config/FactoryConfig_2.json}"
CONFIG_PATH_3="${BEIANG_CONFIG_3:-$ROOT_DIR/config/FactoryConfig_3.json}"
CONFIG_PATH_4="${BEIANG_CONFIG_4:-$ROOT_DIR/config/FactoryConfig_4.json}"
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
  x86_64|amd64|aarch64|arm64) ;;
  *) echo "错误：暂不支持的 Linux 主机架构：$(uname -m)" >&2; exit 1 ;;
esac

EXECUTABLE="$ROOT_DIR/out/linux/$MODE/BeiAng8Panel"
[ -x "$EXECUTABLE" ] || {
  echo "错误：缺少产物，请先运行 ./build_linux.sh $MODE" >&2
  exit 1
}
[ -f "$CONFIG_PATH" ] || {
  echo "错误：缺少 BeiAng8Panel 配置：$CONFIG_PATH" >&2
  exit 1
}

echo "启动：$EXECUTABLE"
echo "配置文件：$CONFIG_PATH"
echo "配置文件：$CONFIG_PATH_2"
echo "配置文件：$CONFIG_PATH_3"
echo "配置文件：$CONFIG_PATH_4"
exec "$EXECUTABLE" \
  -c "$CONFIG_PATH" \
  -c "$CONFIG_PATH_2" \
  -c "$CONFIG_PATH_3" \
  -c "$CONFIG_PATH_4"
