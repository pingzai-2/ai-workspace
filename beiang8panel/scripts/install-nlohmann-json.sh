#!/bin/bash
# nlohmann/json 安装脚本
# nlohmann/json 是一个 header-only 的 JSON 库

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
JSON_REPO="https://github.com/nlohmann/json.git"
JSON_VERSION="${JSON_VERSION:-v3.11.3}"
BUILD_DIR="${BUILD_DIR:-/tmp/nlohmann-json-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            JSON_VERSION="$2"
            shift 2
            ;;
        --prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Install nlohmann/json from GitHub"
            echo
            echo "Options:"
            echo "  --version VER  Specify version (default: v3.11.3)"
            echo "  --prefix PATH  Install prefix (default: /usr/local)"
            echo "  --help, -h     Show this help"
            echo
            echo "Example:"
            echo "  $0                      # Install to /usr/local"
            echo "  sudo $0                # Install with sudo"
            echo "  $0 --prefix /usr      # Install to /usr"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo "=================================="
echo "nlohmann/json Installation Script"
echo "=================================="
echo "Version:       $JSON_VERSION"
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
INCLUDE_DIR="$INSTALL_PREFIX/include/nlohmann"
if [ -f "$INCLUDE_DIR/json.hpp" ]; then
    warn "nlohmann/json already installed at $INCLUDE_DIR"
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
info "Cloning nlohmann/json repository..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
git clone --depth 1 --branch "$JSON_VERSION" "$JSON_REPO" json
cd json

# 创建构建目录
mkdir -p build
cd build

# 配置CMake
info "Configuring CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

# 编译和安装
info "Building and installing..."
make -j"$(nproc)"
make install

echo
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo "nlohmann/json installed to: $INSTALL_PREFIX"
echo
echo "Header file:"
ls -la "$INSTALL_PREFIX/include/nlohmann/json.hpp" 2>/dev/null || true
echo
echo "=================================="
