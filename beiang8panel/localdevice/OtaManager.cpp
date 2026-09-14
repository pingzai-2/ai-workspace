#include "OtaManager.h"

#include "DataManager.h"
#include "common/GlobalDefine.h"
#include "common/GlobalFunction.h"
#include "common/LogManager.h"
#include "structure/LocalDeviceDataStructure.h"

#include <emc6069.h>

#include <sys/statvfs.h>

#include <chrono>

namespace {

// 与 emc6069-wifi 包编译宏保持一致（src/Makefile 覆盖了 SWU_PATH/CMD）
constexpr const char* OTA_FIRMWARE_PATH = "/mnt/UDISK/emc6069_ota.bin";
constexpr const char* OTA_VERSION_FILE = "/etc/version";
// 确认下载前要求 /mnt/UDISK 剩余空间大于固件包再留出余量
constexpr uint64_t OTA_FREE_SPACE_MARGIN_BYTES = 32ULL * 1024 * 1024;

int64_t nowMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

std::string trimCopy(const std::string& input)
{
    const auto begin = input.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos) {
        return {};
    }
    const auto end = input.find_last_not_of(" \t\r\n");
    return input.substr(begin, end - begin + 1);
}

} // namespace

OtaManager::OtaManager(DataManager* dataManager)
    : m_dataManager(dataManager)
    , m_running(false)
    , m_available(false)
    , m_stopRequested(false)
    , m_autoConfirmRequested(false)
{
}

OtaManager::~OtaManager()
{
    stop();
}

std::string OtaManager::readCurrentVersion() const
{
    // /etc/version 形如 "BAFreshAir8C-0.0.3"，即协议上报版本的数据来源；
    // 缺失时回退到后端程序自身版本
    std::string version = trimCopy(FileUtils::readFile(OTA_VERSION_FILE));
    if (version.empty()) {
        version = BEIANG_8PANEL_VERSION;
    }
    return version;
}

void OtaManager::otaEventCallbackTrampoline(int evt, const void* data, void* userData)
{
    auto* self = static_cast<OtaManager*>(userData);
    if (self) {
        self->handleOtaEvent(evt, data);
    }
}

void OtaManager::netStatusCallbackTrampoline(int status, void* userData)
{
    auto* self = static_cast<OtaManager*>(userData);
    if (!self) {
        return;
    }
    // 0x11 通知仅用于日志观测；WiFi 状态以 WifiManager 周期查询为准。
    // 库内部会根据连接状态自动启停 0x32 版本周期上报。
    switch (status) {
    case EMC6069_WIFI_CONNECTED: {
        LOG_INFO("[OTA] module network connected");
        // 重连成功场景转投时间同步; 回调内仅转发, 不阻塞接收线程
        if (self->m_netConnectedCallback) {
            self->m_netConnectedCallback();
        }
        break;
    }
    case EMC6069_WIFI_DISCONNECT:
        LOG_INFO("[OTA] module network disconnected");
        break;
    case EMC6069_WIFI_CONNECTING:
        LOG_INFO("[OTA] module network connecting");
        break;
    default:
        break;
    }
}

void OtaManager::setNetConnectedCallback(std::function<void()> callback)
{
    m_netConnectedCallback = std::move(callback);
}

void OtaManager::publishActionFailure(const std::string& error)
{
    std::lock_guard<std::mutex> lock(m_publishMutex);
    OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
    data.available = m_available.load();
    data.commandPending = false;
    data.lastCommandSuccess = false;
    data.lastError = error;
    data.timestamp = nowMilliseconds();
    m_dataManager->updateOtaData(data);
}

