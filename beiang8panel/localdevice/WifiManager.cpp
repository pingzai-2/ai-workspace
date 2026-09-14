#include "WifiManager.h"

#include "DataManager.h"
#include "common/LogManager.h"
#include "structure/LocalDeviceDataStructure.h"

#include <emc6069.h>

#include <algorithm>
#include <chrono>
#include <utility>
#include <vector>

namespace {

constexpr int WIFI_STATUS_INTERVAL_MS = 2000;
// 库内单次扫描/连接/状态查询自带超时（扫描约10s、连接最长20s、状态约4s），
// 这里只限制去重后保留的条数，与旧 fork emc6069_wifid 版行为一致。
constexpr size_t WIFI_SCAN_RESULT_LIMIT = EMC6069_MAX_AP_RESULTS;

int64_t nowMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

// OTA 下载/安装期间模组串口被库独占，普通指令一律返回 -1。
// 提前识别可以避免把这种失败当作 WiFi 异常，造成状态抖动。
bool isOtaTransferBusy(const OtaRuntimeData& ota)
{
    return ota.available
        && (ota.state == "downloading"
            || ota.state == "downloadComplete"
            || ota.state == "installing");
}

std::vector<WifiNetworkData> convertScanResults(
    const emc6069_wifi_scan_result_t* apList, int count)
{
    std::vector<WifiNetworkData> networks;
    for (int i = 0; i < count && i < EMC6069_MAX_AP_RESULTS; ++i) {
        WifiNetworkData network;
        network.ssid = apList[i].ssid;
        network.secured = apList[i].key_mgmt != WIFI_SEC_NONE;
        network.rssi = apList[i].rssi;

        auto existing = std::find_if(networks.begin(), networks.end(),
            [&network](const WifiNetworkData& item) {
                return item.ssid == network.ssid;
            });
        if (existing == networks.end()) {
            networks.push_back(std::move(network));
        } else if (network.rssi > existing->rssi) {
            *existing = std::move(network);
        }
    }

    std::sort(networks.begin(), networks.end(),
        [](const WifiNetworkData& left, const WifiNetworkData& right) {
            return left.rssi > right.rssi;
        });
    if (networks.size() > WIFI_SCAN_RESULT_LIMIT) {
        networks.resize(WIFI_SCAN_RESULT_LIMIT);
    }
    return networks;
}

} // namespace

WifiManager::WifiManager(DataManager* dataManager)
    : m_dataManager(dataManager)
    , m_running(false)
    , m_available(false)
    , m_enabled(true)
    , m_stopRequested(false)
    , m_connectSequence(0)
{
}

WifiManager::~WifiManager()
{
    stop();
}

bool WifiManager::start()
{
    if (m_running.load()) {
        return true;
    }
    if (!m_dataManager) {
        return false;
    }

    // 串口传输层由 OtaManager 提供，其可用状态经 DataManager 快照读取。
    // OtaManager 尚未启动时这里先按不可用发布，2s 周期刷新会自动纠正。
    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    m_available = snapshot.ota.available;
    WifiRuntimeData data = snapshot.wifi;
    data.available = m_available.load();
    data.enabled = data.available && m_enabled;
    if (!data.available) {
        data.connected = false;
        data.commandPending = false;
        data.lastCommandSuccess = false;
        data.targetSsid.clear();
        data.connectedSsid.clear();
        data.ipAddress.clear();
        data.rssi = 0;
        data.scanResults.clear();
    }
    data.state = data.available ? "idle" : "disabled";
    data.lastError = data.available ? "" : "WiFi system interface is unavailable";
    data.timestamp = nowMilliseconds();
    m_dataManager->updateWifiData(data);

    if (m_available.load()) {
        refreshStatus();
    }
    m_stopRequested = false;
    m_running = true;
    m_worker = std::thread(&WifiManager::workerLoop, this);
    LOG_INFO("[WiFi] Worker started, adapter available={}", m_available.load());
    return true;
}

void WifiManager::stop()
{
    if (!m_running.load()) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(m_queueMutex);
        m_stopRequested = true;
    }
    m_queueCondition.notify_all();
    if (m_worker.joinable()) {
        // 库调用（连接最长20s）不可中断，join 最多等待当前命令自然结束
        m_worker.join();
    }
    m_running = false;
    LOG_INFO("[WiFi] Worker stopped");
}

