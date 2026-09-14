#pragma once

#include "SerialConfig.h"
#include <string>
#include <vector>
#include <functional>
#include <thread>
#include <mutex>
#include <atomic>

#ifdef _WIN32
#include <windows.h>
#endif

namespace _4CP {

// 串口管理器
class SerialPortManager {
public:
    // 数据接收回调
    using ReceiveCallback = std::function<void(const std::vector<uint8_t>&)>;

    SerialPortManager();
    ~SerialPortManager();

    // 打开串口
    bool Open(const SerialConfig& config);

    // 关闭串口
    void Close();

    // 发送数据
    bool Send(const std::vector<uint8_t>& data);

    // 设置接收回调
    void SetReceiveCallback(ReceiveCallback callback);

    // 检查是否打开
    bool IsOpen() const { return isOpen_; }

    // 获取配置
    const SerialConfig& GetConfig() const { return config_; }

private:
#ifdef _WIN32
    HANDLE handle_;
#endif
    SerialConfig config_;
    std::atomic<bool> isOpen_;
    std::atomic<bool> shouldStop_;

    std::thread receiveThread_;
    std::mutex sendMutex_;
    ReceiveCallback receiveCallback_;

    // 接收线程
    void ReceiveThread();

    // 配置串口
    bool ConfigurePort();

    // 致命 I/O 错误后立即对外呈现为停止，由上层完成关闭。
    void MarkFailed();
};

} // namespace _4CP
