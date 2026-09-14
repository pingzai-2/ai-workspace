# CMake 本地编译工具链文件
# 用于在 x86_64 Ubuntu 上编译本地程序

# 本地编译不需要设置为交叉编译模式
# CMAKE_SYSTEM_NAME 留空让 CMake 自动检测为 Linux

# 编译器会自动使用系统默认的 gcc/g++
# 不需要显式指定 CMAKE_C_COMPILER 和 CMAKE_CXX_COMPILER

# 可选的编译器优化标志
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=x86-64 -mtune=generic")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=x86-64 -mtune=generic")

# 本地编译不需要设置 sysroot 或查找根路径
# CMake 会自动使用系统的库路径

# 此工具链文件主要用于明确本地编译的配置
# 大多数情况下，CMake 的默认配置已经足够