bool WifiManager::submitCommand(WifiCommand command)
{
    std::lock_guard<std::mutex> lock(m_queueMutex);
    if (!m_running.load() || m_stopRequested || !m_available.load()) {
        return false;
    }
    const bool connectCommand = command.type == WifiCommandType::Connect;
    const bool disconnectCommand = command.type == WifiCommandType::Disconnect;
    const bool disableCommand = command.type == WifiCommandType::SetEnabled
        && !command.enabled;
    if (connectCommand || disconnectCommand || disableCommand) {
        const uint64_t sequence = m_connectSequence.fetch_add(1) + 1;
        if (connectCommand) {
            command.sequence = sequence;
        }

        // 新的连接意图替换旧连接和候选扫描。自动连接只会在上一项明确
        // 失败后提交下一项，因此连接中出现的新 Connect 就是用户抢占。
        m_commands.erase(
            std::remove_if(m_commands.begin(), m_commands.end(),
                [](const WifiCommand& queued) {
                    return queued.type == WifiCommandType::Connect
                        || queued.type == WifiCommandType::Scan;
                }),
            m_commands.end());
        m_commands.push_front(std::move(command));
    } else {
        m_commands.push_back(std::move(command));
    }
    m_queueCondition.notify_one();
    return true;
}

void WifiManager::workerLoop()
{
    auto nextStatus = std::chrono::steady_clock::now()
        + std::chrono::milliseconds(WIFI_STATUS_INTERVAL_MS);
    while (true) {
        WifiCommand command;
        bool hasCommand = false;
        {
            std::unique_lock<std::mutex> lock(m_queueMutex);
            m_queueCondition.wait_until(lock, nextStatus, [this]() {
                return m_stopRequested || !m_commands.empty();
            });
            if (m_stopRequested) {
                break;
            }
            if (!m_commands.empty()) {
                command = std::move(m_commands.front());
                m_commands.pop_front();
                hasCommand = true;
            }
        }

        if (hasCommand) {
            // WiFi 状态只有本工作线程可以发布。命令排队时不提前改
            // pending，避免上一条命令完成后覆盖下一条命令的状态。
            publishPending(command);
            processCommand(command);
        }
        if (std::chrono::steady_clock::now() >= nextStatus) {
            bool hasQueuedCommand = false;
            {
                std::lock_guard<std::mutex> lock(m_queueMutex);
                hasQueuedCommand = !m_commands.empty();
            }
            if (!hasQueuedCommand) {
                refreshStatus();
                nextStatus = std::chrono::steady_clock::now()
                    + std::chrono::milliseconds(WIFI_STATUS_INTERVAL_MS);
            }
        }
    }
}

void WifiManager::publishPending(const WifiCommand& command)
{
    WifiRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().wifi;
    data.commandPending = true;
    data.lastCommandSuccess = false;
    data.lastError.clear();
    switch (command.type) {
    case WifiCommandType::SetEnabled:
        data.state = command.enabled ? "idle" : "disconnecting";
        break;
    case WifiCommandType::Scan:
        data.state = "scanning";
        break;
    case WifiCommandType::Connect:
        data.state = "connecting";
        data.targetSsid = command.ssid;
        break;
    case WifiCommandType::Disconnect:
        data.state = "disconnecting";
        break;
    }
    data.timestamp = nowMilliseconds();
    m_dataManager->updateWifiData(data);
}

void WifiManager::processCommand(const WifiCommand& command)
{
    switch (command.type) {
    case WifiCommandType::SetEnabled:
        processSetEnabled(command.enabled);
        break;
    case WifiCommandType::Scan:
        processScan();
        break;
    case WifiCommandType::Connect:
        processConnect(command.ssid, command.password, command.sequence);
        break;
    case WifiCommandType::Disconnect:
        processDisconnect();
        break;
    case WifiCommandType::SyncTime:
        processSyncTime();
        break;
    }
}

