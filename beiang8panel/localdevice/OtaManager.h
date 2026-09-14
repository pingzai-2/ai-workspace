/**
 * OTA 管理模块。
 *
 * 整机固件升级链路（R818 AB 方案）：
 *   云端 -> emc6069 模组(YAT 0x31~0x39) -> libemc6069 收流+校验
 *   -> rename 为 swu -> swupdate_cmd.sh 写另一槽位 -> 自动重启(失败 AB 回滚)
 *
 * 本模块持有模组串口（emc6069_init 后常驻，模组可随时推送 0x38 升级通知），
 * 把库事件翻译为 OtaRuntimeData 发布到 DataManager，并对外提供
 * 确认下载/取消通知/清理文件三个动作，供 HTTP 层调用。
 *
 * 库回调在 OTA 接收线程上下文执行，回调内只做状态发布和日志，禁止阻塞。
 */

#ifndef OTAMANAGER_H
#define OTAMANAGER_H

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <functional>
#include <thread>

class DataManager;

class OtaManager {
public:
    explicit OtaManager(DataManager* dataManager);
    ~OtaManager();

    bool start();
    // 0x11模组网络连接成功(含掉线自动重连)时在库接收线程上下文调用。
    // 回调内只做轻量转发(如向WifiManager投递时间同步命令), 禁止阻塞。
    void setNetConnectedCallback(std::function<void()> callback);
    void stop();
    bool isRunning() const { return m_running.load(); }
    bool isAvailable() const { return m_available.load(); }

    // “立即更新/重试”入口。有 0x38 待确认通知时立即回复模组开始 http 下载；
    // 否则（下载失败后重试）置为待自动确认，模组重推通知时不再打扰用户，
    // 直接进入下载。返回 false 表示当前状态不接受该操作，error 给出原因。
    bool startDownload(std::string& error);

    // “下次再说”（清理已下载文件为 false）/“退出”（清理为 true）。
    // 取消后更新按钮仍保持高亮（updateAvailable 不复位），与产品流程一致。
    bool cancelDownload(bool cleanupFiles, std::string& error);

private:
    // 动作队列：库调用一律在本动作线程执行，绝不进库回调线程或 HTTP 线程
    enum class OtaActionType {
        Confirm,
        Cancel
    };
    struct OtaAction {
        OtaActionType type = OtaActionType::Confirm;
        bool cleanupFiles = false;
    };

    std::function<void()> m_netConnectedCallback; // 0x11连接成功回调钩子

    // 库回调（静态转发到成员，参数经 void* 解耦 emc6069.h）
    static void otaEventCallbackTrampoline(int evt, const void* data, void* userData);
    static void netStatusCallbackTrampoline(int status, void* userData);


    void handleOtaEvent(int evt, const void* eventData);
    void actionLoop();
    void processConfirmAction();
    void processCancelAction(bool cleanupFiles);
    void publishActionFailure(const std::string& error);
    std::string readCurrentVersion() const;

    DataManager* m_dataManager;
    std::atomic<bool> m_running;
    std::atomic<bool> m_available;
    // 库回调线程与 HTTP 线程都会读改写 OTA 状态，串行化以避免丢更新
    std::mutex m_publishMutex;
    std::mutex m_actionMutex;
    std::thread m_actionThread;
    std::atomic<bool> m_stopRequested;
    std::mutex m_queueMutex;
    std::condition_variable m_queueCondition;
    std::deque<OtaAction> m_queue;
    int m_listenerHandle = -1;

    // “重试”后等待模组重推 0x38 期间自动确认，不再弹二次确认
    std::atomic<bool> m_autoConfirmRequested;

    std::string m_serialPort;
    int m_baudRate = 115200;
    std::string m_workDir;
    std::string m_currentVersion;
};

#endif // OTAMANAGER_H