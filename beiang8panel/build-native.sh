#!/usr/bin/env bash

# 平台：Linux 本地（当前 Linux 主机原生架构，不是交叉编译）。
# external/libmodbus + external/libhv 离线静态构建；
# libcurl 使用 Linux 系统开发库。脚本不安装软件、不访问网络。

# ===== 用户配置区：可在执行前用同名环境变量覆盖 =====
BEIANG_BUILD_JOBS="${BEIANG_BUILD_JOBS:-}"
BEIANG_BUILD_TESTING="${BEIANG_BUILD_TESTING:-ON}"
BEIANG_CLEAN="${BEIANG_CLEAN:-0}"
# ===== 用户配置区结束；下面是构建逻辑 =====

set -Eeuo pipefail

# 默认选项
BUILD_TYPE="Release"
ENABLE_HTTP="ON"
CLEAN_BUILD=false
VERBOSE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --release)
            BUILD_TYPE="Release"
            shift
            ;;
        --no-http)
            ENABLE_HTTP="OFF"
            shift
            ;;
        --http)
            ENABLE_HTTP="ON"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "BeiAng8Panel Ubuntu 本地编译脚本"
            echo
            echo "Options:"
            echo "  --debug      Build Debug version (default: Release)"
            echo "  --release    Build Release version (default)"
            echo "  --no-http    Disable HTTP server"
            echo "  --http       Enable HTTP server (default)"
            echo "  --clean      Clean build before compilation"
            echo "  --verbose    Verbose output"
            echo "  --help, -h   Show this help message"
            echo
            echo "Examples:"
            echo "  $0                    # Release build with HTTP"
            echo "  $0 --debug            # Debug build with HTTP"
            echo "  $0 --no-http          # Release build without HTTP"
            echo "  $0 --debug --clean    # Debug build with clean"
            echo
            echo "Requirements:"
            echo "  build-essential, cmake"
            echo "  Linux system libcurl development files"
            echo
            echo "For HTTP server support, libmodbus and libhv are bundled:"
            echo "  external/libmodbus"
            echo "  external/libhv"
            echo
            echo "They are built automatically without network access:"
            echo "  ./scripts/build_offline_deps.sh linux <build-dir> <install-prefix>"
            echo
            echo "Or inspect the offline sources directly:"
            echo "  cd external/libmodbus"
            echo "  cd external/libhv"
            echo "  Generated files and all build outputs stay under out/"
            echo "  No git clone, download, sudo make install, or network is required"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/out/build-native"
# native 产物输出到独立目录，与交叉构建(aarch64)的 out/Release 隔离，避免架构冲突
INSTALL_DIR="$PROJECT_DIR/out/${BUILD_TYPE}-native"
DEPS_BUILD_DIR="$PROJECT_DIR/out/build/deps-linux"
DEPS_PREFIX="$PROJECT_DIR/out/deps/linux"

# 检测CPU核心数
if [ -n "$BEIANG_BUILD_JOBS" ]; then
    NPROC="$BEIANG_BUILD_JOBS"
else
    NPROC=$(nproc 2>/dev/null || echo 4)
fi
BEIANG_BUILD_JOBS="$NPROC"
if [ "$BEIANG_CLEAN" = "1" ]; then
    CLEAN_BUILD=true
fi
export BEIANG_BUILD_JOBS BEIANG_BUILD_TESTING BEIANG_CLEAN

echo "=================================="
echo "BeiAng8Panel Native Build"
echo "=================================="
echo "Build Type:    $BUILD_TYPE"
echo "HTTP Server:   $ENABLE_HTTP"
echo "Clean Build:   $CLEAN_BUILD"
echo "Build Dir:     $BUILD_DIR"
echo "Output Dir:    $INSTALL_DIR"
echo "Parallel Jobs: $NPROC"
echo "=================================="
echo

# 检查必要的命令
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: '$1' command not found!"
        echo "Please install: sudo apt install $2"
        exit 1
    fi
}

check_command cmake "cmake"
check_command gcc "build-essential"
check_command g++ "build-essential"

# 检查依赖库
check_library() {
    if [ ! -e "$PROJECT_DIR/$1" ]; then
        echo "Warning: bundled '$1' not found!"
        echo "Restore: $2"
        exit 1
    fi
}

check_library "external/libmodbus/autogen.sh" "external/libmodbus"