void WifiManager::processSetEnabled(bool enabled)
{
    if (enabled) {
        m_enabled = true;
        WifiRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().wifi;
        data.enabled = true;
        data.commandPending = false;
        data.lastCommandSuccess = true;
        data.lastError.clear();
        data.state = data.connected ? "connected" : "idle";
        data.timestamp = nowMilliseconds();
        m_dataManager->updateWifiData(data);
        refreshStatus();
        return;
    }

    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    const bool otaBusy = isOtaTransferBusy(snapshot.ota);
    WifiRuntimeData data = snapshot.wifi;
    data.commandPending = false;
    data.lastCommandSuccess = false;
    data.timestamp = nowMilliseconds();
    if (otaBusy) {
        // 关闭开关在 OTA 期间无法断开模组，保持原状态并提示原因
        data.lastError = "OTA transfer in progress";
    } else {
        if (emc6069_wifi_disconnect(NULL) == 0) {
            m_enabled = false;
            data.lastCommandSuccess = true;
            data.enabled = false;
            data.connected = false;
            data.targetSsid.clear();
            data.connectedSsid.clear();
            data.ipAddress.clear();
            data.rssi = 0;
            data.scanResults.clear();
            data.state = "disabled";
            data.lastError.clear();
        } else {
            data.lastError = "WiFi disable failed";
        }
    }
    m_dataManager->updateWifiData(data);
}

void WifiManager::processScan()
{
    const uint64_t connectSequence = m_connectSequence.load();
    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    if (!snapshot.ota.available || isOtaTransferBusy(snapshot.ota)) {
        WifiRuntimeData data = snapshot.wifi;
        data.commandPending = false;
        data.lastCommandSuccess = false;
        data.state = data.connected ? "connected" : "idle";
        data.lastError = snapshot.ota.available
            ? "OTA transfer in progress"
            : "WiFi system interface is unavailable";
        data.timestamp = nowMilliseconds();
        m_dataManager->updateWifiData(data);
        return;
    }

    // 库调用阻塞约10s；期间出现的新连接命令使本次扫描结果作废
    emc6069_wifi_scan_result_t apList[EMC6069_MAX_AP_RESULTS] = {};
    const int count = emc6069_wifi_scan(apList);
    if (m_stopRequested.load() || m_connectSequence.load() != connectSequence) {
        return;
    }

    WifiRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().wifi;
    data.commandPending = false;
    data.lastCommandSuccess = count >= 0;
    data.timestamp = nowMilliseconds();
    if (count >= 0) {
        data.scanResults = convertScanResults(apList, count);
        data.state = data.connected ? "connected" : "idle";
        data.lastError.clear();
    } else {
        // 扫描失败不清空上一次有效列表。
        data.state = "failed";
        data.lastError = "WiFi scan failed";
    }
    m_dataManager->updateWifiData(data);
}

