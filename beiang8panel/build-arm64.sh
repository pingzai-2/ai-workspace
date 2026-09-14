#!/usr/bin/env bash

# 平台：R818（ARM64）交叉编译；在 Linux x86_64 上执行。
# libmodbus/libhv 从 external 离线静态构建，curl/TLS/zlib 使用 SDK。

# ===== 用户配置区：可在执行前用同名环境变量覆盖 =====
BEIANG_R818_SDK="${BEIANG_R818_SDK:-}"
BEIANG_R818_STAGING="${BEIANG_R818_STAGING:-}"
BEIANG_BUILD_JOBS="${BEIANG_BUILD_JOBS:-}"
BEIANG_CLEAN="${BEIANG_CLEAN:-0}"
# ===== 用户配置区结束；下面是构建逻辑 =====

set -Eeuo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 配置
TOOLCHAIN_FILE="cmake/aarch64-openwrt-linux-gnu.cmake"
BUILD_DIR="out/build"
OUTPUT_DIR="out/Release"
TARGET="BeiAng8Panel"
SDK_DIR="${BEIANG_R818_SDK:-$(cd "$PROJECT_DIR/.." && pwd)}"
STAGING_DIR="${BEIANG_R818_STAGING:-$SDK_DIR/out/r818-evb2/staging_dir}"
TARGET_ROOTFS="$STAGING_DIR/target/rootfs"
DEPS_BUILD_DIR="$PROJECT_DIR/out/build/deps-arm64"
DEPS_PREFIX="$PROJECT_DIR/out/deps/arm64"
# CMake 命令: 优先用系统新版 cmake (>=3.10), 避免撞上 OpenWrt 构建环境自带的老版本 cmake 3.4.3
CMAKE_CMD="${CMAKE_CMD:-/usr/local/bin/cmake}"
[ -x "$CMAKE_CMD" ] || CMAKE_CMD="cmake"

# 显示信息
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

# 将源配置文件中的串口端口设为目标平台端口 (方案B)
# 交叉编译时直接改写 config/FactoryConfig.json 为 /dev/ttyS2
set_serial_port() {
    local target_port="$1"
    local cfg="$PROJECT_DIR/config/FactoryConfig.json"
    if [ -f "$cfg" ]; then
        sed -i "s|\"port\": *\"[^\"]*\"|\"port\": \"$target_port\"|" "$cfg"
        info "串口已设置为: $target_port ($cfg)"
    else
        warn "配置文件不存在: $cfg"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  无参数        基本编译 (Release 模式，默认启用 HTTP 服务器)
  nohttp        禁用 HTTP 服务器
  debug         Debug 模式编译
  clean         清理编译文件
  rebuild       清理并重新编译
  help          显示此帮助信息

示例:
  $0              # 基本编译 (HTTP 服务器默认启用)
  $0 nohttp       # 禁用 HTTP 服务器编译
  $0 rebuild      # 清理后重新编译
EOF
}

# 检查工具链
check_toolchain() {
    local toolchain_path="$SDK_DIR/prebuilt/gcc/linux-x86/aarch64/toolchain-sunxi-glibc/toolchain"
    if [ ! -d "$toolchain_path" ]; then
        error "工具链目录不存在: $toolchain_path"
    fi
    if [ ! -d "$STAGING_DIR" ]; then
        error "staging 目录不存在: $STAGING_DIR"
    fi
    info "工具链检查通过: $toolchain_path"
}

# 构建工程内离线依赖
build_offline_dependencies() {
    local toolchain_bin="$SDK_DIR/prebuilt/gcc/linux-x86/aarch64/toolchain-sunxi-glibc/toolchain/bin"
    local cross_prefix="$toolchain_bin/aarch64-openwrt-linux-gnu"

    export SDK_DIR STAGING_DIR CMAKE_CMD
    export CC="${cross_prefix}-gcc"
    export CXX="${cross_prefix}-g++"
    export AR="${cross_prefix}-ar"
    export RANLIB="${cross_prefix}-ranlib"
    export STRIP="${cross_prefix}-strip"
    export NM="${cross_prefix}-nm"
    export BEIANG_HOST_TRIPLET=aarch64-openwrt-linux-gnu
    export BEIANG_TOOLCHAIN_FILE="$PROJECT_DIR/$TOOLCHAIN_FILE"
    if [ -z "$BEIANG_BUILD_JOBS" ]; then
        BEIANG_BUILD_JOBS="$(nproc)"
    fi
    export BEIANG_BUILD_JOBS BEIANG_CLEAN

    "$PROJECT_DIR/scripts/verify_text_eol.sh"
    "$PROJECT_DIR/scripts/build_offline_deps.sh" arm64 "$DEPS_BUILD_DIR" "$DEPS_PREFIX"
}

