#!/bin/bash
# nghttp2 安装脚本
# nghttp2 是 HTTP/2 库，libhv 依赖它

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
NGHTTP2_REPO="https://github.com/nghttp2/nghttp2.git"
NGHTTP2_VERSION="${NGHTTP2_VERSION:-v1.58.0}"
BUILD_DIR="${BUILD_DIR:-/tmp/nghttp2-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            NGHTTP2_VERSION="$2"
            shift 2
            ;;
        --prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --enable-lib-only)
            ENABLE_LIB_ONLY="--enable-lib-only"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Install nghttp2 from GitHub"
            echo
            echo "Options:"
            echo "  --version VER         Specify version (default: v1.58.0)"
            echo "  --prefix PATH         Install prefix (default: /usr/local)"
            echo "  --enable-lib-only     Only build library, not tools"
            echo "  --help, -h            Show this help"
            echo
            echo "Example:"
            echo "  $0                           # Install full version"
            echo "  sudo $0                     # Install with sudo"
            echo "  $0 --enable-lib-only        # Install library only"
            echo "  $0 --prefix /usr            # Install to /usr"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo "=================================="
echo "nghttp2 Installation Script"
echo "=================================="
echo "Version:       $NGHTTP2_VERSION"
echo "Install Prefix: $INSTALL_PREFIX"
echo "Build Dir:     $BUILD_DIR"
echo "Lib Only:      ${ENABLE_LIB_ONLY:-no}"
echo "=================================="
echo

# 检查依赖
info "Checking dependencies..."

# 检查基础构建工具
for cmd in git automake autoconf libtool; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Missing command: $cmd. Install with: sudo apt install autoconf automake libtool"
    fi
done

for cmd in cmake make gcc g++; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Missing command: $cmd. Install with: sudo apt install build-essential cmake"
    fi
done

# 检查依赖库
info "Checking required libraries..."
for lib in libssl-dev zlib1g-dev libev-dev; do
    if ! dpkg -l | grep -q "^ii  $lib"; then
        warn "Missing library: $lib"
        echo "Install with: sudo apt install $lib"
    fi
done

# 检查是否已安装
if [ -f "$INSTALL_PREFIX/lib/libnghttp2.a" ] || [ -f "$INSTALL_PREFIX/lib/libnghttp2.so" ]; then
    warn "nghttp2 already installed at $INSTALL_PREFIX"
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
info "Cloning nghttp2 repository..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
git clone --depth 1 --branch "$NGHTTP2_VERSION" "$NGHTTP2_REPO" nghttp2
cd nghttp2

# 使用 autogen.sh 生成配置脚本
info "Generating build configuration..."
if [ -f "autogen.sh" ]; then
    ./autogen.sh
else
    autoreconf -i
fi

# 配置
info "Configuring build..."
./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-static \
    --disable-shared \
    ${ENABLE_LIB_ONLY:-} \
    --disable-python-bindings \
    --disable-examples

# 编译
info "Building..."
make -j"$(nproc)"

# 安装
info "Installing..."
make install

# 更新库缓存
if [ -d /etc/ld.so.conf.d ]; then
    echo "$INSTALL_PREFIX/lib" > /etc/ld.so.conf.d/nghttp2.conf 2>/dev/null || true
    ldconfig
fi

echo
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo "nghttp2 installed to: $INSTALL_PREFIX"
echo
echo "Library files:"
find "$INSTALL_PREFIX/lib" -name "libnghttp2*" 2>/dev/null || true
echo
echo "=================================="
