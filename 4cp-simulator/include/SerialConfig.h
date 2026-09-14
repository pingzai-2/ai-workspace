#pragma once

#include <cstdint>
#include <string>

namespace _4CP {

// 一路通信进程使用的串口配置。
struct SerialConfig {
    std::string port;
    uint32_t baudrate;
    uint8_t databits;
    uint8_t stopbits;
    uint8_t parity; // 0: N, 1: O, 2: E

    SerialConfig(
        const std::string& p = "COM1",
        uint32_t br = 115200,
        uint8_t db = 8,
        uint8_t sb = 1,
        uint8_t par = 0)
        : port(p)
        , baudrate(br)
        , databits(db)
        , stopbits(sb)
        , parity(par) {
    }
};

} // namespace _4CP