# 清理
do_clean() {
    cd "$PROJECT_DIR"
    info "清理编译文件..."
    rm -rf "$BUILD_DIR"
    rm -rf "$PROJECT_DIR/out/deps/arm64"
    rm -rf "$OUTPUT_DIR"/*.a "$OUTPUT_DIR/$TARGET" "$OUTPUT_DIR/MD5SUMS" 2>/dev/null || true
    info "清理完成"
}

# 更新 OpenWrt 包目录
update_openwrt_package() {
    local pkg_dir="$SDK_DIR/package/allwinner/beiang8panel"
    local pkg_src="$pkg_dir/src"
    local src_binary="$OUTPUT_DIR/$TARGET"
    local src_citylist="$PROJECT_DIR/LocationList/China-City-List-latest.csv"

    info "更新 OpenWrt 包目录..."

    # 确保包目录存在
    mkdir -p "$pkg_src"

    # 复制二进制文件
    if [ -f "$src_binary" ]; then
        cp -f "$src_binary" "$pkg_src/"
        info "  ✓ 二进制: $pkg_src/$TARGET"
    else
        warn "  ⚠ 二进制文件不存在: $src_binary"
    fi

    # 四路进程配置分别处理，某一路缺失不影响其它路。
    # 源配置文件已在 do_build 阶段完成目标平台配置，直接复制到 OpenWrt 包源目录。
    if [ -f "$PROJECT_DIR/config/FactoryConfig.json" ]; then
        cp -f "$PROJECT_DIR/config/FactoryConfig.json" "$pkg_src/FactoryConfig.json"
        info "  ✓ 配置: $pkg_src/FactoryConfig.json"
    else
        warn "  ⚠ 配置文件不存在: $PROJECT_DIR/config/FactoryConfig.json"
    fi
    if [ -f "$PROJECT_DIR/config/FactoryConfig_2.json" ]; then
        cp -f "$PROJECT_DIR/config/FactoryConfig_2.json" "$pkg_src/FactoryConfig_2.json"
        info "  ✓ 配置: $pkg_src/FactoryConfig_2.json"
    else
        warn "  ⚠ 配置文件不存在: $PROJECT_DIR/config/FactoryConfig_2.json"
    fi
    if [ -f "$PROJECT_DIR/config/FactoryConfig_3.json" ]; then
        cp -f "$PROJECT_DIR/config/FactoryConfig_3.json" "$pkg_src/FactoryConfig_3.json"
        info "  ✓ 配置: $pkg_src/FactoryConfig_3.json"
    else
        warn "  ⚠ 配置文件不存在: $PROJECT_DIR/config/FactoryConfig_3.json"
    fi
    if [ -f "$PROJECT_DIR/config/FactoryConfig_4.json" ]; then
        cp -f "$PROJECT_DIR/config/FactoryConfig_4.json" "$pkg_src/FactoryConfig_4.json"
        info "  ✓ 配置: $pkg_src/FactoryConfig_4.json"
    else
        warn "  ⚠ 配置文件不存在: $PROJECT_DIR/config/FactoryConfig_4.json"
    fi

    # 复制城市列表文件（如果存在）
    if [ -f "$src_citylist" ]; then
        cp -f "$src_citylist" "$pkg_src/"
        info "  ✓ 城市列表: $pkg_src/China-City-List-latest.csv"
    else
        info "  - 城市列表文件不存在 (可选)"
    fi

    # 确保 init 脚本有执行权限
    if [ -f "$pkg_dir/files/etc/init.d/beiang8panel" ]; then
        chmod +x "$pkg_dir/files/etc/init.d/beiang8panel"
        info "  ✓ init 脚本权限已设置"
    fi

    info "OpenWrt 包目录已更新: $pkg_dir"
}

# 编译
do_build() {
    local build_type="${1:-Release}"
    local enable_http="${2:-OFF}"

    cd "$PROJECT_DIR"
    # 方案B: 构建前将源配置串口改为 arm64 目标 (/dev/ttyS2)
    set_serial_port "/dev/ttyS2"
    info "开始编译..."
    info "  构建类型: $build_type"
    info "  HTTP 服务器: $enable_http"

    build_offline_dependencies

    # 创建构建目录。工程被复制后，旧缓存仍指向原源码目录时必须重新配置。
    mkdir -p "$BUILD_DIR"
    if [ -f "$BUILD_DIR/CMakeCache.txt" ] && \
       ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=$PROJECT_DIR" "$BUILD_DIR/CMakeCache.txt"; then
        warn "检测到其他源码目录生成的 CMake 缓存，重新创建构建目录"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi
    cd "$BUILD_DIR"

    # CMake 配置
    info "CMake 配置 ($CMAKE_CMD)..."
    "$CMAKE_CMD" ../.. \
        -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/$TOOLCHAIN_FILE" \
        -DCMAKE_BUILD_TYPE="$build_type" \
        -DBUILD_NATIVE=OFF \
        -DENABLE_HTTP_SERVER="$enable_http" \
        -DBUILD_TESTING=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
        -DSTAGING_DIR="$STAGING_DIR" \
        -DBEIANG_DEPS_PREFIX="$DEPS_PREFIX" \
        -DBEIANG_OUTPUT_DIR="$PROJECT_DIR/$OUTPUT_DIR" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_DEFAULT_COMPONENT_NAME=BeiAng8Panel

    # 编译
    info "编译中..."
    make -j"$BEIANG_BUILD_JOBS"

    # 安装文件到目标rootfs
    info "安装文件到目标rootfs..."
    if mkdir -p "$TARGET_ROOTFS" 2>/dev/null && [ -w "$TARGET_ROOTFS" ]; then
        make install DESTDIR="$TARGET_ROOTFS"
    else
        warn "目标rootfs不可写(可能由 root 创建): $TARGET_ROOTFS"
        warn "跳过 rootfs 安装。可改用 root 身份运行: sudo ./build-arm64.sh"
        warn "编译产物仍位于: $OUTPUT_DIR/$TARGET"
    fi

    # 显示安装结果
    info "安装完成!"
    echo
    echo -e "${GREEN}安装位置:${NC} $TARGET_ROOTFS"
    echo -e "${GREEN}安装的文件:${NC}"
    find "$TARGET_ROOTFS/usr/bin/BeiAng8Panel" "$TARGET_ROOTFS/usr/share/beiang8panel/China-City-List-latest.csv" 2>/dev/null || echo "  (未找到)"
    echo

    # 返回项目根目录
    cd "$PROJECT_DIR"

    # 生成 MD5 文件清单
    (
        cd "$OUTPUT_DIR"
        md5sum "$TARGET" > MD5SUMS
    )

    # 更新 OpenWrt 包目录
    update_openwrt_package

    # 显示结果
    info "编译完成!"
    if [ -f "$OUTPUT_DIR/$TARGET" ]; then
        echo
        echo -e "${GREEN}========================================${NC}"
        file "$OUTPUT_DIR/$TARGET"
        ls -lh "$OUTPUT_DIR/$TARGET"
        echo -e "${GREEN}========================================${NC}"
    else
        error "编译输出文件不存在: $OUTPUT_DIR/$TARGET"
    fi
}

# 主函数
main() {
    local command="${1:-}"
    local build_type="Release"
    local enable_http="ON"  # 默认启用 HTTP 服务器

    case "$command" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        clean)
            do_clean
            exit 0
            ;;
        rebuild)
            do_clean
            do_build "$build_type" "$enable_http"
            ;;
        nohttp)
            enable_http="OFF"
            do_build "$build_type" "$enable_http"
            ;;
        debug)
            build_type="Debug"
            do_build "$build_type" "$enable_http"
            ;;
        "")
            if [ "$BEIANG_CLEAN" = "1" ]; then
                do_clean
            fi
            do_build "$build_type" "$enable_http"
            ;;
        *)
            error "未知选项: $command (使用 'help' 查看帮助)"
            ;;
    esac
}

# 检查工具链并执行
check_toolchain
main "$@"
