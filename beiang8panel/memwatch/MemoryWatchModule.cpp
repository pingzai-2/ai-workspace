/**
 * MemoryWatchModule 实现
 */

#include "MemoryWatchModule.h"
#include "DataManager.h"
#include "common/LogManager.h"

#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <cstdlib>
#include <dirent.h>
#include <unistd.h>

#ifdef __linux__
#include <sys/reboot.h>
#endif

#include <algorithm>

namespace {

// rc.local 同款拉起命令(直跑 eglfs, 无环境依赖)
// 旋转由内核 fb_g2d_rot(G2D 硬件)统一接管, 不再用 -r 90 软件旋转(会双重旋转)
const char* kFlutterStartCommand =
    "(trap '' HUP; /usr/bin/flutter_eglfs /usr/bin/bundle/ >/dev/null 2>&1 &)";
constexpr int kFlutterExitWaitSec = 15; // PVR 约束: 只 SIGTERM, 给足 EGL 清理时间
constexpr size_t kMaxEvents = 8;

std::string levelName(int level)
{
    switch (level) {
    case 1: return "warn";
    case 2: return "restart";
    case 3: return "reboot";
    default: return "normal";
    }
}

} // namespace

MemoryWatchModule::MemoryWatchModule(DataManager* dataManager,
    const MemoryWatchConfig& config)
    : m_dataManager(dataManager)
    , m_config(config)
{
    if (m_config.checkIntervalSec < 5) {
        m_config.checkIntervalSec = 5;
    }
    if (m_config.sustainedChecks < 1) {
        m_config.sustainedChecks = 1;
    }
    if (m_config.actionCooldownSec < 30) {
        m_config.actionCooldownSec = 30;
    }
}

MemoryWatchModule::~MemoryWatchModule()
{
    stop();
}

bool MemoryWatchModule::start()
{
    if (m_running.exchange(true)) {
        return true;
    }
    if (!m_config.enabled) {
        LOG_INFO("[MemoryWatch] disabled by config, monitoring skipped");
        return true;
    }
    try {
        m_thread = std::thread(&MemoryWatchModule::monitorLoop, this);
    } catch (const std::system_error& e) {
        m_running = false;
        LOG_ERROR("[MemoryWatch] failed to start thread: {}", e.what());
        return false;
    }
    LOG_INFO("[MemoryWatch] started: interval={}s warn={}KB restartApp={}KB reboot={}KB sustained={} cooldown={}s",
        m_config.checkIntervalSec, m_config.warnThresholdKB,
        m_config.restartAppThresholdKB, m_config.rebootThresholdKB,
        m_config.sustainedChecks, m_config.actionCooldownSec);
    return true;
}

void MemoryWatchModule::stop()
{
    if (!m_running.exchange(false)) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(m_stopMutex);
    }
    m_stopCv.notify_all();
    if (m_thread.joinable()) {
        m_thread.join();
    }
    LOG_INFO("[MemoryWatch] stopped, flutter restarts this run: {}", m_restartAppCount);
}

void MemoryWatchModule::monitorLoop()
{
    int64_t tick = static_cast<int64_t>(::time(nullptr));
    while (m_running.load()) {
        tick += m_config.checkIntervalSec;
        if (tick <= static_cast<int64_t>(::time(nullptr))) {
            // 系统挂起等导致严重迟到: 重新对齐到当前时间,不补采
            tick = static_cast<int64_t>(::time(nullptr)) + m_config.checkIntervalSec;
        }
        std::unique_lock<std::mutex> lock(m_stopMutex);
        m_stopCv.wait_until(lock,
            std::chrono::system_clock::from_time_t(static_cast<time_t>(tick)),
            [this] { return !m_running.load(); });
        lock.unlock();
        if (!m_running.load()) {
            break;
        }
        checkOnce(static_cast<int64_t>(::time(nullptr)));
    }
}

