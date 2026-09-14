/**
 * MemoryWatchModule - 内存水位监控与分级处置模块
 *
 * 独立线程按配置周期读取 /proc/meminfo 的 MemAvailable,按 MemoryWatchPolicy
 * 三级阈值处置: 告警日志 → 重启 Flutter(SIGTERM, PVR 驱动约束禁 kill -9)→
 * 重启设备。OTA 进行中抑制动作。状态经 GET /api/memwatch/status 暴露。
 */

#ifndef MEMORYWATCHMODULE_H
#define MEMORYWATCHMODULE_H

#include "MemoryWatchPolicy.h"

#include <nlohmann/json.hpp>

#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class DataManager;

class MemoryWatchModule {
public:
    explicit MemoryWatchModule(DataManager* dataManager, const MemoryWatchConfig& config);
    ~MemoryWatchModule();

    MemoryWatchModule(const MemoryWatchModule&) = delete;
    MemoryWatchModule& operator=(const MemoryWatchModule&) = delete;

    // 启动监控线程;stop 幂等。enabled=false 时启动为空转。
    bool start();
    void stop();
    bool isRunning() const { return m_running.load(); }

    // GET /api/memwatch/status 的 data 对象
    nlohmann::json getStatusJson() const;

private:
    void monitorLoop();
    void checkOnce(int64_t nowEpochSec);
    // /proc/meminfo MemAvailable;失败返回 -1
    int64_t readMemAvailableKB() const;
    bool isOtaBusy() const;
    std::vector<int> findFlutterPids() const;

    // 动作执行。restartFlutter 成功发出 SIGTERM 并确认退出+重新拉起返回 true;
    // 未能退出返回 false(下一轮策略升级为重启设备)。
    bool restartFlutterApp();
    void rebootDevice();

    void recordEvent(const std::string& text);
    static std::string formatTime(int64_t epochSec);

    DataManager* m_dataManager;
    MemoryWatchConfig m_config;

    std::atomic<bool> m_running{false};
    std::thread m_thread;
    std::mutex m_stopMutex;
    std::condition_variable m_stopCv;

    // 保护策略状态与快照
    mutable std::mutex m_mutex;
    MemoryWatchState m_state;
    int64_t m_lastCheckEpoch = 0;
    int64_t m_lastMemAvailableKB = -1;
    uint64_t m_restartAppCount = 0;
    int64_t m_lastRestartAppEpoch = 0;
    std::deque<std::string> m_events; // 最近事件(时间+动作+水位)
};

#endif // MEMORYWATCHMODULE_H
