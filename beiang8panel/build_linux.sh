#!/bin/sh

# -----------------------------------------------------------------------------
# 用户配置区：并行编译任务数，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
BEIANG_BUILD_JOBS="${BEIANG_BUILD_JOBS:-}"
# -----------------------------------------------------------------------------

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
MODE="${1:-release}"

usage() {
  cat <<'EOF'
用法：./build_linux.sh [release|debug]

该脚本只在 Linux PC 本机生成同架构 BeiAng8Panel，不执行交叉编译。
libmodbus、libhv 固定从工程 external/ 离线构建。
EOF
}

case "$MODE" in
  release) BUILD_TYPE="Release" ;;
  debug) BUILD_TYPE="Debug" ;;
  -h|--help) usage; exit 0 ;;
  *) echo "错误：模式只能是 release 或 debug。" >&2; usage >&2; exit 2 ;;
esac

[ "$(uname -s)" = "Linux" ] || {
  echo "错误：Linux PC 版本必须在 Linux 主机上本机构建。" >&2
  exit 1
}
case "$(uname -m)" in
  x86_64|amd64) PLATFORM_ARCH="x64" ;;
  aarch64|arm64) PLATFORM_ARCH="arm64" ;;
  *) echo "错误：暂不支持的 Linux 主机架构：$(uname -m)" >&2; exit 1 ;;
esac

for command_name in cmake make gcc g++ file md5sum bash; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少命令：$command_name" >&2
    exit 1
  }
done
if [ -z "$BEIANG_BUILD_JOBS" ]; then
  BEIANG_BUILD_JOBS="$(nproc)"
fi
export BEIANG_BUILD_JOBS

DEPS_BUILD_DIR="$ROOT_DIR/out/build/deps-linux"
DEPS_PREFIX="$ROOT_DIR/out/deps/linux"
APP_BUILD_DIR="$ROOT_DIR/out/build/linux-$MODE"
OUTPUT_DIR="$ROOT_DIR/out/linux/$MODE"

echo "BeiAng8Panel Linux PC 本机构建：$MODE（离线，$PLATFORM_ARCH）"
echo "离线依赖：$ROOT_DIR/external"
echo "输出目录：$OUTPUT_DIR"

"$ROOT_DIR/scripts/verify_text_eol.sh"
bash "$ROOT_DIR/scripts/build_offline_deps.sh" linux "$DEPS_BUILD_DIR" "$DEPS_PREFIX"

cmake -S "$ROOT_DIR" -B "$APP_BUILD_DIR" \
  -DBUILD_NATIVE=ON \
  -DENABLE_HTTP_SERVER=ON \
  -DBUILD_TESTING=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DBEIANG_DEPS_PREFIX="$DEPS_PREFIX" \
  -DBEIANG_OUTPUT_DIR="$OUTPUT_DIR"
cmake --build "$APP_BUILD_DIR" --parallel "$BEIANG_BUILD_JOBS"

EXECUTABLE="$OUTPUT_DIR/BeiAng8Panel"
[ -x "$EXECUTABLE" ] || { echo "错误：未找到产物：$EXECUTABLE" >&2; exit 1; }
(
  cd "$OUTPUT_DIR"
  md5sum BeiAng8Panel >MD5SUMS
  md5sum -c MD5SUMS >/dev/null
)
file "$EXECUTABLE"
echo "构建完成：$EXECUTABLE"
