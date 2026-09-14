# 数据结构库
add_library(structure_lib STATIC
    GatewayGeneralDataStructure.cpp
    ManualModeDataStructure.cpp
    SmartModeDataStructure.cpp
    SystemSettingsDataStructure.cpp
    EnvironmentDataStructure.cpp
)

target_include_directories(structure_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/structure
)
