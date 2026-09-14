add_executable(modbus_master_scheduler_test
    ModbusMasterSchedulerTest.cpp
    ${CMAKE_SOURCE_DIR}/gateways/ModbusMasterScheduler.cpp
)

target_include_directories(modbus_master_scheduler_test PRIVATE
    ${CMAKE_SOURCE_DIR}/gateways
)

target_link_libraries(modbus_master_scheduler_test pthread)

add_test(NAME modbus_master_scheduler_test COMMAND modbus_master_scheduler_test)

add_executable(modbus_snapshot_parser_test
    ModbusSnapshotParserTest.cpp
)

target_link_libraries(modbus_snapshot_parser_test
    gateways_lib
    structure_lib
    common_lib
    modbus
    pthread
)

add_test(NAME modbus_snapshot_parser_test COMMAND modbus_snapshot_parser_test)

add_executable(modbus_command_policy_test
    ModbusCommandPolicyTest.cpp
)

target_include_directories(modbus_command_policy_test PRIVATE
    ${CMAKE_SOURCE_DIR}
)

add_test(NAME modbus_command_policy_test COMMAND modbus_command_policy_test)

add_executable(modbus_freshness_tracker_test
    ModbusFreshnessTrackerTest.cpp
)

target_include_directories(modbus_freshness_tracker_test PRIVATE
    ${CMAKE_SOURCE_DIR}
)

add_test(NAME modbus_freshness_tracker_test COMMAND modbus_freshness_tracker_test)

add_executable(history_aggregation_test
    HistoryAggregationTest.cpp
    ${CMAKE_SOURCE_DIR}/history/HistoryAggregation.cpp
    ${CMAKE_SOURCE_DIR}/history/HistoryStorage.cpp
)

target_include_directories(history_aggregation_test PRIVATE
    ${CMAKE_SOURCE_DIR}
)

target_link_libraries(history_aggregation_test pthread)

add_test(NAME history_aggregation_test COMMAND history_aggregation_test)

add_executable(memory_watch_policy_test
    MemoryWatchPolicyTest.cpp
)

target_include_directories(memory_watch_policy_test PRIVATE
    ${CMAKE_SOURCE_DIR}
)

add_test(NAME memory_watch_policy_test COMMAND memory_watch_policy_test)
