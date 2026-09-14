#pragma once

#include <iostream>
#include <iomanip>
#include <chrono>
#include <sstream>

namespace _4CP {

// 日志辅助类 - 提供带时间戳的日志输出
class Logger {
public:
    class ScopedThreadSilence {
    public:
        ScopedThreadSilence() : previous_(ThreadLoggingEnabled()) {
            ThreadLoggingEnabled() = false;
        }

        ~ScopedThreadSilence() {
            ThreadLoggingEnabled() = previous_;
        }

    private:
        bool previous_;
    };

    static bool IsThreadLoggingEnabled() {
        return ThreadLoggingEnabled();
    }

    // 获取当前时间戳字符串，格式: 2026-8-6 07:43:21
    static std::string GetTimestamp() {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);

        std::stringstream ss;
        tm localTime;
        #ifdef _WIN32
            localtime_s(&localTime, &time);
        #else
            localtime_r(&time, &localTime);
        #endif

        ss << std::setfill('0')
           << (localTime.tm_year + 1900) << "-"
           << (localTime.tm_mon + 1) << "-"
           << localTime.tm_mday << " "
           << std::setw(2) << localTime.tm_hour << ":"
           << std::setw(2) << localTime.tm_min << ":"
           << std::setw(2) << localTime.tm_sec;

        return ss.str();
    }

    // 输出带时间戳的日志
    static void Log(const std::string& message) {
        std::cout << "[" << GetTimestamp() << "] " << message << std::endl;
    }

    // 输出不带换行的日志（用于后续继续输出）
    static void LogContinued(const std::string& message) {
        std::cout << "[" << GetTimestamp() << "] " << message;
    }

private:
    static bool& ThreadLoggingEnabled() {
        static thread_local bool enabled = true;
        return enabled;
    }
};

// 便捷宏定义
#define LOG(msg) do { \
    if (_4CP::Logger::IsThreadLoggingEnabled()) { \
        std::cout << "[" << _4CP::Logger::GetTimestamp() << "] " << msg << std::endl; \
    } \
} while (0)
#define LOG_CONT(msg) do { \
    if (_4CP::Logger::IsThreadLoggingEnabled()) { \
        std::cout << "[" << _4CP::Logger::GetTimestamp() << "] " << msg; \
    } \
} while (0)

} // namespace _4CP