void OtaManager::handleOtaEvent(int evt, const void* eventData)
{
    auto* data = static_cast<const emc6069_ota_event_data_t*>(eventData);
    std::lock_guard<std::mutex> lock(m_publishMutex);
    OtaRuntimeData state = m_dataManager->getLocalDeviceDataSnapshot().ota;
    state.available = m_available.load();
    state.currentVersion = m_currentVersion;
    state.timestamp = nowMilliseconds();

    switch (evt) {
    case EMC6069_OTA_EVT_FW_NOTIFY:
        LOG_INFO("[OTA] firmware notify: version={}, size={} bytes",
            data->fw_ver ? data->fw_ver : "", data->total);
        state.updateAvailable = true;
        state.targetVersion = data->fw_ver ? data->fw_ver : "";
        state.fwSize = data->total;
        state.fwMd5 = data->fw_md5 ? data->fw_md5 : "";
        state.percent = 0;
        state.downloadedBytes = 0;
        state.lastError.clear();
        if (m_autoConfirmRequested.load()) {
            // 失败重试后模组重推通知，直接进入下载，不再回到二次确认
            state.state = "preparing";
            state.commandPending = true;
        } else {
            state.state = "notifyPending";
        }
        break;

    case EMC6069_OTA_EVT_DOWNLOAD_START:
        LOG_INFO("[OTA] download start, offset={} total={}",
            data->offset, data->total);
        m_autoConfirmRequested = false;
        state.state = "downloading";
        state.commandPending = false;
        state.lastCommandSuccess = true;
        state.downloadedBytes = data->offset;
        state.percent = data->percent;
        if (data->total > 0) {
            state.fwSize = data->total;
        }
        break;

    case EMC6069_OTA_EVT_DOWNLOAD_PROGRESS:
        state.state = "downloading";
        state.downloadedBytes = data->offset;
        state.percent = data->percent;
        break;

    case EMC6069_OTA_EVT_DOWNLOAD_COMPLETE:
        LOG_INFO("[OTA] download complete: {}",
            data->fw_path ? data->fw_path : "");
        state.state = "downloadComplete";
        state.downloadedBytes = state.fwSize;
        state.percent = 100;
        break;

    case EMC6069_OTA_EVT_INSTALL_START:
        LOG_INFO("[OTA] install start, device will reboot after swupdate");
        state.state = "installing";
        break;

    case EMC6069_OTA_EVT_DOWNLOAD_FAILED:
        LOG_ERROR("[OTA] download failed");
        // updateAvailable 保持 true：下载失败后按钮仍高亮，可重试或退出
        state.state = "failed";
        state.commandPending = false;
        state.lastCommandSuccess = false;
        state.lastError = "固件下载失败，请检查网络连接或稍后再试";
        break;

    default:
        return;
    }

    m_dataManager->updateOtaData(state);
}

bool OtaManager::start()
{
    if (m_running.load()) {
        return true;
    }
    if (!m_dataManager) {
        return false;
    }

    m_serialPort = m_dataManager->getOtaSerialPort();
    m_baudRate = m_dataManager->getOtaSerialBaudRate();
    m_workDir = m_dataManager->getOtaWorkDir();
    m_currentVersion = readCurrentVersion();

    if (!m_dataManager->isOtaEnabled()) {
        // 功能开关关闭：发布不可用状态即返回，不占用模组串口
        LOG_INFO("[OTA] disabled by config, staying idle");
        std::lock_guard<std::mutex> lock(m_publishMutex);
        OtaRuntimeData data;
        data.available = false;
        data.state = "idle";
        data.currentVersion = m_currentVersion;
        data.lastError = "OTA disabled";
        data.timestamp = nowMilliseconds();
        m_dataManager->updateOtaData(data);
        return true;
    }

    // 库的收尾流程会把固件 rename 到 workDir 之下，目录必须先建好
    if (!m_workDir.empty() && !FileUtils::createDirectories(m_workDir)) {
        LOG_ERROR("[OTA] cannot create work dir: {}", m_workDir);
    }

    OtaRuntimeData data;
    data.currentVersion = m_currentVersion;
    data.timestamp = nowMilliseconds();

    m_available = false;
    m_autoConfirmRequested = false;

    // 先注册回调再 init，init 期间模组重启（约2s）就可能产生 0x11 通知
    m_listenerHandle = emc6069_ota_listener_add(
        [](emc6069_ota_event_t evt, const emc6069_ota_event_data_t* eventData,
            void* userData) {
            OtaManager::otaEventCallbackTrampoline(
                static_cast<int>(evt), eventData, userData);
        },
        this);
    emc6069_register_net_status_cb(
        [](emc6069_wifi_status_t status, void* userData) {
            OtaManager::netStatusCallbackTrampoline(
                static_cast<int>(status), userData);
        },
        this);

    // init 会复位模组并等待约2s，属于启动期的预期阻塞
    if (emc6069_init(m_serialPort.c_str(), m_baudRate) != 0) {
        LOG_ERROR("[OTA] emc6069_init failed on {} @{}",
            m_serialPort, m_baudRate);
        data.available = false;
        data.state = "idle";
        data.lastError = "OTA serial init failed: " + m_serialPort;
        m_dataManager->updateOtaData(data);

        if (m_listenerHandle >= 0) {
            emc6069_ota_listener_remove(m_listenerHandle);
            m_listenerHandle = -1;
        }
        emc6069_unregister_net_status_cb();
        return false;
    }

    m_available = true;
    data.available = true;
    data.state = "idle";
    data.lastError.clear();
    m_dataManager->updateOtaData(data);

    m_stopRequested = false;
    m_running = true;
    m_actionThread = std::thread(&OtaManager::actionLoop, this);
    LOG_INFO("[OTA] started on {} @{}, current version={}",
        m_serialPort, m_baudRate, m_currentVersion);
    return true;
}