if [ "$ENABLE_HTTP" = "ON" ]; then
    # 检查libhv离线源码是否完整
    if [ ! -f "$PROJECT_DIR/external/libhv/CMakeLists.txt" ] || [ ! -f "$PROJECT_DIR/external/libhv/http/server/HttpServer.h" ]; then
        echo "=================================="
        echo "Error: bundled libhv source not found!"
        echo "=================================="
        echo
        echo "HTTP server support requires the bundled libhv source."
        echo
        echo "Quick build:"
        echo "  ./scripts/build_offline_deps.sh linux out/build/deps-linux out/deps/linux"
        echo
        echo "Or inspect the offline source:"
        echo "  cd external/libhv"
        echo "  mkdir -p ../../out/build/deps-linux/libhv"
        echo "  The project build script configures the static library"
        echo "  The project build script installs it under out/deps/linux"
        echo
        echo "Or use --no-http to build without HTTP server:"
        echo "  $0 --no-http"
        echo
        exit 1
    fi

    # 检查nlohmann/json是否随libhv源码提供
    if [ ! -f "$PROJECT_DIR/external/libhv/cpputil/json.hpp" ]; then
        echo "=================================="
        echo "Error: bundled nlohmann/json header not found!"
        echo "=================================="
        echo
        echo "HTTP server support requires the JSON header bundled with libhv."
        echo
        echo "Bundled header:"
        echo "  external/libhv/cpputil/json.hpp"
        echo
        echo "It is provided by the complete external/libhv source tree."
        echo
        echo "Or restore from the project archive:"
        echo "  external/libhv/cpputil/json.hpp"
        echo "  Do not install or download another copy"
        echo
        echo "Or use --no-http to build without HTTP server:"
        echo "  $0 --no-http"
        echo
        exit 1
    fi

    # 检查nghttp2构建配置
    # nghttp2是可选能力，当前external/libhv离线构建明确关闭，不依赖系统安装。
    if grep -q -- '-DWITH_NGHTTP2=OFF' "$PROJECT_DIR/scripts/build_offline_deps.sh"; then
        echo "=================================="
        echo "Info: nghttp2 disabled for offline build"
        echo "=================================="
        echo
        echo "nghttp2 is optional and only required for HTTP/2 support."
        echo
        echo "Offline build setting:"
        echo "  scripts/build_offline_deps.sh: -DWITH_NGHTTP2=OFF"
        echo
        echo "The HTTP server remains enabled without HTTP/2 support."
        echo "No system package, download, or interactive confirmation is required."
        echo
    fi
fi

echo

# 将源配置文件中的串口端口设为 native 目标 (ttyUSB0)
# 方案B: 构建脚本直接改写 config/FactoryConfig.json，
# 使 PC 端运行 native 二进制时直接读到 /dev/ttyUSB0
set_serial_port() {
    local target_port="$1"
    local cfg="$PROJECT_DIR/config/FactoryConfig.json"
    if [ -f "$cfg" ]; then
        sed -i "s|\"port\": *\"[^\"]*\"|\"port\": \"$target_port\"|" "$cfg"
        echo "Serial port set to: $target_port ($cfg)"
    else
        echo "Warning: config file not found: $cfg"
    fi
}

set_serial_port "/dev/ttyUSB0"

# 清理
if [ "$CLEAN_BUILD" = true ]; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR" "$DEPS_BUILD_DIR" "$DEPS_PREFIX" "$INSTALL_DIR"
fi

# 从工程 external/ 离线构建依赖
"$PROJECT_DIR/scripts/verify_text_eol.sh"
"$PROJECT_DIR/scripts/build_offline_deps.sh" linux "$DEPS_BUILD_DIR" "$DEPS_PREFIX"

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 配置CMake
echo "Configuring CMake..."
CMAKE_ARGS=(
    -S "$PROJECT_DIR"
    -B "$BUILD_DIR"
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
    -DBUILD_NATIVE=ON
    -DENABLE_HTTP_SERVER="$ENABLE_HTTP"
    -DBUILD_TESTING="$BEIANG_BUILD_TESTING"
    -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON
    -DBEIANG_DEPS_PREFIX="$DEPS_PREFIX"
    -DBEIANG_OUTPUT_DIR="$INSTALL_DIR"
)

cmake "${CMAKE_ARGS[@]}"

# 编译
echo
echo "Building..."
MAKE_ARGS=()
if [ "$VERBOSE" = true ]; then
    MAKE_ARGS+=(VERBOSE=1)
fi
MAKE_ARGS+=("-j$NPROC")

make -C "$BUILD_DIR" "${MAKE_ARGS[@]}"

if [ "$BEIANG_BUILD_TESTING" = "ON" ]; then
    ctest --test-dir "$BUILD_DIR" --output-on-failure
fi

(
    cd "$INSTALL_DIR"
    md5sum BeiAng8Panel > MD5SUMS
)

echo
echo "=================================="
echo "Build Complete!"
echo "=================================="
echo "Binary: $INSTALL_DIR/BeiAng8Panel"
file "$INSTALL_DIR/BeiAng8Panel"
ls -lh "$INSTALL_DIR/BeiAng8Panel"
echo "=================================="
