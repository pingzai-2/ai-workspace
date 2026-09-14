#include "SerialPortManager.h"
#include "Logger.h"
#include <iostream>
#include <chrono>

namespace _4CP {

SerialPortManager::SerialPortManager()
    : handle_(INVALID_HANDLE_VALUE)
    , isOpen_(false)
    , shouldStop_(false)
{
}

SerialPortManager::~SerialPortManager() {
    Close();
}

bool SerialPortManager::Open(const SerialConfig& config) {
    config_ = config;

#ifdef _WIN32
    // 打开串口
    std::string portPath = "\\\\.\\" + config.port;
    handle_ = CreateFileA(
        portPath.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,  // 使用重叠I/O支持取消操作
        nullptr
    );

    if (handle_ == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        std::cerr << "Failed to open serial port " << config.port
                  << ". Error: " << err << std::endl;
        return false;
    }

    // 配置串口参数
    if (!ConfigurePort()) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
        return false;
    }

    // 清空缓冲区并清除所有错误
    PurgeComm(handle_, PURGE_RXCLEAR | PURGE_TXCLEAR);
    ClearCommError(handle_, nullptr, nullptr);

    isOpen_ = true;
    shouldStop_ = false;

    // 启动接收线程
    receiveThread_ = std::thread(&SerialPortManager::ReceiveThread, this);

    LOG("Serial port " << config.port << " opened at "
              << config.baudrate << " baud");

    return true;
#else
    // Linux实现
    return false;
#endif
}

void SerialPortManager::Close() {
    // 先设置停止标志
    shouldStop_ = true;
    isOpen_ = false;

#ifdef _WIN32
    // 取消所有待处理的I/O操作
    if (handle_ != INVALID_HANDLE_VALUE) {
        CancelIoEx(handle_, nullptr);
        PurgeComm(handle_, PURGE_RXABORT | PURGE_TXABORT | PURGE_RXCLEAR | PURGE_TXCLEAR);
    }
#endif

    // 等待接收线程结束（有超时保护）
    // 由于 CancelIoEx，线程应该能快速退出
    if (receiveThread_.joinable()) {
        receiveThread_.join();
    }

#ifdef _WIN32
    if (handle_ != INVALID_HANDLE_VALUE) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
    }
#endif

    LOG("Serial port closed");
}

bool SerialPortManager::Send(const std::vector<uint8_t>& data) {
    if (!isOpen_ || data.empty()) {
        return false;
    }

    std::lock_guard<std::mutex> lock(sendMutex_);

#ifdef _WIN32
    DWORD bytesWritten = 0;
    OVERLAPPED overlapped = {};
    overlapped.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);

    if (overlapped.hEvent == nullptr) {
        LOG("[ERROR] Failed to create event for overlapped write");
        MarkFailed();
        return false;
    }

    BOOL result = WriteFile(
        handle_,
        data.data(),
        static_cast<DWORD>(data.size()),
        &bytesWritten,
        &overlapped
    );

    if (!result) {
        DWORD err = GetLastError();
        if (err == ERROR_IO_PENDING) {
            // 等待操作完成
            DWORD waitResult = WaitForSingleObject(overlapped.hEvent, 1000); // 1秒超时
            if (waitResult == WAIT_OBJECT_0) {
                if (!GetOverlappedResult(handle_, &overlapped, &bytesWritten, FALSE)) {
                    CloseHandle(overlapped.hEvent);
                    MarkFailed();
                    return false;
                }
            } else {
                // 超时或失败，取消操作
                CancelIoEx(handle_, &overlapped);
                CloseHandle(overlapped.hEvent);
                LOG("[ERROR] Write timeout or failed");
                MarkFailed();
                return false;
            }
        } else {
            CloseHandle(overlapped.hEvent);
            LOG("[ERROR] WriteFile failed: " << err);
            MarkFailed();
            return false;
        }
    }

    CloseHandle(overlapped.hEvent);

    if (bytesWritten != data.size()) {
        LOG("[ERROR] Partial write: " << bytesWritten << "/" << data.size());
        MarkFailed();
        return false;
    }

    return true;
#else
    return false;
#endif
}

void SerialPortManager::SetReceiveCallback(ReceiveCallback callback) {
    receiveCallback_ = callback;
}

void SerialPortManager::MarkFailed() {
    shouldStop_ = true;
    isOpen_ = false;
}

