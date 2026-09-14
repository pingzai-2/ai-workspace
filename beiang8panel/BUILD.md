# BeiAng8Panel 编译说明

## 编译模式

服务器环境主要使用两种编译模式：

| 模式 | 脚本 | 目标平台 | 说明 |
|------|------|----------|------|
| ARM64交叉编译 | `build-arm64.sh` | ARM64 (aarch64) | 在 R818 SDK 服务器环境中编译并更新 OpenWrt 包目录 |
| Ubuntu本地编译 | `build-native.sh` | x86_64 | 在 Ubuntu 服务器上编译本地版本 |

这两个脚本是原服务器环境的主要入口，继续保留现有用法和目录约定。

---

## Ubuntu 本地编译

### 1. 基础环境

服务器需要预先具备：

```text
build-essential
cmake
file
md5sum
bash
Linux 系统 libcurl 开发库
```

构建脚本不安装软件，也不访问网络。

### 2. 离线依赖

`libmodbus`、`libhv` 和 `nlohmann/json` 已放在工程 `external/` 目录，无需从系统安装或在线下载：

```text
external/libmodbus
external/libhv
external/nlohmann_json
```

`build-native.sh` 会自动调用：

```bash
./scripts/build_offline_deps.sh linux out/build/deps-linux out/deps/linux
```

依赖的构建文件和静态库只保存在 `out/`，不安装到系统目录。

### 3. 编译项目

```bash
# Release模式（默认）
./build-native.sh

# Debug模式
./build-native.sh --debug

# 不启用HTTP服务器
./build-native.sh --no-http

# 清理后重新编译
./build-native.sh --clean

# 显示详细编译输出
./build-native.sh --verbose
```

可在执行前用环境变量覆盖脚本顶部配置：

```bash
BEIANG_BUILD_JOBS=8 ./build-native.sh
BEIANG_BUILD_TESTING=OFF ./build-native.sh
BEIANG_CLEAN=1 ./build-native.sh
```

默认启用调度器测试，构建完成后自动执行 `ctest`。`BEIANG_BUILD_TESTING=OFF` 时跳过测试。

脚本会把 `config/FactoryConfig.json` 中的串口改为 Linux 本地使用的 `/dev/ttyUSB0`。

### 4. 输出

编译完成后，二进制文件位于：

```text
out/Release-native/BeiAng8Panel  (Release模式)
out/Debug-native/BeiAng8Panel    (Debug模式)
```

同目录生成 `MD5SUMS`。

---

## ARM64 交叉编译

`build-arm64.sh` 用于原服务器上的 R818 ARM64 交叉编译。

### 1. SDK 目录

默认把 BeiAng8Panel 工程的父目录作为 R818 SDK 根目录：

```text
R818 SDK/
├── beiang8panel/
├── prebuilt/
├── out/r818-evb1/staging_dir/
└── package/allwinner/beiang8panel/
```

也可以在执行前覆盖：

```bash
BEIANG_R818_SDK=/绝对路径/R818_SDK ./build-arm64.sh
BEIANG_R818_STAGING=/绝对路径/staging_dir ./build-arm64.sh
```

### 2. 编译

```bash
# 基本编译（Release模式，启用HTTP）
./build-arm64.sh

# Debug模式
./build-arm64.sh debug

# 不启用HTTP服务器
./build-arm64.sh nohttp

# 清理
./build-arm64.sh clean

# 重新编译
./build-arm64.sh rebuild
```

脚本会执行以下工作：

1. 检查 R818 工具链和 staging 目录。
2. 把 `config/FactoryConfig.json` 中的串口改为 `/dev/ttyS2`。
3. 从 `external/` 离线构建 ARM64 版 libmodbus 和 libhv。
4. 交叉编译 BeiAng8Panel。
5. 在目标 rootfs 可写时执行安装。
6. 更新 SDK 的 `package/allwinner/beiang8panel/src`。
7. 生成 `out/Release/MD5SUMS` 并显示产物架构。

### 3. 输出

```text
out/Release/BeiAng8Panel
out/Release/MD5SUMS
```

目标 rootfs 可写时，程序同时安装到：

```text
<staging_dir>/target/rootfs/usr/bin/BeiAng8Panel
```

如果 rootfs 由其他用户创建且不可写，脚本会跳过安装，但 `out/Release/BeiAng8Panel` 仍然保留。

---

## CMake 直接编译

当前 CMake 要求传入离线依赖目录 `BEIANG_DEPS_PREFIX`，正常编译优先使用上面的两个脚本。

