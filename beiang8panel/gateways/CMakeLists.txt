# 设备网关与通信通道库；进程 1 的 4CP 网关继续使用 libmodbus。
add_library(gateways_lib STATIC
    BeiAng4CPGateway.cpp
    CommunicationChannel.cpp
    CommunicationScheduler.cpp
    ModbusMasterScheduler.cpp
    SerialCommunication.cpp
)

target_link_libraries(gateways_lib
    structure_lib
    common_lib
    modbus
)

target_include_directories(gateways_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/gateways
)
