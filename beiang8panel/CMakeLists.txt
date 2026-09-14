cmake_minimum_required(VERSION 3.10)

# 设置 CMP0079 策略为 NEW，允许跨目录链接 target_link_libraries
if(POLICY CMP0079)
    cmake_policy(SET CMP0079 NEW)
endif()

# 交叉编译时设置安装前缀为 /usr（而非 /usr/local）
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    set(CMAKE_INSTALL_PREFIX "/usr" CACHE PATH "Install path prefix" FORCE)
endif()

project(BeiAng8Panel VERSION 1.3.0 LANGUAGES C CXX)

# SDK 中也可能存在同名旧头文件。导入库头文件必须保持普通 -I 语义，
# 才能与本工程离线构建的静态库严格使用同一版本。
set(CMAKE_NO_SYSTEM_FROM_IMPORTED ON)

# 嵌入式正式构建默认不生成测试程序；本机验证时显式传 -DBUILD_TESTING=ON。
option(BUILD_TESTING "Build backend tests" OFF)
include(CTest)

# staging 必须由 build-arm64.sh 从 SDK 当前 out 中解析，不能写死板型目录。
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    if(NOT DEFINED STAGING_DIR)
        message(FATAL_ERROR "STAGING_DIR must be resolved by build-arm64.sh")
    endif()
    set(ENV{STAGING_DIR} "${STAGING_DIR}")
endif()

# 选项：编译平台选择
option(BUILD_NATIVE "Build for native platform (x86_64)" OFF)

# 选项：是否启用 HTTP 服务器（需要 libhv）
option(ENABLE_HTTP_SERVER "Enable HTTP server (requires libhv)" ON)

# 本地编译模式处理
if(BUILD_NATIVE)
    set(CMAKE_CROSSCOMPILING OFF CACHE BOOL "Cross compiling" FORCE)
    set(BEIANG_NATIVE_BUILD TRUE)  # 使 BuildConfig.h 生成 BEIANG_NATIVE_BUILD 宏
    message(STATUS "Building for NATIVE platform (x86_64)")
else()
    message(STATUS "Building for CROSS-COMPILE platform (ARM64)")
endif()

# 选项：日志配置
set(LOG_DIR_DEFAULT "logs")
set(LOG_FILE_NAME_DEFAULT "beiang8panel")
set(LOG_LEVEL_DEFAULT "INFO")
set(LOG_CONSOLE_ENABLED_DEFAULT "ON")
set(LOG_MAX_FILE_SIZE_DEFAULT "10485760")  # 10MB
set(LOG_MAX_FILES_DEFAULT "5")

# 设置 C++ 标准（升级到C++17）
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 设置编译选项
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -pthread")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -O0")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -DNDEBUG")

# 交叉编译时添加额外的编译标志
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
    # 工具链 GCC 6.4.1 的 libstdc++ 无 C++17 <optional> 头,
    # 强制 nlohmann/json 用 C++14 模式(不 include <optional>)以通过编译。
    # 项目源码未使用 C++17 特性, 功能不受影响。
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DJSON_HAS_CPP_14")
endif()

# 输出目录由平台脚本显式隔离；保留旧默认值，兼容手工 cmake。
set(BEIANG_OUTPUT_DIR "" CACHE PATH "BeiAng8Panel artifact output directory")
if(NOT BEIANG_OUTPUT_DIR)
    if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
        set(BEIANG_OUTPUT_DIR ${CMAKE_SOURCE_DIR}/out/${CMAKE_BUILD_TYPE})
    else()
        set(BEIANG_OUTPUT_DIR ${CMAKE_SOURCE_DIR}/out/${CMAKE_BUILD_TYPE}-native)
    endif()