### 本地编译

```bash
./scripts/build_offline_deps.sh linux out/build/deps-linux out/deps/linux

cmake -S . -B out/build-native \
    -DBUILD_NATIVE=ON \
    -DENABLE_HTTP_SERVER=ON \
    -DBUILD_TESTING=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBEIANG_DEPS_PREFIX="$PWD/out/deps/linux" \
    -DBEIANG_OUTPUT_DIR="$PWD/out/Release-native"

cmake --build out/build-native --parallel
ctest --test-dir out/build-native --output-on-failure
```

### ARM64 交叉编译

ARM64 直接调用 CMake 还需要 R818 工具链、SDK sysroot、staging 和离线依赖环境。应以 `build-arm64.sh` 内的实际参数为准，不单独维护第二套交叉编译命令。

---

## 依赖说明

| 依赖 | 必需/可选 | 来源 | 说明 |
|------|-----------|------|------|
| pthread | 必需 | 系统/SDK | 线程库 |
| libmodbus | 必需 | `external/libmodbus` | 离线静态构建，Modbus RTU通信 |
| nlohmann/json | 必需 | `external/nlohmann_json` | JSON配置和接口数据 |
| spdlog | 必需 | `external/spdlog` | 日志库 |
| rapidjson | 工程保留 | `external/rapidjson` | JSON库 |
| libhv | HTTP启用时必需 | `external/libhv` | 离线静态构建，HTTP事件库 |
| libcurl | HTTP启用时必需 | Linux系统/R818 SDK | HTTP客户端能力 |

`external/` 中的第三方源码是离线构建输入。不要把 `out/` 生成物写回第三方源码目录。

---

## 故障排除

### 缺少离线源码

如果提示找不到 libmodbus、libhv 或 nlohmann/json，检查：

```bash
test -f external/libmodbus/autogen.sh
test -f external/libhv/CMakeLists.txt
test -f external/nlohmann_json/nlohmann/json.hpp
```

从工程归档恢复缺失目录，不在线下载或安装另一份版本。

### 缺少 libcurl

libcurl 使用 Linux 系统或 R818 SDK 已提供的开发库。native 构建缺少时检查系统开发环境；ARM64 构建缺少时检查 staging 中的头文件和库。

### 文本换行错误

构建前会执行：

```bash
./scripts/verify_text_eol.sh
```

`.sh` 必须保持 LF。只修复实际报错文件，不对整个业务源码无差别转换换行。

### 串口权限（运行时）

运行程序可能需要串口设备权限：

```bash
sudo usermod -a -G dialout $USER
# 重新登录后生效
```

### R818 工具链或 staging 不存在

确认 SDK 目录结构正确，或者通过以下变量指定真实位置：

```bash
BEIANG_R818_SDK=/绝对路径/R818_SDK
BEIANG_R818_STAGING=/绝对路径/staging_dir
```

---

## 目录结构

```text
BeiAng8Panel/
├── build-native.sh          # Ubuntu服务器本地编译脚本
├── build-arm64.sh           # R818服务器交叉编译脚本
├── scripts/
│   ├── build_offline_deps.sh # 离线构建libmodbus/libhv
│   └── verify_text_eol.sh    # 换行检查
├── cmake/
│   ├── aarch64-openwrt-linux-gnu.cmake # ARM64工具链
│   └── x86_64-linux-native.cmake       # 本地编译工具链
├── external/
│   ├── libmodbus/            # 内置Modbus源码
│   ├── libhv/                # 内置HTTP源码
│   ├── nlohmann_json/        # 内置JSON头文件
│   ├── spdlog/               # 内置日志库
│   └── rapidjson/            # 内置JSON库
├── out/
│   ├── Release-native/       # Ubuntu Release输出
│   ├── Debug-native/         # Ubuntu Debug输出
│   ├── Release/              # R818输出
│   ├── build/                # 构建临时目录
│   └── deps/                 # 平台隔离的离线依赖
└── CMakeLists.txt            # 主CMake配置
```

---

## 其他平台入口

以下脚本用于工程独立目录下的新平台构建和运行，详细约定以脚本顶部说明为准：

```text
build_macos.sh          / run_macos.sh
build_linux.sh          / run_linux.sh
build_embedded_r528.sh  / run_embedded_r528.sh
build_embedded_r818.sh  / run_embedded_r818.sh
```

它们不改变本说明前面两个服务器脚本的主入口地位。
