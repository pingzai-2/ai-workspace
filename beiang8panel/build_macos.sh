#!/bin/sh

# BeiAng8Panel macOS 统一构建入口。
# 固定使用工程内 external/libmodbus、external/libhv 离线源码；curl/iconv 使用 Apple SDK。

# -----------------------------------------------------------------------------
# 用户配置区：并行编译任务数，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
BEIANG_BUILD_JOBS="${BEIANG_BUILD_JOBS:-}"
# -----------------------------------------------------------------------------
# 用户配置区结束：下方通常不需要修改
# -----------------------------------------------------------------------------

set -eu

# CMake 和依赖构建工具在 C、POSIX 等 ASCII locale 下可能无法正规化工程路径。
# 构建入口固定为 macOS 自带的 UTF-8 locale，避免受用户终端语言设置影响。
LANG="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
export LANG LC_ALL

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
MODE="${1:-release}"

usage() {
  cat <<'EOF'
用法：
  ./build_macos.sh [release|debug]

示例：
  ./build_macos.sh
  ./build_macos.sh debug
  # 高级用法：临时覆盖脚本顶部配置
  BEIANG_BUILD_JOBS=8 ./build_macos.sh release
EOF
}

case "$MODE" in
  release)
    BUILD_TYPE="Release"
    ;;
  debug)
    BUILD_TYPE="Debug"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "错误：不支持的构建模式：$MODE" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
  echo "错误：此脚本只用于 macOS 本机构建。" >&2
  exit 1
fi

for command_name in cmake make clang clang++ file otool nm md5 bash; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：缺少 $command_name 命令。" >&2
    exit 1
  }
done

if [ -z "$BEIANG_BUILD_JOBS" ]; then
  BEIANG_BUILD_JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 1)"
fi
export BEIANG_BUILD_JOBS

DEPS_BUILD_DIR="$ROOT_DIR/out/build/deps-macos"
DEPS_PREFIX="$ROOT_DIR/out/deps/macos"
APP_BUILD_DIR="$ROOT_DIR/out/build/macos-$MODE"
OUTPUT_DIR="$ROOT_DIR/out/macos/$MODE"

echo "BeiAng8Panel macOS 构建"
echo "项目目录：$ROOT_DIR"
echo "构建模式：$MODE"
echo "离线依赖：$ROOT_DIR/external"
echo "输出目录：$OUTPUT_DIR"

"$ROOT_DIR/scripts/verify_text_eol.sh"
bash "$ROOT_DIR/scripts/build_offline_deps.sh" macos "$DEPS_BUILD_DIR" "$DEPS_PREFIX"

cmake -S "$ROOT_DIR" -B "$APP_BUILD_DIR" \
  -DBUILD_NATIVE=ON \
  -DENABLE_HTTP_SERVER=ON \
  -DBUILD_TESTING=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DBEIANG_DEPS_PREFIX="$DEPS_PREFIX" \
  -DBEIANG_OUTPUT_DIR="$OUTPUT_DIR"
cmake --build "$APP_BUILD_DIR" --parallel "$BEIANG_BUILD_JOBS"

APP="$OUTPUT_DIR/BeiAng8Panel"
EXECUTABLE="$APP"
if [ ! -x "$EXECUTABLE" ]; then
  echo "错误：构建结束，但未找到可执行产物：$EXECUTABLE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/metadata"
file "$EXECUTABLE" | tee "$OUTPUT_DIR/metadata/file.txt"
otool -L "$EXECUTABLE" | tee "$OUTPUT_DIR/metadata/dependencies.txt"
nm -g "$EXECUTABLE" >"$OUTPUT_DIR/metadata/symbols.txt"
(
  cd "$OUTPUT_DIR"
  printf '%s  %s\n' "$(md5 -q BeiAng8Panel)" BeiAng8Panel >MD5SUMS
)

echo
echo "构建完成：$APP"
