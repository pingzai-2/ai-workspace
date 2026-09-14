# CMake 交叉编译工具链文件
# 用于在 x86_64 主机上编译 aarch64 (ARM64) 目标程序

# 关键：必须设置 CMAKE_SYSTEM_NAME 才能启用交叉编译
# 目标实际运行 Linux；这也让 CMake 正确启用 Linux 平台能力。
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 指定交叉编译工具链路径
# 可用环境变量 SDK_DIR 覆盖 (build-arm64.sh 已设置)；否则从工程位置推导。
if(DEFINED ENV{SDK_DIR})
    set(SDK_DIR $ENV{SDK_DIR})
else()
    set(SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/../..")
endif()
get_filename_component(SDK_DIR "${SDK_DIR}" ABSOLUTE)
set(TOOLCHAIN_PATH "${SDK_DIR}/prebuilt/gcc/linux-x86/aarch64/toolchain-sunxi-glibc/toolchain")

# 指定编译器
set(CMAKE_C_COMPILER ${TOOLCHAIN_PATH}/bin/aarch64-openwrt-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PATH}/bin/aarch64-openwrt-linux-gnu-g++)

# 指定 ar, nm, ranlib 等工具
set(CMAKE_AR ${TOOLCHAIN_PATH}/bin/aarch64-openwrt-linux-gnu-gcc-ar)
set(CMAKE_NM ${TOOLCHAIN_PATH}/bin/aarch64-openwrt-linux-gnu-gcc-nm)
set(CMAKE_RANLIB ${TOOLCHAIN_PATH}/bin/aarch64-openwrt-linux-gnu-gcc-ranlib)

# 查找根文件系统
if(DEFINED ENV{STAGING_DIR})
    set(R818_STAGING_DIR "$ENV{STAGING_DIR}")
endif()
set(CMAKE_FIND_ROOT_PATH
    ${TOOLCHAIN_PATH}/aarch64-openwrt-linux-gnu
)
if(DEFINED R818_STAGING_DIR)
    list(APPEND CMAKE_FIND_ROOT_PATH ${R818_STAGING_DIR}/target)
endif()

# 调整搜索路径
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# 设置 sysroot
set(CMAKE_SYSROOT ${TOOLCHAIN_PATH}/aarch64-openwrt-linux-gnu)

# 编译器 flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a -mtune=cortex-a53")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a -mtune=cortex-a53")

# 链接器 flags
# SDK 的 libcurl.so 依赖同一 staging 目录中的 OpenSSL/nghttp2 等动态库。
# -L 只负责查找直接链接库；-rpath-link 让交叉链接器继续解析这些间接依赖。
if(DEFINED R818_STAGING_DIR)
    set(R818_TARGET_LIBRARY_DIR "${R818_STAGING_DIR}/target/usr/lib")
    set(CMAKE_EXE_LINKER_FLAGS
        "${CMAKE_EXE_LINKER_FLAGS} -Wl,-rpath-link,${R818_TARGET_LIBRARY_DIR}")
    set(CMAKE_SHARED_LINKER_FLAGS
        "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-rpath-link,${R818_TARGET_LIBRARY_DIR}")
endif()

# 不尝试编译测试程序（交叉编译时可能无法运行）
set(CMAKE_CXX_COMPILER_WORKS 1)
set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_C_COMPILER_LINKED_WORKS 1)

# 设置 pkg-config
set(ENV{PKG_CONFIG_PATH} ${CMAKE_FIND_ROOT_PATH}/usr/lib/pkgconfig)
set(ENV{PKG_CONFIG_LIBDIR} ${CMAKE_FIND_ROOT_PATH}/usr/lib/pkgconfig)
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_FIND_ROOT_PATH})

if(DEFINED R818_STAGING_DIR)
    set(ENV{STAGING_DIR} "${R818_STAGING_DIR}")
endif()
