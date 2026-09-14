/**
 * 串口通信类实现
 */

#include "SerialCommunication.h"
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <spdlog/fmt/ostr.h>
#include <spdlog/spdlog.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

using namespace std;

SerialCommunication::SerialCommunication(const SerialConfig& config)
    : m_config(config)
    , m_isOpen(false)
    , m_fatalError(false)
    , m_fd(-1)
{
}

SerialCommunication::~SerialCommunication()
{
    close();
}

bool SerialCommunication::open()
{
    if (m_isOpen) {
        close();
    }

    // 打开串口设备
    m_fd = ::open(m_config.port.c_str(), O_RDWR | O_NOCTTY | O_NDELAY);
    if (m_fd < 0) {
        m_lastError = "Failed to open serial port: " + m_config.port;
        spdlog::error("[SerialCommunication] {}", m_lastError);
        return false;
    }

#ifdef TIOCEXCL
    // 轻量化独占：同一路端点已被其它进程持有时，本路启动失败，不抢占设备。
    if (ioctl(m_fd, TIOCEXCL) != 0) {
        m_lastError = "Failed to exclusively claim serial port: "
            + m_config.port + ": " + string(strerror(errno));
        spdlog::error("[SerialCommunication] {}", m_lastError);
        ::close(m_fd);
        m_fd = -1;
        return false;
    }
#endif

    // 配置串口参数
    if (!setTermios()) {
        ::close(m_fd);
        m_fd = -1;
        return false;
    }

    m_isOpen = true;
    m_fatalError = false;
    spdlog::info("[SerialCommunication] Opened port: {} at {} baud", m_config.port, m_config.baudRate);
    return true;
}

void SerialCommunication::close()
{
    if (m_isOpen && m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
        m_isOpen = false;
        spdlog::info("[SerialCommunication] Closed port: {}", m_config.port);
    }
}

int SerialCommunication::read(uint8_t* buffer, size_t length)
{
    if (!m_isOpen || m_fd < 0) {
        m_lastError = "Serial port not open";
        return -1;
    }

    int bytesRead = ::read(m_fd, buffer, length);
    if (bytesRead < 0) {
        m_lastError = "Read failed: " + string(strerror(errno));
        if (errno == EIO || errno == ENODEV || errno == ENXIO || errno == EBADF) {
            m_fatalError = true;
        }
        return -1;
    }

    return bytesRead;
}

int SerialCommunication::write(const uint8_t* data, size_t length)
{
    if (!m_isOpen || m_fd < 0) {
        m_lastError = "Serial port not open";
        return -1;
    }

    int bytesWritten = ::write(m_fd, data, length);
    if (bytesWritten < 0) {
        m_lastError = "Write failed: " + string(strerror(errno));
        if (errno == EIO || errno == ENODEV || errno == ENXIO || errno == EBADF) {
            m_fatalError = true;
        }
        return -1;
    }

    // 等待数据发送完成
    tcdrain(m_fd);

    return bytesWritten;
}

bool SerialCommunication::reconfigure(const SerialConfig& config)
{
    bool wasOpen = m_isOpen;
    if (wasOpen) {
        close();
    }

    m_config = config;

    if (wasOpen) {
        return open();
    }

    return true;
}

bool SerialCommunication::setTermios()
{
    struct termios options;

    // 获取当前配置
    if (tcgetattr(m_fd, &options) != 0) {
        m_lastError = "tcgetattr failed";
        return false;
    }

    // 设置波特率
    speed_t speed;
    switch (m_config.baudRate) {
    case 9600:
        speed = B9600;
        break;
    case 19200:
        speed = B19200;
        break;
    case 38400:
        speed = B38400;
        break;
    case 57600:
        speed = B57600;
        break;
    case 115200:
        speed = B115200;
        break;
    default:
        speed = B9600;
        break;
    }

    cfsetispeed(&options, speed);
    cfsetospeed(&options, speed);

    // 设置数据位
    options.c_cflag &= ~CSIZE;
    switch (m_config.dataBits) {
    case 5:
        options.c_cflag |= CS5;
        break;
    case 6:
        options.c_cflag |= CS6;
        break;
    case 7:
        options.c_cflag |= CS7;
        break;
    case 8:
        options.c_cflag |= CS8;
        break;
    default:
        options.c_cflag |= CS8;
        break;
    }

    // 设置停止位
    if (m_config.stopBits == 2) {
        options.c_cflag |= CSTOPB;
    } else {
        options.c_cflag &= ~CSTOPB;
    }

    // 设置校验位
    switch (m_config.parity) {
    case 'O':
        options.c_cflag |= PARENB;
        options.c_cflag |= PARODD;
        break;
    case 'E':
        options.c_cflag |= PARENB;
        options.c_cflag &= ~PARODD;
        break;
    default: // 'N'
        options.c_cflag &= ~PARENB;
        break;
    }

    // 设置为原始模式
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_oflag &= ~OPOST;

    // 启用接收，本地控制
    options.c_cflag |= (CLOCAL | CREAD);

    // 设置硬件流控制
    options.c_cflag &= ~CRTSCTS;

    // 设置软件流控制
    options.c_iflag &= ~(IXON | IXOFF | IXANY);

    // 设置超时和最小字符数
    options.c_cc[VTIME] = m_config.timeoutMs / 100;
    options.c_cc[VMIN] = 0;

    // 应用配置
    if (tcsetattr(m_fd, TCSANOW, &options) != 0) {
        m_lastError = "tcsetattr failed";
        return false;
    }

    // 刷新缓冲区
    tcflush(m_fd, TCIOFLUSH);

    return true;
}