int64_t MemoryWatchModule::readMemAvailableKB() const
{
    FILE* fp = std::fopen("/proc/meminfo", "r");
    if (!fp) {
        return -1;
    }
    char line[256];
    int64_t value = -1;
    while (std::fgets(line, sizeof(line), fp)) {
        if (std::strncmp(line, "MemAvailable:", 13) == 0) {
            value = std::strtoll(line + 13, nullptr, 10);
            break;
        }
    }
    std::fclose(fp);
    return value;
}

bool MemoryWatchModule::isOtaBusy() const
{
    // 下载/安装中抑制所有处置动作;idle/failed 之外都视为忙
    const std::string state = m_dataManager->getLocalDeviceDataSnapshot().ota.state;
    return !state.empty() && state != "idle" && state != "failed";
}

std::vector<int> MemoryWatchModule::findFlutterPids() const
{
    std::vector<int> pids;
    DIR* dir = opendir("/proc");
    if (!dir) {
        return pids;
    }
    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        bool numeric = entry->d_name[0] >= '0' && entry->d_name[0] <= '9';
        if (!numeric) {
            continue;
        }
        char path[64];
        std::snprintf(path, sizeof(path), "/proc/%s/cmdline", entry->d_name);
        FILE* fp = std::fopen(path, "r");
        if (!fp) {
            continue;
        }
        char cmdline[512] = {0};
        std::fgets(cmdline, sizeof(cmdline), fp);
        std::fclose(fp);
        if (std::strstr(cmdline, "flutter_eglfs") != nullptr) {
            pids.push_back(std::atoi(entry->d_name));
        }
    }
    closedir(dir);
    return pids;
}

bool MemoryWatchModule::restartFlutterApp()
{
    std::vector<int> pids = findFlutterPids();
    if (pids.empty()) {
        LOG_WARNING("[MemoryWatch] flutter_eglfs not running, relaunch only");
    } else {
        // PVR 驱动约束: 普通 SIGTERM 让 EGL 完整销毁, 严禁 kill -9
        for (int pid : pids) {
            kill(pid, SIGTERM);
        }
        bool exited = false;
        for (int waited = 0; waited < kFlutterExitWaitSec * 10 && !exited; ++waited) {
            usleep(100 * 1000);
            exited = findFlutterPids().empty();
        }
        if (!exited) {
            LOG_ERROR("[MemoryWatch] flutter did not exit within {}s after SIGTERM, "
                      "will escalate to device reboot", kFlutterExitWaitSec);
            return false;
        }
    }
    // rc.local 同款命令重新拉起(busybox 无 nohup, 用 trap 忽略 HUP)
    const int rc = std::system(kFlutterStartCommand);
    LOG_CRITICAL("[MemoryWatch] flutter restarted (system rc={})", rc);
    return rc == 0;
}

void MemoryWatchModule::rebootDevice()
{
    LOG_CRITICAL("[MemoryWatch] rebooting device now");
    LogManager::getInstance().flush();
    sync();
#ifdef __linux__
    reboot(RB_AUTOBOOT);
#endif
    // 非 Linux 或 syscall 失败时的兜底
    std::system("reboot");
}

std::string MemoryWatchModule::formatTime(int64_t epochSec)
{
    char buf[24];
    time_t t = static_cast<time_t>(epochSec);
    tm value;
    localtime_r(&t, &value);
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &value);
    return std::string(buf);
}

void MemoryWatchModule::recordEvent(const std::string& text)
{
    std::lock_guard<std::mutex> guard(m_mutex);
    m_events.push_back(text);
    while (m_events.size() > kMaxEvents) {
        m_events.pop_front();
    }
}

