cmake_minimum_required(VERSION 3.20)

project(4CP_Simulator
    VERSION 1.0.0
    DESCRIPTION "4CP Protocol Device Simulator"
    LANGUAGES C CXX
)

include(CTest)

# C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 构建类型
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# 编译选项
if(MSVC)
    set(PROJECT_WARNING_OPTIONS /W4 /WX /utf-8)
    set(THIRD_PARTY_WARNING_OPTIONS /W3 /WX-)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
else()
    set(PROJECT_WARNING_OPTIONS -Wall -Wextra -Werror)
    # 第三方源码保持其上游警告语义，不把工具链差异产生的警告升级为错误。
    set(THIRD_PARTY_WARNING_OPTIONS -Wall -Wextra)
endif()

if(NOT WIN32)
    message(FATAL_ERROR "4CP Simulator currently supports Windows only")
endif()

# 与后端共用同一份 libmodbus 3.1.2 构建适配；模拟器需要 DLL。
set(LIBMODBUS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/libmodbus")
set(LIBMODBUS_BUILD_SHARED ON CACHE BOOL "" FORCE)
add_subdirectory(cmake/libmodbus)

# 源文件
set(SOURCES
    src/4CP_Protocol.cpp
    src/DeviceSimulator.cpp
    src/4CP_SimulatorCore.cpp
    src/CommunicationScheduler.cpp
    src/ModbusSlaveScheduler.cpp
    src/ProcessSupervisor.cpp
    src/main.cpp
)

# 头文件
set(HEADERS
    include/4CP_Protocol.h
    include/SerialConfig.h
    include/DeviceSimulator.h
    include/4CP_SimulatorCore.h
    include/CommunicationSchedulerType.h
    include/CommunicationScheduler.h
    include/ModbusSlaveScheduler.h
    include/ProcessSupervisor.h
)

# 可执行文件
add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

# 包含目录
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_libraries(${PROJECT_NAME} PRIVATE modbus)
target_compile_options(${PROJECT_NAME} PRIVATE ${PROJECT_WARNING_OPTIONS})

# 链接库
# 安装
install(TARGETS ${PROJECT_NAME} modbus
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
)

if(BUILD_TESTING)
    add_executable(4CP_ProtocolTests
        tests/DeviceSimulatorTest.cpp
        src/4CP_Protocol.cpp
        src/DeviceSimulator.cpp
        include/4CP_Protocol.h
        include/DeviceSimulator.h
    )
    target_include_directories(4CP_ProtocolTests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    )
    target_compile_options(4CP_ProtocolTests PRIVATE ${PROJECT_WARNING_OPTIONS})
    add_test(NAME 4CP_ProtocolTests COMMAND 4CP_ProtocolTests)

endif()

# 打印配置信息
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
