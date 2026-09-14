# 核心控制模块库
add_library(master_lib STATIC
    DataAcquisitionModule.cpp
    ScheduleController.cpp
)

target_link_libraries(master_lib
    structure_lib
    gateways_lib
    common_lib
)

target_include_directories(master_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/master
)
