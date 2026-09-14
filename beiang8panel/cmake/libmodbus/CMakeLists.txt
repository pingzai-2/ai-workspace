cmake_minimum_required(VERSION 3.10)

project(BeiAngLibmodbus LANGUAGES C)

option(LIBMODBUS_BUILD_SHARED "Build libmodbus as a shared library" OFF)

if(NOT DEFINED LIBMODBUS_SOURCE_DIR)
    message(FATAL_ERROR "LIBMODBUS_SOURCE_DIR is required")
endif()

get_filename_component(LIBMODBUS_SOURCE_DIR "${LIBMODBUS_SOURCE_DIR}" ABSOLUTE)
set(LIBMODBUS_SRC_DIR "${LIBMODBUS_SOURCE_DIR}/src")
if(NOT EXISTS "${LIBMODBUS_SRC_DIR}/modbus.c")
    message(FATAL_ERROR "libmodbus source not found: ${LIBMODBUS_SOURCE_DIR}")
endif()

include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckSymbolExists)

check_include_file("arpa/inet.h" HAVE_ARPA_INET_H)
check_include_file("byteswap.h" HAVE_BYTESWAP_H)
check_include_file("linux/serial.h" HAVE_LINUX_SERIAL_H)
check_include_file("netdb.h" HAVE_NETDB_H)
check_include_file("netinet/in.h" HAVE_NETINET_IN_H)
check_include_file("netinet/ip.h" HAVE_NETINET_IP_H)
check_include_file("netinet/tcp.h" HAVE_NETINET_TCP_H)
check_include_file("sys/ioctl.h" HAVE_SYS_IOCTL_H)
check_include_file("sys/socket.h" HAVE_SYS_SOCKET_H)
check_include_file("termios.h" HAVE_TERMIOS_H)
check_include_file("unistd.h" HAVE_UNISTD_H)

check_function_exists(accept4 HAVE_ACCEPT4)
check_function_exists(gai_strerror HAVE_GAI_STRERROR)
check_function_exists(getaddrinfo HAVE_GETADDRINFO)
check_function_exists(gettimeofday HAVE_GETTIMEOFDAY)
check_function_exists(inet_ntop HAVE_INET_NTOP)
check_function_exists(inet_pton HAVE_INET_PTON)
check_function_exists(select HAVE_SELECT)
check_function_exists(socket HAVE_SOCKET)
check_function_exists(strerror HAVE_STRERROR)
check_function_exists(strlcpy HAVE_STRLCPY)

check_symbol_exists(TIOCM_RTS "sys/ioctl.h" HAVE_DECL_TIOCM_RTS)
if(HAVE_LINUX_SERIAL_H)
    check_symbol_exists(TIOCSRS485 "sys/ioctl.h;linux/serial.h" HAVE_DECL_TIOCSRS485)
else()
    set(HAVE_DECL_TIOCSRS485 0)
endif()

set(LIBMODBUS_VERSION_MAJOR 3)
set(LIBMODBUS_VERSION_MINOR 1)
set(LIBMODBUS_VERSION_MICRO 2)
set(LIBMODBUS_VERSION "3.1.2")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/config.h"
)
configure_file(
    "${LIBMODBUS_SRC_DIR}/modbus-version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/modbus-version.h"
    @ONLY
)

if(LIBMODBUS_BUILD_SHARED)
    set(LIBMODBUS_LIBRARY_TYPE SHARED)
else()
    set(LIBMODBUS_LIBRARY_TYPE STATIC)
endif()

add_library(modbus ${LIBMODBUS_LIBRARY_TYPE}
    "${LIBMODBUS_SRC_DIR}/modbus.c"
    "${LIBMODBUS_SRC_DIR}/modbus-data.c"
    "${LIBMODBUS_SRC_DIR}/modbus-rtu.c"
    "${LIBMODBUS_SRC_DIR}/modbus-tcp.c"
)

set_target_properties(modbus PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
    OUTPUT_NAME modbus
    POSITION_INDEPENDENT_CODE ON
)

if(WIN32)
    # libmodbus 3.1.2 已包含 Win32 串口实现；这里只补 DLL 导出和系统库。
    if(LIBMODBUS_BUILD_SHARED)
        target_compile_definitions(modbus PRIVATE DLLBUILD)
        set_target_properties(modbus PROPERTIES
            PREFIX ""
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
        )
    endif()
    target_compile_definitions(modbus PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(modbus PRIVATE ws2_32)
endif()

target_include_directories(modbus PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${LIBMODBUS_SRC_DIR}"
)

if(HAVE_NETINET_IN_H)
    target_compile_definitions(modbus PRIVATE HAVE_NETINET_IN_H=1)
endif()
if(HAVE_NETINET_IP_H)
    target_compile_definitions(modbus PRIVATE HAVE_NETINET_IP_H=1)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_compile_definitions(modbus PRIVATE _GNU_SOURCE=1)
endif()

if(MSVC)
    target_compile_options(modbus PRIVATE /W0)
else()
    target_compile_options(modbus PRIVATE -w)
endif()

install(TARGETS modbus
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
install(FILES
    "${LIBMODBUS_SRC_DIR}/modbus.h"
    "${LIBMODBUS_SRC_DIR}/modbus-rtu.h"
    "${LIBMODBUS_SRC_DIR}/modbus-tcp.h"
    "${CMAKE_CURRENT_BINARY_DIR}/modbus-version.h"
    DESTINATION include/modbus
)
