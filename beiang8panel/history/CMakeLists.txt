# 历史趋势采样与查询模块库
# HistoryAggregation/HistoryStorage 为纯函数+文件IO,无 DataManager 依赖,可独立单测;
# HistoryRecorder 依赖 DataManager(寄存器缓存读取)
add_library(history_lib STATIC
    HistoryAggregation.cpp
    HistoryStorage.cpp
    HistoryRecorder.cpp
)

target_link_libraries(history_lib
    common_lib
    gateways_lib
    structure_lib
)

target_include_directories(history_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/history
)
