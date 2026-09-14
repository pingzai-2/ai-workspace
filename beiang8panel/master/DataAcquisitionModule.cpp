/**
 * 设备数据采集模块实现
 */

#include "DataAcquisitionModule.h"
#include "common/GlobalFunction.h"
#include "common/LogManager.h"
#include <algorithm>
#include <chrono>
#include <cstring>
#include <iostream>

using namespace std;

DataAcquisitionModule::DataAcquisitionModule(DataManager* dataManager)
    : m_dataManager(dataManager)
    , m_gateway(nullptr)
    , m_isRunning(false)
    , m_hasPendingRawSnapshot(false)
    , m_successCount(0)
    , m_failureCount(0)
    , m_consecutiveFailures(0)
    , m_lastAcquisitionTime(0)
    , m_reconnectBackoffMs(RECONNECT_BACKOFF_BASE_MS)
    , m_nodeMissingFailureCount(0)
    , m_pollIntervalMs(DEFAULT_DATA_ACQUISITION_INTERVAL_MS)
    , m_pollBackoffActive(false)
    , m_consecutiveSuccesses(0)
{
    // Gateway 将在 start() 时从 DataManager 获取
}

DataAcquisitionModule::~DataAcquisitionModule()
{
    stop();
}

bool DataAcquisitionModule::start()
{
    if (m_isRunning) {
        LOG_WARNING("[DataAcquisitionModule] Already running");
        return true;
    }

    // 从 DataManager 获取共享的 Gateway
    m_gateway = m_dataManager->getGateway();
    if (!m_gateway) {
        LOG_ERROR("[DataAcquisitionModule] Failed to get Gateway from DataManager");
        return false;
    }

    m_isRunning = true;
    m_successCount = 0;
    m_failureCount = 0;
    m_consecutiveFailures = 0;
    m_reconnectBackoffMs = RECONNECT_BACKOFF_BASE_MS;
    m_nodeMissingFailureCount = 0;
    m_pollIntervalMs = m_config.intervalMs;
    m_pollBackoffActive = false;
    m_consecutiveSuccesses = 0;
    {
        lock_guard<mutex> lock(m_snapshotMutex);
        m_hasPendingRawSnapshot = false;
    }

    // 通信与数据处理分离：通信线程只采原始快照，处理线程负责解析和更新 DataManager。
    m_processingThread = thread(&DataAcquisitionModule::processingLoop, this);
    m_acquisitionThread = thread(&DataAcquisitionModule::acquisitionLoop, this);

    LOG_INFO("[DataAcquisitionModule] Started data acquisition");
    return true;
}

void DataAcquisitionModule::stop()
{
    if (!m_isRunning) {
        return;
    }

    m_isRunning = false;
    m_pollCv.notify_all();
    m_snapshotCv.notify_all();

    if (m_acquisitionThread.joinable()) {
        m_acquisitionThread.join();
    }
    if (m_processingThread.joinable()) {
        m_processingThread.join();
    }

    m_gateway = nullptr;

    LOG_INFO("[DataAcquisitionModule] Stopped data acquisition. Total: {} success, {} failures",
        m_successCount, m_failureCount);
}

void DataAcquisitionModule::acquisitionLoop()
{
    while (m_isRunning) {
        // 执行数据采集
        bool success = performAcquisition();

        bool recovered = false;
        int waitMs = m_config.intervalMs;
        {
            lock_guard<mutex> lock(m_mutex);
            if (success) {
                m_successCount++;
                m_consecutiveFailures = 0;
                m_consecutiveSuccesses++;
            } else {
                m_failureCount++;
                m_consecutiveFailures++;
                m_consecutiveSuccesses = 0;
            }
        }
        if (!success) {
            recovered = handleAcquisitionFailure();
        }

        {
            lock_guard<mutex> lock(m_mutex);
            // 故障爆发期降频/恢复（迟滞 + 逐档回退）。
            if (success) {
                if (m_pollIntervalMs != m_config.intervalMs &&
                    m_consecutiveSuccesses >= POLL_BACKOFF_RECOVER_STREAK) {
                    const int lower = std::max(m_config.intervalMs, m_pollIntervalMs / 2);
                    m_pollIntervalMs = lower;
                    m_consecutiveSuccesses = 0;
                    if (lower == m_config.intervalMs) {
                        m_pollBackoffActive = false;
                        LOG_INFO("[DataAcquisition] Poll interval restored to {}ms", m_pollIntervalMs);
                    } else {
                        LOG_INFO("[DataAcquisition] Poll interval reduced to {}ms", m_pollIntervalMs);
                    }
                } else if (m_pollIntervalMs == m_config.intervalMs) {
                    m_consecutiveSuccesses = 0;
                }
            } else if (!recovered) {
                const int newInterval = std::min(
                    m_pollIntervalMs * 2, DATA_ACQUISITION_POLL_BACKOFF_MAX_MS);
                if (!m_pollBackoffActive && newInterval > m_config.intervalMs) {
                    m_pollBackoffActive = true;
                    LOG_WARNING("[DataAcquisition] Failure burst detected, backing off poll interval "
                        "{}ms -> {}ms (max {}ms)",
                        m_pollIntervalMs, newInterval, DATA_ACQUISITION_POLL_BACKOFF_MAX_MS);
                }
                m_pollIntervalMs = newInterval;
            }
            waitMs = m_pollIntervalMs;
        }

        unique_lock<mutex> lock(m_mutex);
        m_pollCv.wait_for(lock, chrono::milliseconds(waitMs), [this]() {
            return !m_isRunning;
        });
    }
}