void MemoryWatchModule::checkOnce(int64_t nowEpochSec)
{
    const int64_t memKB = readMemAvailableKB();
    if (memKB < 0) {
        LOG_WARNING("[MemoryWatch] read /proc/meminfo failed");
        return;
    }
    const MemoryWatchSample sample = {memKB, isOtaBusy()};

    MemoryWatchAction action;
    {
        std::lock_guard<std::mutex> guard(m_mutex);
        action = evaluate(sample, m_config, nowEpochSec, &m_state);
        m_lastCheckEpoch = nowEpochSec;
        m_lastMemAvailableKB = memKB;
    }
    const double memMB = memKB / 1024.0;
    const std::string stamp = formatTime(nowEpochSec);

    switch (action) {
    case MemoryWatchAction::None:
    case MemoryWatchAction::KeepQuiet:
        break;
    case MemoryWatchAction::LogWarnOnce:
        LOG_WARNING("[MemoryWatch] low memory: MemAvailable={}KB({:.1f}MB)", memKB, memMB);
        recordEvent(stamp + " WARN MemAvailable=" + std::to_string(memKB) + "KB");
        break;
    case MemoryWatchAction::LogWarnRepeat:
        LOG_WARNING("[MemoryWatch] still low memory: MemAvailable={}KB({:.1f}MB)", memKB, memMB);
        break;
    case MemoryWatchAction::LogRecover:
        LOG_INFO("[MemoryWatch] memory recovered: MemAvailable={}KB({:.1f}MB)", memKB, memMB);
        recordEvent(stamp + " RECOVER MemAvailable=" + std::to_string(memKB) + "KB");
        break;
    case MemoryWatchAction::SkipOtaBusy:
        LOG_WARNING("[MemoryWatch] MemAvailable={}KB({:.1f}MB), action suppressed during OTA",
            memKB, memMB);
        recordEvent(stamp + " SUPPRESSED(OTA) MemAvailable=" + std::to_string(memKB) + "KB");
        break;
    case MemoryWatchAction::RestartApp: {
        LOG_CRITICAL("[MemoryWatch] MemAvailable={}KB({:.1f}MB) below restart threshold, "
                     "restarting flutter", memKB, memMB);
        recordEvent(stamp + " RESTART-APP MemAvailable=" + std::to_string(memKB) + "KB");
        const bool ok = restartFlutterApp();
        std::lock_guard<std::mutex> guard(m_mutex);
        if (ok) {
            ++m_restartAppCount;
            m_lastRestartAppEpoch = nowEpochSec;
            m_state.lastRestartAppEpoch = nowEpochSec;
        }
        break;
    }
    case MemoryWatchAction::RebootDevice:
        recordEvent(stamp + " REBOOT-DEVICE MemAvailable=" + std::to_string(memKB) + "KB");
        rebootDevice();
        break;
    }
}

nlohmann::json MemoryWatchModule::getStatusJson() const
{
    std::lock_guard<std::mutex> guard(m_mutex);
    const int level = levelToInt(levelOf(
        m_lastMemAvailableKB > 0 ? m_lastMemAvailableKB : (1LL << 62), m_config));

    nlohmann::json events = nlohmann::json::array();
    for (const std::string& text : m_events) {
        events.push_back(text);
    }

    nlohmann::json data;
    data["enabled"] = m_config.enabled;
    data["checkIntervalSec"] = m_config.checkIntervalSec;
    data["warnThresholdMB"] = m_config.warnThresholdKB / 1024;
    data["restartAppThresholdMB"] = m_config.restartAppThresholdKB / 1024;
    data["rebootThresholdMB"] = m_config.rebootThresholdKB / 1024;
    data["sustainedChecks"] = m_config.sustainedChecks;
    data["actionCooldownSec"] = m_config.actionCooldownSec;
    data["memAvailableKB"] = m_lastMemAvailableKB;
    data["memAvailableMB"] = m_lastMemAvailableKB > 0
        ? nlohmann::json(m_lastMemAvailableKB / 1024.0)
        : nlohmann::json(nullptr);
    data["level"] = levelName(m_lastMemAvailableKB > 0 ? level : 0);
    data["lastCheckTime"] = m_lastCheckEpoch != 0
        ? nlohmann::json(formatTime(m_lastCheckEpoch))
        : nlohmann::json(nullptr);
    data["restartAppCount"] = m_restartAppCount;
    data["lastRestartAppTime"] = m_lastRestartAppEpoch != 0
        ? nlohmann::json(formatTime(m_lastRestartAppEpoch))
        : nlohmann::json(nullptr);
    data["events"] = events;
    return data;
}