void OtaManager::stop()
{
    if (!m_running.load()) {
        // 启动中途失败的场景也要释放回调与串口
        if (m_listenerHandle >= 0) {
            emc6069_ota_listener_remove(m_listenerHandle);
            m_listenerHandle = -1;
        }
        emc6069_unregister_net_status_cb();
        if (m_available.load()) {
            emc6069_close();
            m_available = false;
        }
        return;
    }

    {
        std::lock_guard<std::mutex> lock(m_queueMutex);
        m_stopRequested = true;
    }
    m_queueCondition.notify_all();
    if (m_actionThread.joinable()) {
        m_actionThread.join();
    }
    m_running = false;

    if (m_listenerHandle >= 0) {
        emc6069_ota_listener_remove(m_listenerHandle);
        m_listenerHandle = -1;
    }
    emc6069_unregister_net_status_cb();
    emc6069_close();
    m_available = false;

    std::lock_guard<std::mutex> lock(m_publishMutex);
    OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
    data.available = false;
    data.state = "idle";
    data.commandPending = false;
    data.timestamp = nowMilliseconds();
    m_dataManager->updateOtaData(data);
    LOG_INFO("[OTA] stopped");
}

bool OtaManager::startDownload(std::string& error)
{
    std::lock_guard<std::mutex> lock(m_actionMutex);
    if (!m_running.load() || !m_available.load()) {
        error = "OTA 功能不可用";
        return false;
    }

    const OtaRuntimeData state = m_dataManager->getLocalDeviceDataSnapshot().ota;
    if (state.state == "downloading" || state.state == "downloadComplete"
        || state.state == "installing") {
        // 下载/安装进行中重复触发视为已受理
        return true;
    }

    // 模组未通知有新版本时直接拒绝（对应 UI 置灰逻辑 canUpdate），
    // 不再走"接受后由模组空查询回 idle"的路径。
    if (!state.updateAvailable) {
        error = "当前无可用更新";
        return false;
    }

    if (state.state != "notifyPending") {
        // 失败后重试：模组会重推 0x38，届时自动确认直接续传，不再弹确认框
        m_autoConfirmRequested = true;
        std::lock_guard<std::mutex> publishLock(m_publishMutex);
        OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
        data.state = "preparing";
        data.commandPending = true;
        data.lastError.clear();
        data.timestamp = nowMilliseconds();
        m_dataManager->updateOtaData(data);
        return true;
    }

    m_queue.push_back(OtaAction{OtaActionType::Confirm, false});
    m_queueCondition.notify_one();
    return true;
}