bool DataAcquisitionModule::performAcquisition()
{
    try {
        // 通信快路径：只读取原始寄存器并发布快照，不解析、不持有 DataManager 锁。
        BeiAng4CPGateway::RawRegisterCache rawCache;
        const bool success = m_gateway->readRawDeviceData(rawCache);
        if (success) {
            publishRawSnapshot(rawCache);
        }

        m_lastAcquisitionTime = TimeUtils::getCurrentTimestampMs();

        if (success) {
            LOG_DEBUG("[DataAcquisition] Data acquired successfully at {}",
                TimeUtils::timestampToString(m_lastAcquisitionTime));
        }

        return success;

    } catch (const exception& e) {
        LOG_ERROR("[DataAcquisition] Exception: {}", e.what());
        return false;
    }
}

void DataAcquisitionModule::publishRawSnapshot(
    const BeiAng4CPGateway::RawRegisterCache& rawCache)
{
    {
        lock_guard<mutex> lock(m_snapshotMutex);
        m_pendingRawSnapshot = rawCache;
        m_hasPendingRawSnapshot = true;
    }
    m_snapshotCv.notify_one();
}

void DataAcquisitionModule::processingLoop()
{
    while (true) {
        BeiAng4CPGateway::RawRegisterCache rawCache;
        {
            unique_lock<mutex> lock(m_snapshotMutex);
            m_snapshotCv.wait(lock, [this]() {
                return !m_isRunning || m_hasPendingRawSnapshot;
            });
            if (!m_hasPendingRawSnapshot && !m_isRunning) {
                return;
            }
            rawCache = m_pendingRawSnapshot;
            m_hasPendingRawSnapshot = false;
        }
        processRawSnapshot(rawCache);
    }
}

bool DataAcquisitionModule::processRawSnapshot(
    const BeiAng4CPGateway::RawRegisterCache& rawCache)
{
    GatewayGeneralDataStructure parsedData;
    if (!m_gateway->parseRawDeviceData(rawCache, parsedData)) {
        LOG_ERROR("[DataProcessing] Failed to parse raw Modbus snapshot: {}",
            m_gateway->getLastErrorMessage());
        return false;
    }

    // 仍只更新 DataManager 内存，不新增落盘；同一轮语义值和原始值原子发布。
    m_dataManager->publishModbusSnapshot(
        parsedData, rawCache, TimeUtils::getCurrentTimestampMs());
    return true;
}

bool DataAcquisitionModule::handleAcquisitionFailure()
{
    if (m_consecutiveFailures < m_config.maxRetryCount) {
        return false;
    }
    if (!m_config.autoReconnect) {
        return false;
    }

    LOG_WARNING("[DataAcquisition] Too many consecutive failures ({}), attempting reconnection...",
        m_consecutiveFailures);

    // 真正重建底层串口连接（此前仅将指针置空后取回缓存对象，从未重新 connect，
    // 失效的 fd 继续复用导致"重连成功"后仍持续失败）
    bool ok = m_gateway ? m_gateway->reconnect() : false;

    // connect 成功仅代表串口打开，不等于设备在线；用一次真实读取探测链路是否恢复
    // 探测读取不更新缓存（探测成功≠链路稳定，由后续采集循环全量更新）
    // 使用临时数据结构，不持有 m_dataMutex 以避免阻塞 HTTP 请求
    if (ok) {
        this_thread::sleep_for(chrono::milliseconds(200));
        if (m_gateway) {
            BeiAng4CPGateway::RawRegisterCache probeData;
            ok = m_gateway->readRawDeviceData(probeData);
        } else {
            ok = false;
        }
    }

    if (ok) {
        // 链路恢复：重置退避状态与失败计数。注意：不在此恢复轮询间隔——
        // 探测成功仅代表链路瞬时恢复，不代表稳定，由采集循环的迟滞逻辑
        // （连续成功 POLL_BACKOFF_RECOVER_STREAK 次）逐步回退档位。
        m_consecutiveFailures = 0;
        m_reconnectBackoffMs = RECONNECT_BACKOFF_BASE_MS;
        m_nodeMissingFailureCount = 0;
        LOG_INFO("[DataAcquisition] Reconnected successfully");
        return true;
    }

    // 未恢复：清零连续失败计数，等待再次累积到阈值后重试，避免假成功刷屏
    // 重试节奏 ≈ maxRetryCount × intervalMs（默认 5s）
    m_consecutiveFailures = 0;

    // 区分失败性质：串口节点消失或无法重新占用时停止本路；
    // 其它失败（设备无响应/CRC等）仍维持原有重试节奏。
    bool nodeMissing = m_gateway && m_gateway->isSerialNodeMissing();
    if (nodeMissing) {
        // endpoint 已消失或无法重新占用时停止本路采集；不在后台持续重连，
        // 避免端点异常时反复触碰设备。HTTP 进程仍可提供诊断状态，重启进程后重试。
        LOG_ERROR("[DataAcquisition] Serial endpoint unavailable (errno={}); acquisition stopped",
            m_gateway->getLastConnectErrno());
        m_isRunning = false;
        m_pollCv.notify_all();
        m_snapshotCv.notify_all();
    } else {
        m_reconnectBackoffMs = RECONNECT_BACKOFF_BASE_MS;
        m_nodeMissingFailureCount = 0;
        LOG_WARNING("[DataAcquisition] Reconnection not recovered, will retry after {} failures",
            m_config.maxRetryCount);
    }

    return false;
}
