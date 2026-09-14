/**
 * WiFi 管理模块。
 *
 * WiFi 扫描/连接可能阻塞数秒，因此使用独立工作线程，
 * 不占用亮度、指示灯和本机传感器的采集节拍。
 *
 * 底层直接调用 libemc6069（emc6069 模组串口由 OtaManager 常驻持有，
 * OTA 下载/安装期间模组串口被独占，此时 WiFi 命令会被库拒绝，
 * 本模块识别后保持原状态而不是报 failed）。
 */

#ifndef WIFIMANAGER_H
#define WIFIMANAGER_H

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

class DataManager;

enum class WifiCommandType {
    SetEnabled,
    Scan,
    Connect,
    Disconnect,
    SyncTime // 联网后同步网络时间(0x24->系统时间+RTC)
};

struct WifiCommand {
    WifiCommandType type = WifiCommandType::Scan;
    bool enabled = true;
    std::string ssid;
    std::string password;
    uint64_t sequence = 0;
};

class WifiManager {
public:
    explicit WifiManager(DataManager* dataManager);
    ~WifiManager();

    bool start();
    void stop();
    bool submitCommand(WifiCommand command);

    // 请求同步网络时间(0x24)。非阻塞: 仅向命令队列投递SyncTime,
    // 供0x11重连通知等接收线程上下文转投执行。
    bool requestTimeSync();
    bool isRunning() const { return m_running.load(); }
    bool isAvailable() const { return m_available.load(); }

private:
    void workerLoop();
    void publishPending(const WifiCommand& command);
    void processCommand(const WifiCommand& command);
    void processSetEnabled(bool enabled);
    void processScan();
    void processConnect(
        const std::string& ssid,
        const std::string& password,
        uint64_t sequence);
    void processDisconnect();
    void processSyncTime();
    void refreshStatus();

    DataManager* m_dataManager;
    std::thread m_worker;
    std::atomic<bool> m_running;
    std::atomic<bool> m_available;
    bool m_enabled;
    std::atomic<bool> m_stopRequested;
    std::atomic<uint64_t> m_connectSequence;
    std::mutex m_queueMutex;
    std::condition_variable m_queueCondition;
    std::deque<WifiCommand> m_commands;
};

#endif // WIFIMANAGER_H
