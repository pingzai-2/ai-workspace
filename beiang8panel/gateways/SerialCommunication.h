/**
 * 串口通信类
 *
 * 封装串口通信操作
 */

#ifndef SERIALCOMMUNICATION_H
#define SERIALCOMMUNICATION_H

#include "common/GlobalDefine.h"
#include <memory>
#include <string>
#include <vector>

// 串口配置结构
struct SerialConfig {
    std::string port; // 串口设备路径
    int baudRate; // 波特率
    int dataBits; // 数据位
    int stopBits; // 停止位
    char parity; // 校验位 (N:none, O:odd, E:even)
    int timeoutMs; // 超时时间(毫秒)

    SerialConfig()
        : port(DEFAULT_SERIAL_PORT)
        , baudRate(DEFAULT_SERIAL_BAUDRATE)
        , dataBits(DEFAULT_SERIAL_DATABITS)
        , stopBits(DEFAULT_SERIAL_STOPBITS)
        , parity(DEFAULT_SERIAL_PARITY)
        , timeoutMs(MODBUS_RESPONSE_TIMEOUT_MS)
    {
    }
};

// 串口通信类
class SerialCommunication {
public:
    explicit SerialCommunication(const SerialConfig& config);
    ~SerialCommunication();

    // 打开/关闭串口
    bool open();
    void close();
    bool isOpen() const { return m_isOpen; }

    // 读写数据
    int read(uint8_t* buffer, size_t length);
    int write(const uint8_t* data, size_t length);

    // 配置
    const SerialConfig& getConfig() const { return m_config; }
    bool reconfigure(const SerialConfig& config);

    // 状态
    std::string getLastError() const { return m_lastError; }
    bool hasFatalError() const { return m_fatalError; }

private:
    SerialConfig m_config;
    bool m_isOpen;
    bool m_fatalError;
    int m_fd; // 文件描述符
    std::string m_lastError;

    // 设置串口参数
    bool setTermios();
};

#endif // SERIALCOMMUNICATION_H
