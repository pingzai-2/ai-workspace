cmake_minimum_required(VERSION 3.10)

project(modbus_diagnostic CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 添加可执行文件
add_executable(modbus_diagnostic modbus_diagnostic.cpp)

# 链接 libmodbus
target_link_libraries(modbus_diagnostic modbus)

# 安装
install(TARGETS modbus_diagnostic DESTINATION bin)
