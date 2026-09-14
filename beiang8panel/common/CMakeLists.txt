# 通用工具库
add_library(common_lib STATIC
    GlobalFunction.cpp
    FaultCode.cpp
    LogManager.cpp
    Application.cpp
    Configuration.cpp
    ApiResponse.cpp
)

target_include_directories(common_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/common
)

# 根据 HTTP 服务器选项定义宏
if(ENABLE_HTTP_SERVER)
    target_compile_definitions(common_lib PUBLIC ENABLE_HTTP_SERVER=1)
else()
    target_compile_definitions(common_lib PUBLIC ENABLE_HTTP_SERVER=0)
endif()