void WifiManager::processConnect(
    const std::string& ssid,
    const std::string& password,
    uint64_t sequence)
{
    m_enabled = true;
    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    if (!snapshot.ota.available || isOtaTransferBusy(snapshot.ota)) {
        WifiRuntimeData data = snapshot.wifi;
        data.enabled = true;
        data.commandPending = false;
        data.lastCommandSuccess = false;
        data.state = "failed";
        data.lastError = snapshot.ota.available
            ? "OTA transfer in progress"
            : "WiFi system interface is unavailable";
        data.timestamp = nowMilliseconds();
        m_dataManager->updateWifiData(data);
        return;
    }

    // 库内阻塞等待连接结果（最长 EMC6069_WIFI_CONNECT_TIMEOUT 秒）
    const int result = emc6069_wifi_connect(ssid.c_str(), password.c_str());
    if (m_stopRequested.load() || m_connectSequence.load() != sequence) {
        return;
    }
    if (result != 0) {
        WifiRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().wifi;
        data.enabled = true;
        data.commandPending = false;
        data.lastCommandSuccess = false;
        data.state = "failed";
        data.lastError = "WiFi connect failed";
        data.timestamp = nowMilliseconds();
        m_dataManager->updateWifiData(data);
        return;
    }

    // 库的连接返回成功表示已收到模组连接成功通知；紧接一次状态确认带出
    // SSID/IP。0x18 信息偶尔晚于连接通知就绪，短暂重试几次再定论。
    for (int attempt = 0; attempt < 3; ++attempt) {
        refreshStatus();
        if (m_dataManager->getLocalDeviceDataSnapshot().wifi.connected) {
            // 连接确认成功, 同步网络时间(0x24->系统时间+RTC)
            processSyncTime();
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    refreshStatus();
}

bool WifiManager::requestTimeSync()
{
    std::lock_guard<std::mutex> lock(m_queueMutex);
    if (!m_running.load() || m_stopRequested || !m_available.load()) {
        return false;
    }
    // 已有待处理的SyncTime则不重复入队
    for (const auto& queued : m_commands) {
        if (queued.type == WifiCommandType::SyncTime) {
            return true;
        }
    }
    WifiCommand command;
    command.type = WifiCommandType::SyncTime;
    m_commands.push_back(command);
    return true;
}

void WifiManager::processSyncTime()
{
    // 工作线程执行, 0x24查询UTC(带重试)写系统时间与全部RTC
    const int result = emc6069_sync_time_to_system();
    LOG_INFO("[WiFi] time sync after network: {}",
        result == 0 ? "ok" : (result == 1 ? "system only, rtc failed" : "failed"));
}

void WifiManager::processDisconnect()
{
    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    const bool otaBusy = isOtaTransferBusy(snapshot.ota);
    WifiRuntimeData data = snapshot.wifi;
    // Disconnect 只断开当前连接，不等于 SetEnabled(false)。显式重发
    // available/enabled，避免 UI 把一次普通断开误判成 Wi-Fi 开关关闭。
    data.available = snapshot.ota.available;
    data.enabled = data.available && m_enabled;
    data.commandPending = false;
    data.lastCommandSuccess = false;
    data.timestamp = nowMilliseconds();
    if (otaBusy || !snapshot.ota.available) {
        data.lastError = snapshot.ota.available
            ? "OTA transfer in progress"
            : "WiFi system interface is unavailable";
    } else {
        if (emc6069_wifi_disconnect(NULL) == 0) {
            data.lastCommandSuccess = true;
            data.connected = false;
            data.targetSsid.clear();
            data.connectedSsid.clear();
            data.ipAddress.clear();
            data.rssi = 0;
            data.state = m_enabled ? "idle" : "disabled";
            data.lastError.clear();
        } else {
            data.state = "failed";
            data.lastError = "WiFi disconnect failed";
        }
    }
    m_dataManager->updateWifiData(data);
}

void WifiManager::refreshStatus()
{
    const LocalDeviceDataStructure snapshot = m_dataManager->getLocalDeviceDataSnapshot();
    m_available = snapshot.ota.available;
    WifiRuntimeData data = snapshot.wifi;
    data.available = m_available.load();
    data.enabled = data.available && m_enabled;
    data.timestamp = nowMilliseconds();
    if (!data.available || !m_enabled) {
        data.state = "disabled";
        data.connected = false;
        m_dataManager->updateWifiData(data);
        return;
    }
    if (isOtaTransferBusy(snapshot.ota)) {
        // OTA 传输期间模组不响应状态查询，保留上次 WiFi 状态即可
        return;
    }

    emc6069_wifi_status_info_t info = {};
    if (emc6069_get_wifi_status(&info) != 0) {
        // 读失败不覆盖上一次的 SSID/IP/连接值。
        if (!data.connected) {
            data.state = "failed";
            data.lastError = "WiFi status query failed";
        }
        m_dataManager->updateWifiData(data);
        return;
    }

    // 库在已连接时才带出 SSID/IP；SSID 缺失时 normalizer 会按未连接处理
    const bool connected = info.status == EMC6069_NET_CONNECTED
        && info.ssid[0] != '\0';
    data.connected = connected;
    if (connected) {
        data.connectedSsid = info.ssid;
        data.ipAddress = info.ip;
        data.rssi = info.rssi > 0 ? 0 : info.rssi;
        data.state = "connected";
        data.commandPending = false;
        data.lastCommandSuccess = true;
        data.lastError.clear();
        data.targetSsid.clear();
    } else {
        data.connectedSsid.clear();
        data.ipAddress.clear();
        data.rssi = 0;
        data.state = "idle";
        data.lastError.clear();
    }
    m_dataManager->updateWifiData(data);
}
