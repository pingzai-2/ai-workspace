#ifndef MODBUSFRESHNESSTRACKER_H
#define MODBUSFRESHNESSTRACKER_H

#include <chrono>

// 只记录最近一次成功的 Modbus RTU 通信，不依赖可能不准确的系统时间。
// 外部锁负责并发保护；本类只保存状态并提供可单测的边界判断。
class ModbusFreshnessTracker {
public:
    using Clock = std::chrono::steady_clock;
    using TimePoint = Clock::time_point;

    static constexpr int STALE_TIMEOUT_MS = 30000;

    void markSuccess(TimePoint now = Clock::now())
    {
        m_lastSuccessAt = now;
        m_hasSuccess = true;
    }

    bool isFresh(TimePoint now = Clock::now()) const
    {
        return m_hasSuccess
            && now - m_lastSuccessAt
                < std::chrono::milliseconds(STALE_TIMEOUT_MS);
    }

private:
    TimePoint m_lastSuccessAt;
    bool m_hasSuccess = false;
};

#endif // MODBUSFRESHNESSTRACKER_H
