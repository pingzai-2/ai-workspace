/**
 * 单路通信调度器接口。
 *
 * 进程只选择调度器类型，不依赖具体传输介质或协议。操作由通道封装，
 * 调度器只负责排队、串行执行和策略选择。
 */

#ifndef COMMUNICATIONSCHEDULER_H
#define COMMUNICATIONSCHEDULER_H

#include "CommunicationSchedulerType.h"
#include <chrono>
#include <cstddef>
#include <functional>
#include <memory>

class CommunicationScheduler {
public:
    using Operation = std::function<bool()>;
    using Completion = std::function<void(bool)>;

    virtual ~CommunicationScheduler() = default;

    virtual bool start() = 0;
    virtual void stop() = 0;
    virtual bool isRunning() const = 0;
    virtual std::size_t pendingReadCount() const = 0;
    virtual std::size_t pendingWriteCount() const = 0;

    virtual bool executeRead(Operation operation, std::size_t maxAttempts = 1) = 0;
    virtual bool executeWrite(Operation operation, std::size_t maxAttempts = 1) = 0;
    // 非阻塞读取入口。完成后的读取操作回到普通读队列，
    // 下一拍仍会重新选择队列，保持统一节奏。
    virtual bool submitRead(Operation operation,
        Completion completion = Completion(),
        std::size_t maxAttempts = 1) = 0;
    // 非阻塞写入入口。操作直接进入唯一的写队列，避免外层再套一层队列。
    virtual bool submitWrite(Operation operation,
        Completion completion = Completion(),
        std::size_t maxAttempts = 1) = 0;
    virtual bool executeControl(Operation operation) = 0;
};

std::unique_ptr<CommunicationScheduler> createCommunicationScheduler(
    CommunicationSchedulerType type,
    std::chrono::milliseconds commandInterval);

#endif // COMMUNICATIONSCHEDULER_H
