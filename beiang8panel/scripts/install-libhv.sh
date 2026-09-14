#!/bin/bash
# libhv 安装脚本
# 从 GitHub 下载并编译 libhv

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 配置
LIBHV_VERSION="${LIBHV_VERSION:-v1.3.2}"
LIBHV_REPO="https://github.com/ithewei/libhv.git"
BUILD_DIR="${BUILD_DIR:-/tmp/libhv-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

# 解析参数
BUILD_SHARED_LIBS="${BUILD_SHARED_LIBS:-OFF}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --shared)
            BUILD_SHARED_LIBS=ON
            shift
            ;;
        --static)
            BUILD_SHARED_LIBS=OFF
            shift
            ;;
        --version)
            LIBHV_VERSION="$2"
            shift 2
            ;;
        --prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Install libhv from GitHub"
            echo
            echo "Options:"
            echo "  --static       Build static library (default)"
            echo "  --shared       Build shared library"
            echo "  --version VER  Specify libhv version (default: v1.3.2)"
            echo "  --prefix PATH  Install prefix (default: /usr/local)"
            echo "  --help, -h     Show this help"
            echo
            echo "Example:"
            echo "  $0              # Install static libhv to /usr/local"
            echo "  $0 --shared     # Install shared libhv"
            echo "  sudo $0         # Install to system directory"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo "=================================="
echo "libhv Installation Script"
echo "=================================="
echo "Version:       $LIBHV_VERSION"
echo "Build Shared:  $BUILD_SHARED_LIBS"
echo "Install Prefix: $INSTALL_PREFIX"
echo "Build Dir:     $BUILD_DIR"
echo "=================================="
echo

# 检查依赖
info "Checking dependencies..."
for cmd in git cmake make gcc g++; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Missing command: $cmd. Install with: sudo apt install build-essential cmake"
    fi
done

# 检查是否已安装
if [ -f "$INSTALL_PREFIX/lib/libhv.a" ] || [ -f "$INSTALL_PREFIX/lib/libhv.so" ]; then
    warn "libhv already installed at $INSTALL_PREFIX"
    read -p "Continue and reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
fi

# 检查是否需要sudo
if [ "$INSTALL_PREFIX" = "/usr/local" ] || [ "$INSTALL_PREFIX" = "/usr" ]; then
    if [ "$EUID" -ne 0 ]; then
        warn "Installing to $INSTALL_PREFIX requires sudo"
        warn "Please run: sudo $0"
        exit 1
    fi
fi

# 清理旧的构建目录
if [ -d "$BUILD_DIR" ]; then
    info "Cleaning old build directory..."
    rm -rf "$BUILD_DIR"
fi

# 克隆仓库
info "Cloning libhv repository..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
git clone --depth 1 --branch "$LIBHV_VERSION" "$LIBHV_REPO" libhv
cd libhv

# 创建构建目录
mkdir -p build
cd build

# 配置CMake
info "Configuring CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS="$BUILD_SHARED_LIBS" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_UNIT_TESTS=OFF

# 编译
info "Building..."
make -j"$(nproc)"

# 安装
info "Installing to $INSTALL_PREFIX..."
make install

# 更新库缓存
if [ -d /etc/ld.so.conf.d ]; then
    echo "$INSTALL_PREFIX/lib" > /etc/ld.so.conf.d/libhv.conf 2>/dev/null || true
    ldconfig
fi

echo
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo "libhv installed to: $INSTALL_PREFIX"
echo
echo "Library files:"
find "$INSTALL_PREFIX/lib" -name "libhv*" 2>/dev/null || true
echo
echo "Header files:"
find "$INSTALL_PREFIX/include" -name "hv" -type d 2>/dev/null || true
echo "=================================="
