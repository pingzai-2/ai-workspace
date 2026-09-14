/**
 * 通用通信事务调度器实现。
 *
 * 调度器只负责操作入队、串行执行、间隔和读写优先级，不依赖具体传输
 * 介质或协议。当前文件名和 ModbusMasterScheduler 名称保留给进程 1 的
 * 既有实现，避免破坏现有调用方；新进程使用下方的通用实现类型。
 */

#ifndef MODBUSMASTERSCHEDULER_H
#define MODBUSMASTERSCHEDULER_H

#include "CommunicationScheduler.h"
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <thread>

class CommunicationSchedulerImpl : public CommunicationScheduler {
public:
    explicit CommunicationSchedulerImpl(
        std::chrono::milliseconds commandInterval,
        std::size_t maxPendingReads = 128,
        std::size_t maxPendingWrites = 128);
    ~CommunicationSchedulerImpl() override;

    bool start() override;
    void stop() override;
    bool isRunning() const override;
    std::size_t pendingReadCount() const override;
    std::size_t pendingWriteCount() const override;

    bool executeRead(Operation operation, std::size_t maxAttempts = 1) override;
    bool executeWrite(Operation operation, std::size_t maxAttempts = 1) override;
    bool submitRead(Operation operation,
        Completion completion = Completion(),
        std::size_t maxAttempts = 1) override;
    bool submitWrite(Operation operation,
        Completion completion = Completion(),
        std::size_t maxAttempts = 1) override;
    bool executeControl(Operation operation) override;

protected:
    // 调度策略只决定读写队列的选择顺序，实际操作由通道回调提供。
    virtual bool prioritizeWrites() const { return true; }

private:
    struct Command {
        Command(Operation commandOperation,
                bool useInterval,
                bool useWritePriority,
                std::size_t attempts,
                std::shared_ptr<std::promise<bool>> resultPromise,
                Completion resultCompletion)
            : operation(std::move(commandOperation))
            , respectCommandInterval(useInterval)
            , writePriority(useWritePriority)
            , remainingAttempts(attempts)
            , promise(std::move(resultPromise))
            , completion(std::move(resultCompletion))
        {
        }

        Operation operation;
        bool respectCommandInterval;
        bool writePriority;
        std::size_t remainingAttempts;
        std::shared_ptr<std::promise<bool>> promise;
        Completion completion;
    };

    bool execute(Operation operation,
                 bool writePriority,
                 bool respectCommandInterval,
                 std::size_t maxAttempts);
    bool submit(Operation operation,
        bool writePriority,
        bool respectCommandInterval,
        std::size_t maxAttempts,
        std::shared_ptr<std::promise<bool>> promise,
        Completion completion);
    void workerLoop();
    std::shared_ptr<Command> selectReadyCommand(std::unique_lock<std::mutex>& lock);
    void completeQueuedCommands(bool result);
    static void completeCommand(const std::shared_ptr<Command>& command, bool result);

    const std::chrono::milliseconds m_commandInterval;
    const std::size_t m_maxPendingReads;
    const std::size_t m_maxPendingWrites;

    mutable std::mutex m_mutex;
    std::condition_variable m_cv;
    std::deque<std::shared_ptr<Command>> m_readQueue;
    std::deque<std::shared_ptr<Command>> m_writeQueue;
    std::thread m_workerThread;
    bool m_running;
    bool m_hasLastCommand;
    std::chrono::steady_clock::time_point m_lastCommandFinishedAt;
};

// 进程 1 的兼容类型。后续替换具体协议时，只需替换这个入口的实现。
class ModbusMasterScheduler final : public CommunicationSchedulerImpl {
public:
    explicit ModbusMasterScheduler(
        std::chrono::milliseconds commandInterval,
        std::size_t maxPendingReads = 128,
        std::size_t maxPendingWrites = 128)
        : CommunicationSchedulerImpl(
            commandInterval, maxPendingReads, maxPendingWrites) {}
};

class CommunicationScheduler2 final : public CommunicationSchedulerImpl {
public:
    explicit CommunicationScheduler2(std::chrono::milliseconds commandInterval)
        : CommunicationSchedulerImpl(commandInterval) {}
};

class CommunicationScheduler3 final : public CommunicationSchedulerImpl {
public:
    explicit CommunicationScheduler3(std::chrono::milliseconds commandInterval)
        : CommunicationSchedulerImpl(commandInterval) {}

protected:
    bool prioritizeWrites() const override { return false; }
};

class CommunicationScheduler4 final : public CommunicationSchedulerImpl {
public:
    explicit CommunicationScheduler4(std::chrono::milliseconds commandInterval)
        : CommunicationSchedulerImpl(commandInterval) {}
};

#endif // MODBUSMASTERSCHEDULER_H
