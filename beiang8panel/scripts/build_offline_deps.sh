#!/usr/bin/env bash

# 从仓库 external/ 离线构建 libmodbus 与 libhv。
# 平台脚本负责提供编译器、工具链和互不混用的输出目录。

set -Eeuo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "用法：$0 <macos|linux|arm64> <build-dir> <install-prefix>" >&2
    exit 2
fi

PLATFORM="$1"
BUILD_DIR="$2"
INSTALL_PREFIX="$3"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
LIBMODBUS_SOURCE="$ROOT_DIR/external/libmodbus"
LIBHV_SOURCE="$ROOT_DIR/external/libhv"
CMAKE_CMD="${CMAKE_CMD:-cmake}"
BUILD_JOBS="${BEIANG_BUILD_JOBS:-1}"

case "$PLATFORM" in
    macos|linux|arm64) ;;
    *) echo "错误：未知平台 $PLATFORM" >&2; exit 2 ;;
esac

[[ -f "$LIBMODBUS_SOURCE/src/modbus.c" ]] || { echo "错误：external/libmodbus 源码不完整。" >&2; exit 1; }
[[ -f "$LIBHV_SOURCE/CMakeLists.txt" ]] || { echo "错误：external/libhv 源码不完整。" >&2; exit 1; }

LIBMODBUS_BUILD="$BUILD_DIR/libmodbus"
LIBHV_BUILD="$BUILD_DIR/libhv"
LIBHV_BUILD_SOURCE="$BUILD_DIR/libhv-source"
if [[ "${BEIANG_CLEAN:-0}" == "1" ]]; then
    rm -rf "$LIBMODBUS_BUILD" "$LIBHV_BUILD" \
        "$LIBHV_BUILD_SOURCE" "$INSTALL_PREFIX"
fi
mkdir -p "$LIBMODBUS_BUILD" "$LIBHV_BUILD" "$INSTALL_PREFIX"

echo "[依赖 1/2] libmodbus（external，静态）"
libmodbus_args=(
    -DCMAKE_BUILD_TYPE=Release
    "-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX"
    "-DLIBMODBUS_SOURCE_DIR=$LIBMODBUS_SOURCE"
)
if [[ "$PLATFORM" == "arm64" ]]; then
    [[ -n "${BEIANG_TOOLCHAIN_FILE:-}" ]] || { echo "错误：ARM64 构建缺少 BEIANG_TOOLCHAIN_FILE。" >&2; exit 1; }
    libmodbus_args+=("-DCMAKE_TOOLCHAIN_FILE=$BEIANG_TOOLCHAIN_FILE")
fi
"$CMAKE_CMD" -S "$ROOT_DIR/cmake/libmodbus" -B "$LIBMODBUS_BUILD" "${libmodbus_args[@]}"
"$CMAKE_CMD" --build "$LIBMODBUS_BUILD" --parallel "$BUILD_JOBS"
"$CMAKE_CMD" --install "$LIBMODBUS_BUILD"

echo "[依赖 2/2] libhv（external，静态）"
"$CMAKE_CMD" -E copy_directory "$LIBHV_SOURCE" "$LIBHV_BUILD_SOURCE"
libhv_args=(
    -DCMAKE_BUILD_TYPE=Release
    "-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX"
    -DCMAKE_SKIP_RPATH=ON
    -DBUILD_SHARED=OFF
    -DBUILD_STATIC=ON
    -DBUILD_EXAMPLES=OFF
    -DBUILD_UNITTEST=OFF
    -DWITH_OPENSSL=OFF
    -DWITH_CURL=OFF
    -DWITH_NGHTTP2=OFF
)
if [[ "$PLATFORM" == "arm64" ]]; then
    [[ -n "${BEIANG_TOOLCHAIN_FILE:-}" ]] || { echo "错误：ARM64 构建缺少 BEIANG_TOOLCHAIN_FILE。" >&2; exit 1; }
    libhv_args+=("-DCMAKE_TOOLCHAIN_FILE=$BEIANG_TOOLCHAIN_FILE")
fi
"$CMAKE_CMD" -S "$LIBHV_BUILD_SOURCE" -B "$LIBHV_BUILD" "${libhv_args[@]}"
"$CMAKE_CMD" --build "$LIBHV_BUILD" --parallel "$BUILD_JOBS"
"$CMAKE_CMD" --install "$LIBHV_BUILD"

for required_file in \
    "$INSTALL_PREFIX/include/modbus/modbus.h" \
    "$INSTALL_PREFIX/include/hv/HttpServer.h" \
    "$INSTALL_PREFIX/lib/libmodbus.a" \
    "$INSTALL_PREFIX/lib/libhv_static.a"; do
    [[ -f "$required_file" ]] || { echo "错误：离线依赖产物缺失：$required_file" >&2; exit 1; }
done

echo "离线依赖完成：$INSTALL_PREFIX"