void SerialPortManager::ReceiveThread() {
    std::vector<uint8_t> buffer(1024);
    const int readTimeout = 100; // ms
    int consecutiveErrors = 0;
    const int maxConsecutiveErrors = 10;

    // 创建重叠I/O事件
#ifdef _WIN32
    OVERLAPPED overlapped = {};
    overlapped.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    if (overlapped.hEvent == nullptr) {
        LOG("[ERROR] Failed to create event for overlapped read");
        MarkFailed();
        return;
    }
    HANDLE hEvent = overlapped.hEvent;  // 保存句柄用于清理
#endif

    while (!shouldStop_ && isOpen_) {
#ifdef _WIN32
        // 重置事件
        ResetEvent(overlapped.hEvent);

        DWORD bytesRead = 0;
        DWORD errors = 0;
        COMSTAT stat = {};

        // 检查串口状态和可用字节数
        if (!ClearCommError(handle_, &errors, &stat)) {
            DWORD err = GetLastError();
            if (++consecutiveErrors >= maxConsecutiveErrors) {
                LOG("[ERROR] ClearCommError failed repeatedly: " << err
                         << ", closing port");
                MarkFailed();
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(readTimeout));
            continue;
        }

        // 如果有数据可用或正常读取
        BOOL result = ReadFile(
            handle_,
            buffer.data(),
            static_cast<DWORD>(buffer.size()),
            &bytesRead,
            &overlapped
        );

        if (result) {
            // 同步完成（立即有数据）
            consecutiveErrors = 0;
            if (bytesRead > 0) {
                std::vector<uint8_t> receivedData(buffer.begin(), buffer.begin() + bytesRead);
                if (receiveCallback_) {
                    receiveCallback_(receivedData);
                }
            }
        } else {
            DWORD err = GetLastError();

            if (err == ERROR_IO_PENDING) {
                // 等待异步操作完成
                DWORD waitResult = WaitForSingleObject(overlapped.hEvent, readTimeout);

                if (waitResult == WAIT_OBJECT_0) {
                    // 操作完成，获取结果
                    if (GetOverlappedResult(handle_, &overlapped, &bytesRead, FALSE)) {
                        consecutiveErrors = 0;
                        if (bytesRead > 0) {
                            std::vector<uint8_t> receivedData(buffer.begin(), buffer.begin() + bytesRead);
                            if (receiveCallback_) {
                                receiveCallback_(receivedData);
                            }
                        }
                    } else {
                        err = GetLastError();
                        // 操作被取消（995）是正常情况
                        if (err != ERROR_OPERATION_ABORTED && shouldStop_) {
                            // 正在关闭，忽略
                            break;
                        }
                        if (++consecutiveErrors >= maxConsecutiveErrors) {
                            LOG("[ERROR] GetOverlappedResult failed repeatedly: "
                                << err << ", closing port");
                            MarkFailed();
                            break;
                        }
                    }
                } else if (waitResult == WAIT_TIMEOUT) {
                    // 超时是正常情况，继续
                    consecutiveErrors = 0;
                } else {
                    // 其他错误
                    if (++consecutiveErrors >= maxConsecutiveErrors) {
                        LOG("[ERROR] Serial read wait failed repeatedly, closing port");
                        MarkFailed();
                        break;
                    }
                }
            } else if (err == ERROR_OPERATION_ABORTED) {
                // I/O被取消，正常退出
                LOG("[DBG] Read operation cancelled");
                break;
            } else {
                // 其他错误
                if (++consecutiveErrors >= maxConsecutiveErrors) {
                    LOG("[ERROR] ReadFile failed repeatedly: " << err
                             << ", BytesInQueue=" << stat.cbInQue
                             << ", closing port");
                    MarkFailed();
                    break;
                }
                // 偶尔错误，继续尝试
                if (consecutiveErrors < 5) {
                    // 减少日志频率
                    LOG("[DBG] ReadFile failed: " << err
                              << ", BytesInQueue=" << stat.cbInQue);
                }
            }
        }

        // 短暂休眠避免CPU占用过高
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
#else
        std::this_thread::sleep_for(std::chrono::milliseconds(readTimeout));
#endif
    }

#ifdef _WIN32
    if (hEvent != nullptr) {
        CloseHandle(hEvent);
    }
#endif

    LOG("[DBG] Receive thread exiting");
}

bool SerialPortManager::ConfigurePort() {
#ifdef _WIN32
    DCB dcb = {};
    dcb.DCBlength = sizeof(DCB);

    // 获取当前配置
    if (!GetCommState(handle_, &dcb)) {
        std::cerr << "Failed to get comm state" << std::endl;
        return false;
    }

    // 设置参数
    dcb.BaudRate = config_.baudrate;
    dcb.ByteSize = config_.databits;
    dcb.StopBits = (config_.stopbits == 1) ? ONESTOPBIT :
                   (config_.stopbits == 2) ? TWOSTOPBITS : ONE5STOPBITS;
    dcb.Parity = (config_.parity == 0) ? NOPARITY :
                 (config_.parity == 1) ? ODDPARITY :
                 (config_.parity == 2) ? EVENPARITY : NOPARITY;

    dcb.fBinary = TRUE;
    dcb.fParity = TRUE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fDsrSensitivity = FALSE;
    dcb.fTXContinueOnXoff = TRUE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;
    dcb.fErrorChar = FALSE;
    dcb.fNull = FALSE;
    // RS-485 方向控制: 禁用 RTS
    // 某些自动方向控制的适配器需要 RTS 禁用
    dcb.fRtsControl = RTS_CONTROL_DISABLE;
    // 同时禁用 DTR
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fAbortOnError = FALSE;

    // 设置配置
    if (!SetCommState(handle_, &dcb)) {
        std::cerr << "Failed to set comm state" << std::endl;
        return false;
    }

    // 设置超时 - 优化串口读取行为
    COMMTIMEOUTS timeouts = {};
    // ReadIntervalTimeout: 字符间最大超时 (ms)
    // MAXDWORD 表示立即返回，配合 OVERLAPPED 使用
    timeouts.ReadIntervalTimeout = MAXDWORD;
    // ReadTotalTimeoutMultiplier: 每个字符的超时乘数 (ms)
    timeouts.ReadTotalTimeoutMultiplier = MAXDWORD;
    // ReadTotalTimeoutConstant: 总读取超时基数 (ms)
    // 0 表示无总超时限制，只在字符间超时时返回
    timeouts.ReadTotalTimeoutConstant = 0;
    // 写入超时设置
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 100; // 100ms

    if (!SetCommTimeouts(handle_, &timeouts)) {
        std::cerr << "Failed to set comm timeouts" << std::endl;
        return false;
    }

    return true;
#else
    return false;
#endif
}

} // namespace _4CP
