# HTTP服务器库
add_library(httpserver_lib STATIC
    HttpServerBasedOnLibhv.cpp
)

# 添加编译定义
target_compile_definitions(httpserver_lib PRIVATE
    HV_STATICLIB
)

# libhv 头文件由导入目标 hv 的 INTERFACE_INCLUDE_DIRECTORIES 传递。
target_include_directories(httpserver_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/httpserver
)

# 链接依赖库
target_link_libraries(httpserver_lib
    structure_lib
    gateways_lib
    master_lib
    common_lib
    hv
)
