# UI业务逻辑库
add_library(uiservice_lib STATIC
    BasePage.cpp
    HomePage.cpp
    ManualModePage.cpp
    SmartModePage.cpp
    IdlePage.cpp
    SystemSettingsPage.cpp
    DeviceMaintenancePage.cpp
    EngineeringModePage.cpp
    HistoryTrendPage.cpp
)

target_link_libraries(uiservice_lib
    structure_lib
    common_lib
)

target_include_directories(uiservice_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/uiservice
)