endif()
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${BEIANG_OUTPUT_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${BEIANG_OUTPUT_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${BEIANG_OUTPUT_DIR})

# libmodbus/libhv 固定从 external 离线构建后的平台前缀导入。
# 不允许构建过程悄悄拾取另一平台或 /usr/local 中的同名库。
set(BEIANG_DEPS_PREFIX "" CACHE PATH "Offline libmodbus/libhv install prefix")
if(NOT BEIANG_DEPS_PREFIX)
    message(FATAL_ERROR "BEIANG_DEPS_PREFIX is required; use a platform build script")
endif()

set(BEIANG_MODBUS_LIBRARY "${BEIANG_DEPS_PREFIX}/lib/libmodbus.a")
set(BEIANG_HV_LIBRARY "${BEIANG_DEPS_PREFIX}/lib/libhv_static.a")
if(NOT EXISTS "${BEIANG_MODBUS_LIBRARY}")
    message(FATAL_ERROR "Offline libmodbus not found: ${BEIANG_MODBUS_LIBRARY}")
endif()
if(ENABLE_HTTP_SERVER AND NOT EXISTS "${BEIANG_HV_LIBRARY}")
    message(FATAL_ERROR "Offline libhv not found: ${BEIANG_HV_LIBRARY}")
endif()

add_library(modbus STATIC IMPORTED GLOBAL)
set_target_properties(modbus PROPERTIES
    IMPORTED_LOCATION "${BEIANG_MODBUS_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${BEIANG_DEPS_PREFIX}/include"
)

if(ENABLE_HTTP_SERVER)
    add_library(hv STATIC IMPORTED GLOBAL)
    set_target_properties(hv PROPERTIES
        IMPORTED_LOCATION "${BEIANG_HV_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${BEIANG_DEPS_PREFIX}/include"
        INTERFACE_COMPILE_DEFINITIONS HV_STATICLIB
    )
endif()

# ============================================================================
# spdlog 依赖配置
# ============================================================================
# 尝试使用 find_package 查找系统已安装的 spdlog
find_package(spdlog QUIET)

# 如果未找到，使用项目中的 spdlog
if(NOT spdlog_FOUND)
    # 使用项目中的本地 spdlog（位于 external/spdlog）
    set(SPDLOG_DIR "${CMAKE_SOURCE_DIR}/external/spdlog")

    if(EXISTS "${SPDLOG_DIR}/CMakeLists.txt")
        # 使用 spdlog 的 CMake 构建系统（会自动处理 fmt 依赖）
        set(SPDLOG_BUILD_SHARED OFF CACHE BOOL "Build spdlog as shared library" FORCE)
        set(SPDLOG_BUILD_EXAMPLE OFF CACHE BOOL "Build spdlog examples" FORCE)
        set(SPDLOG_BUILD_TESTS OFF CACHE BOOL "Build spdlog tests" FORCE)
        set(SPDLOG_BUILD_BENCH OFF CACHE BOOL "Build spdlog benchmarks" FORCE)
        set(SPDLOG_FMT_EXTERNAL OFF CACHE BOOL "Use external fmt library" FORCE)
        add_subdirectory("${SPDLOG_DIR}" "${CMAKE_BINARY_DIR}/spdlog")
        message(STATUS "Using local spdlog from: ${SPDLOG_DIR}")
    elseif(EXISTS "${SPDLOG_DIR}/include/spdlog")
        # 回退方案：如果只有头文件，创建 INTERFACE 库（需要外部 fmt）
        include_directories("${SPDLOG_DIR}/include")
        add_library(spdlog INTERFACE)
        target_include_directories(spdlog INTERFACE "${SPDLOG_DIR}/include")
        message(WARNING "spdlog CMakeLists.txt not found, using header-only mode (requires external fmt)")
    else()
        message(FATAL_ERROR "spdlog not found in system or external directory")
    endif()
endif()

# 包含目录
include_directories(
    ${CMAKE_SOURCE_DIR}
    ${BEIANG_DEPS_PREFIX}/include
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/common
    ${CMAKE_SOURCE_DIR}/structure
    ${CMAKE_SOURCE_DIR}/gateways
    ${CMAKE_SOURCE_DIR}/master
    ${CMAKE_SOURCE_DIR}/uiservice
    ${CMAKE_BINARY_DIR} # 用于生成的BuildConfig.h
)

# ============================================================================
# 生成BuildConfig.h
# ============================================================================
configure_file(
    "${CMAKE_SOURCE_DIR}/common/BuildConfig.h.in"
    "${CMAKE_BINARY_DIR}/BuildConfig.h"
)

# 交叉编译时添加平台 SDK 的系统库包含目录
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    include_directories(${STAGING_DIR}/target/usr/include)
endif()

# nlohmann/json（header-only 库）
set(NLOHMANN_JSON_DIR "${CMAKE_SOURCE_DIR}/external/nlohmann_json")
if(EXISTS "${NLOHMANN_JSON_DIR}/nlohmann/json.hpp")
    include_directories(${NLOHMANN_JSON_DIR})
    message(STATUS "Using nlohmann/json from: ${NLOHMANN_JSON_DIR}")
else()
    message(FATAL_ERROR "nlohmann/json not found at ${NLOHMANN_JSON_DIR}")
endif()

# 链接目录
link_directories(
    ${CMAKE_SOURCE_DIR}/lib
)

# 交叉编译时添加 OpenWrt staging 库路径
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    # 编译时链接 staging_dir 中的库
    link_directories(${STAGING_DIR}/target/usr/lib)
endif()

# 添加子目录
add_subdirectory(common)
add_subdirectory(structure)
add_subdirectory(gateways)
add_subdirectory(master)
add_subdirectory(history)
add_subdirectory(memwatch)
add_subdirectory(uiservice)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# HTTP 服务器（可选）
if(ENABLE_HTTP_SERVER)
    add_subdirectory(httpserver)
    set(HTTP_SERVER_LIB httpserver_lib)
else()
    set(HTTP_SERVER_LIB "")
endif()

# ============================================================================
# 链接 spdlog 到所有需要它的子库
# ============================================================================
# spdlog 必须在这些库定义之后链接，以便正确传递头文件路径
if(TARGET spdlog::spdlog)
    target_link_libraries(common_lib PUBLIC spdlog::spdlog)
elseif(TARGET spdlog)
    target_link_libraries(common_lib PUBLIC spdlog)
endif()

# 创建可执行文件
add_executable(${PROJECT_NAME}
    main.cpp
    ProcessSupervisor.cpp
    DataManager.cpp
    modbuscommand/ModbusCommandModule.cpp
    localdevice/LocalDeviceModule.cpp
    localdevice/WifiManager.cpp
    localdevice/OtaManager.cpp
)

# ============================================================================
# emc6069 模组库（WiFi 与 MCU OTA 的串口传输层）
# 交叉构建链接 SDK staging 的 libemc6069.so（emc6069-wifi 包 InstallDev 安装）；
# 原生调试构建编译 external/emc6069-stub 桩（全部返回失败，功能按不可用运行）。
# ============================================================================
if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
    if(NOT EXISTS "${STAGING_DIR}/target/usr/lib/libemc6069.so")
        message(FATAL_ERROR
            "libemc6069.so not found in staging; build the emc6069-wifi package first")
    endif()
    # 旧版 emc6069-wifi 包没有 OTA API，staging 未更新时给出明确指引
    file(READ "${STAGING_DIR}/target/usr/include/emc6069.h" BEIANG_EMCO6069_HEADER)
    if(NOT BEIANG_EMCO6069_HEADER MATCHES "emc6069_ota_confirm_update")
        message(FATAL_ERROR
            "staged emc6069.h lacks OTA API; rebuild the emc6069-wifi package first")
    endif()
    include_directories(${STAGING_DIR}/target/usr/include)
    set(BEIANG_EMCO6069_SOURCES "")
    set(BEIANG_EMCO6069_LIBRARY emc6069)
else()
    include_directories(${CMAKE_SOURCE_DIR}/external/emc6069-stub)
    set(BEIANG_EMCO6069_SOURCES external/emc6069-stub/emc6069_stub.c)
    set(BEIANG_EMCO6069_LIBRARY "")
endif()

target_sources(${PROJECT_NAME} PRIVATE ${BEIANG_EMCO6069_SOURCES})

# 定义编译宏
if(ENABLE_HTTP_SERVER)
    target_compile_definitions(${PROJECT_NAME} PRIVATE ENABLE_HTTP_SERVER=1)
else()
    target_compile_definitions(${PROJECT_NAME} PRIVATE ENABLE_HTTP_SERVER=0)
endif()

# 链接库
target_link_libraries(${PROJECT_NAME}
    common_lib
    structure_lib
    gateways_lib
    master_lib
    ${HTTP_SERVER_LIB}
    uiservice_lib
    history_lib
    memwatch_lib
    pthread
)

# 链接 spdlog
# 优先使用 spdlog::spdlog（编译为静态库，包含 bundled fmt）
if(TARGET spdlog::spdlog)
    target_link_libraries(${PROJECT_NAME} spdlog::spdlog)
elseif(TARGET spdlog)
    target_link_libraries(${PROJECT_NAME} spdlog)
elseif(TARGET spdlog::spdlog_header_only)
    target_link_libraries(${PROJECT_NAME} spdlog::spdlog_header_only)
endif()

# 链接 libmodbus（Modbus RTU 通信必需）
target_link_libraries(${PROJECT_NAME} modbus)

# 链接 emc6069 模组库（WiFi/OTA 串口传输层，原生构建为桩实现，无需链接）
if(BEIANG_EMCO6069_LIBRARY)
    target_link_libraries(${PROJECT_NAME} ${BEIANG_EMCO6069_LIBRARY})
endif()

# HTTP 业务直接使用 libcurl/iconv。curl/TLS/zlib 属于平台或 SDK 能力，
# 不随工程重复打包；libhv 本身固定使用上面的 external 静态库。
if(ENABLE_HTTP_SERVER)
    if(CMAKE_CROSSCOMPILING AND NOT BUILD_NATIVE)
        find_library(BEIANG_CURL_LIBRARY NAMES curl
            PATHS "${STAGING_DIR}/target/usr/lib"
            NO_DEFAULT_PATH REQUIRED)
        target_link_libraries(${PROJECT_NAME} hv "${BEIANG_CURL_LIBRARY}")
    elseif(APPLE)
        # Apple SDK 自带 libcurl 和 iconv。
        find_library(BEIANG_SECURITY_FRAMEWORK Security REQUIRED)
        find_library(BEIANG_COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
        target_link_libraries(${PROJECT_NAME}
            hv
            curl
            iconv
            "${BEIANG_SECURITY_FRAMEWORK}"
            "${BEIANG_COREFOUNDATION_FRAMEWORK}"
        )
    else()
        find_package(CURL REQUIRED)
        target_link_libraries(${PROJECT_NAME} hv CURL::libcurl)
    endif()
endif()

# 链接 gateways_lib 需要的 modbus
# gateways_lib 已经链接了 modbus，这里确保传递依赖正确

# 安装规则
install(TARGETS ${PROJECT_NAME} DESTINATION bin)

# 安装城市列表文件到rootfs（注意：CMAKE_INSTALL_PREFIX=/usr，所以路径相对于 /usr）
if(EXISTS "${CMAKE_SOURCE_DIR}/LocationList/China-City-List-latest.csv")
    install(FILES ${CMAKE_SOURCE_DIR}/LocationList/China-City-List-latest.csv
            DESTINATION share/beiang8panel)
endif()

# 安装配置文件到rootfs
# 优先安装到 /etc/beiang8panel/（系统配置目录）
# 构建不改写源配置；运行脚本可通过 BEIANG_CONFIG 指定平台配置。
install(FILES
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_2.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_3.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_4.json
        DESTINATION etc/beiang8panel)

# 备用安装路径：/usr/share/beiang8panel/config/
install(FILES
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_2.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_3.json
        ${CMAKE_SOURCE_DIR}/config/FactoryConfig_4.json
        DESTINATION share/beiang8panel/config)

# 打印配置信息
message(STATUS "BeiAng8Panel Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Cross-Compiling: ${CMAKE_CROSSCOMPILING}")
message(STATUS "  System: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "  C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "  CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "  HTTP Server: ${ENABLE_HTTP_SERVER}")
if(TARGET spdlog::spdlog)
    message(STATUS "  spdlog: Local static library with bundled fmt from ${SPDLOG_DIR}")
elseif(TARGET spdlog)
    message(STATUS "  spdlog: Local (INTERFACE) from ${SPDLOG_DIR}")
elseif(spdlog_FOUND)
    message(STATUS "  spdlog: ${spdlog_VERSION} (system)")
else()
    message(STATUS "  spdlog: Not found!")
endif()