bool OtaManager::cancelDownload(bool cleanupFiles, std::string& error)
{
    std::lock_guard<std::mutex> lock(m_actionMutex);
    if (!m_running.load() || !m_available.load()) {
        error = "OTA 功能不可用";
        return false;
    }

    const OtaRuntimeData state = m_dataManager->getLocalDeviceDataSnapshot().ota;
    m_autoConfirmRequested = false;
    if (state.state == "notifyPending") {
        m_queue.push_back(OtaAction{OtaActionType::Cancel, cleanupFiles});
        m_queueCondition.notify_one();
    } else if (cleanupFiles) {
        // 下载失败后的“退出”：删除残留固件与续传记录
        FileUtils::removeFile(std::string(OTA_FIRMWARE_PATH));
        FileUtils::removeFile(std::string(OTA_FIRMWARE_PATH) + ".meta");
        FileUtils::removeFile(m_workDir + "/firmware.swu");
    } else if (!state.updateAvailable) {
        // 空闲且模组未通知有新版本：无可取消的更新
        error = "当前无可用更新";
        return false;
    }

    {
        std::lock_guard<std::mutex> publishLock(m_publishMutex);
        OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
        data.commandPending = false;
        data.state = "idle";
        data.lastError.clear();
        // updateAvailable 不复位：产品流程要求取消后更新按钮仍高亮
        data.timestamp = nowMilliseconds();
        m_dataManager->updateOtaData(data);
    }
    return true;
}

void OtaManager::actionLoop()
{
    while (true) {
        OtaAction action;
        {
            std::unique_lock<std::mutex> lock(m_queueMutex);
            m_queueCondition.wait(lock, [this]() {
                return m_stopRequested.load() || !m_queue.empty();
            });
            if (m_stopRequested.load()) {
                break;
            }
            action = m_queue.front();
            m_queue.pop_front();
        }

        if (action.type == OtaActionType::Confirm) {
            processConfirmAction();
        } else {
            processCancelAction(action.cleanupFiles);
        }
    }
}

void OtaManager::processConfirmAction()
{
    const OtaRuntimeData state = m_dataManager->getLocalDeviceDataSnapshot().ota;

    // 确认前先做空间检查：库在续传时也会查剩余空间，但只在有 .meta 时兜底；
    // 空间不足时直接拒绝且不回复 0x38，模组侧会稍后重推通知
    if (state.fwSize > 0 && !m_workDir.empty()) {
        struct statvfs fsInfo = {};
        if (statvfs(m_workDir.c_str(), &fsInfo) == 0) {
            const uint64_t freeBytes =
                static_cast<uint64_t>(fsInfo.f_bavail) * fsInfo.f_frsize;
            if (freeBytes < state.fwSize + OTA_FREE_SPACE_MARGIN_BYTES) {
                LOG_ERROR("[OTA] insufficient space: free={} need={}",
                    freeBytes, state.fwSize + OTA_FREE_SPACE_MARGIN_BYTES);
                {
                    std::lock_guard<std::mutex> lock(m_publishMutex);
                    OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
                    data.available = m_available.load();
                    data.state = "failed";
                    data.commandPending = false;
                    data.lastCommandSuccess = false;
                    data.lastError = "存储空间不足，无法下载固件";
                    data.timestamp = nowMilliseconds();
                    m_dataManager->updateOtaData(data);
                }
                m_autoConfirmRequested = false;
                return;
            }
        }
    }

    // choice=1: http 边下边传（全量包较大，模组 OTA 分区存不下，Ymodem 不适用）
    if (emc6069_ota_confirm_update(1) != 0) {
        LOG_WARN("[OTA] confirm update rejected by library");
        publishActionFailure("确认升级失败，请稍后再试");
        m_autoConfirmRequested = false;
        return;
    }
    m_autoConfirmRequested = false;

    std::lock_guard<std::mutex> lock(m_publishMutex);
    OtaRuntimeData data = m_dataManager->getLocalDeviceDataSnapshot().ota;
    data.commandPending = true;
    data.lastCommandSuccess = true;
    data.state = "preparing";
    data.timestamp = nowMilliseconds();
    m_dataManager->updateOtaData(data);
}

void OtaManager::processCancelAction(bool cleanupFiles)
{
    emc6069_ota_cancel_update();
    if (cleanupFiles) {
        FileUtils::removeFile(std::string(OTA_FIRMWARE_PATH));
        FileUtils::removeFile(std::string(OTA_FIRMWARE_PATH) + ".meta");
        FileUtils::removeFile(m_workDir + "/firmware.swu");
    }
    LOG_INFO("[OTA] update notify cancelled, cleanup={}", cleanupFiles);
}
