/**
 * 设备数据采集模块
 *
 * 负责周期性从设备网关读取数据
 */

#ifndef DATAACQUISITIONMODULE_H
#define DATAACQUISITIONMODULE_H

#include <atomic>
#include <condition_variable>
#include <thread>
#include <memory>
#include <mutex>
#include "DataManager.h"
#include "gateways/BeiAng4CPGateway.h"

// 采集配置
struct AcquisitionConfig {
    int intervalMs;              // 采集间隔(毫秒)
    int maxRetryCount;           // 最大重试次数
    bool autoReconnect;          // 自动重连

    AcquisitionConfig()
        : intervalMs(DEFAULT_DATA_ACQUISITION_INTERVAL_MS)
        , maxRetryCount(MAX_DATA_ACQUISITION_FAILURE_COUNT)
        , autoReconnect(true)
    {}
};

// 数据采集模块类
class DataAcquisitionModule {
public:
    explicit DataAcquisitionModule(DataManager* dataManager);
    ~DataAcquisitionModule();

    // 启动/停止
    bool start();
    void stop();
    bool isRunning() const { return m_isRunning; }

    // 配置
    AcquisitionConfig& getConfig() { return m_config; }
    const AcquisitionConfig& getConfig() const { return m_config; }

    // 状态获取
    int getSuccessCount() const { return m_successCount; }
    int getFailureCount() const { return m_failureCount; }
    int64_t getLastAcquisitionTime() const { return m_lastAcquisitionTime; }

private:
    // 采集线程
    void acquisitionLoop();
    void processingLoop();

    // 执行数据采集
    bool performAcquisition();
    void publishRawSnapshot(const BeiAng4CPGateway::RawRegisterCache& rawCache);
    bool processRawSnapshot(const BeiAng4CPGateway::RawRegisterCache& rawCache);

    // 处理采集失败；返回 true 表示本次处理中链路已恢复（重连+探测成功）
    bool handleAcquisitionFailure();

    // 数据管理器
    DataManager* m_dataManager;

    // 设备网关（引用 DataManager 的 Gateway）
    BeiAng4CPGateway* m_gateway;

    // 配置
    AcquisitionConfig m_config;

    // 状态
    std::atomic<bool> m_isRunning;
    std::thread m_acquisitionThread;
    std::thread m_processingThread;

    // 通信线程只覆盖写入最新原始快照；处理线程来不及消费时，旧状态由新状态替换。
    std::mutex m_snapshotMutex;
    std::condition_variable m_snapshotCv;
    BeiAng4CPGateway::RawRegisterCache m_pendingRawSnapshot;
    bool m_hasPendingRawSnapshot;

    // 统计
    int m_successCount;
    int m_failureCount;
    int m_consecutiveFailures;
    int64_t m_lastAcquisitionTime;

    // 串口节点消失时的重连退避状态
    int m_reconnectBackoffMs;      // 当前退避间隔（累计到 RECONNECT_BACKOFF_MAX_MS）
    int m_nodeMissingFailureCount; // 连续"节点消失"类失败的次数，决定退避档位

    // 故障爆发期轮询降频状态
    int m_pollIntervalMs;          // 当前生效的轮询间隔（正常=m_config.intervalMs，故障期逐步放大）
    bool m_pollBackoffActive;      // 是否处于降频状态（用于控制降频/恢复日志只打一次）
    int m_consecutiveSuccesses;    // 连续"干净成功"次数，达到 POLL_BACKOFF_RECOVER_STREAK 才降一档（迟滞恢复）

    // 互斥锁
    std::mutex m_mutex;
    std::condition_variable m_pollCv;
};

#endif // DATAACQUISITIONMODULE_H
