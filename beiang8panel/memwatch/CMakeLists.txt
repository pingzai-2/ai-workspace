# 内存水位监控模块库
# MemoryWatchPolicy 为纯策略头文件(单测直 include);
# MemoryWatchModule 依赖 DataManager(OTA 状态查询)
add_library(memwatch_lib STATIC
    MemoryWatchModule.cpp
)

target_link_libraries(memwatch_lib
    common_lib
    structure_lib
)

target_include_directories(memwatch_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/memwatch
)
