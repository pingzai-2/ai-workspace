#include "ModbusMasterScheduler.h"

#include <exception>
#include <utility>

CommunicationSchedulerImpl::CommunicationSchedulerImpl(
    std::chrono::milliseconds commandInterval,
    std::size_t maxPendingReads,
    std::size_t maxPendingWrites)
    : m_commandInterval(commandInterval)
    , m_maxPendingReads(maxPendingReads)
    , m_maxPendingWrites(maxPendingWrites)
    , m_running(false)
    , m_hasLastCommand(false)
{
}

CommunicationSchedulerImpl::~CommunicationSchedulerImpl()
{
    stop();
}

bool CommunicationSchedulerImpl::start()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_running) {
        return true;
    }
    if (m_workerThread.joinable()) {
        return false;
    }

    m_running = true;
    m_hasLastCommand = false;
    try {
        m_workerThread = std::thread(&CommunicationSchedulerImpl::workerLoop, this);
    } catch (...) {
        m_running = false;
        return false;
    }
    return true;
}

void CommunicationSchedulerImpl::stop()
{
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_running && !m_workerThread.joinable()) {
            return;
        }
        m_running = false;
    }
    m_cv.notify_all();

    if (m_workerThread.joinable()) {
        m_workerThread.join();
    }
    completeQueuedCommands(false);
}

bool CommunicationSchedulerImpl::isRunning() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_running;
}

std::size_t CommunicationSchedulerImpl::pendingReadCount() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_readQueue.size();
}

std::size_t CommunicationSchedulerImpl::pendingWriteCount() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_writeQueue.size();
}

bool CommunicationSchedulerImpl::executeRead(Operation operation, std::size_t maxAttempts)
{
    return execute(std::move(operation), false, true, maxAttempts);
}

bool CommunicationSchedulerImpl::executeWrite(Operation operation, std::size_t maxAttempts)
{
    return execute(std::move(operation), true, true, maxAttempts);
}

bool CommunicationSchedulerImpl::submitRead(
    Operation operation,
    Completion completion,
    std::size_t maxAttempts)
{
    return submit(std::move(operation), false, true, maxAttempts,
        nullptr, std::move(completion));
}

bool CommunicationSchedulerImpl::submitWrite(
    Operation operation,
    Completion completion,
    std::size_t maxAttempts)
{
    return submit(std::move(operation), true, true, maxAttempts,
        nullptr, std::move(completion));
}

bool CommunicationSchedulerImpl::executeControl(Operation operation)
{
    return execute(std::move(operation), true, false, 1);
}

bool CommunicationSchedulerImpl::execute(
    Operation operation,
    bool writePriority,
    bool respectCommandInterval,
    std::size_t maxAttempts)
{
    if (!operation || maxAttempts == 0) {
        return false;
    }

    auto promise = std::make_shared<std::promise<bool>>();
    std::future<bool> result = promise->get_future();
    if (!submit(std::move(operation), writePriority, respectCommandInterval,
            maxAttempts, promise, Completion())) {
        return false;
    }
    return result.get();
}

bool CommunicationSchedulerImpl::submit(
    Operation operation,
    bool writePriority,
    bool respectCommandInterval,
    std::size_t maxAttempts,
    std::shared_ptr<std::promise<bool>> promise,
    Completion completion)
{
    if (!operation || maxAttempts == 0) {
        return false;
    }

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_running) {
            return false;
        }

        auto& queue = writePriority ? m_writeQueue : m_readQueue;
        const std::size_t limit = writePriority ? m_maxPendingWrites : m_maxPendingReads;
        if (queue.size() >= limit) {
            return false;
        }

        queue.push_back(std::make_shared<Command>(
            std::move(operation), respectCommandInterval, writePriority,
            maxAttempts, std::move(promise), std::move(completion)));
    }
    m_cv.notify_one();
    return true;
}

void CommunicationSchedulerImpl::workerLoop()
{
    while (true) {
        std::shared_ptr<Command> command;
        {
            std::unique_lock<std::mutex> lock(m_mutex);
            m_cv.wait(lock, [this]() {
                return !m_running || !m_writeQueue.empty() || !m_readQueue.empty();
            });
            if (!m_running) {
                break;
            }
            command = selectReadyCommand(lock);
            if (!command) {
                continue;
            }
        }

        bool success = false;
        try {
            success = command->operation();
        } catch (const std::exception&) {
            success = false;
        } catch (...) {
            success = false;
        }

        bool retryQueued = false;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (command->respectCommandInterval) {
                m_lastCommandFinishedAt = std::chrono::steady_clock::now();
                m_hasLastCommand = true;
            }
            if (!success && command->remainingAttempts > 1 && m_running) {
                --command->remainingAttempts;
                auto& queue = command->writePriority ? m_writeQueue : m_readQueue;
                queue.push_front(command);
                retryQueued = true;
            }
        }
        if (retryQueued) {
            m_cv.notify_one();
            continue;
        }
        completeCommand(command, success);
    }
}

std::shared_ptr<CommunicationSchedulerImpl::Command>
CommunicationSchedulerImpl::selectReadyCommand(std::unique_lock<std::mutex>& lock)
{
    while (m_running) {
        std::shared_ptr<Command> candidate;
        if (prioritizeWrites()) {
            candidate = !m_writeQueue.empty()
                ? m_writeQueue.front()
                : (!m_readQueue.empty() ? m_readQueue.front() : nullptr);
        } else {
            candidate = !m_readQueue.empty()
                ? m_readQueue.front()
                : (!m_writeQueue.empty() ? m_writeQueue.front() : nullptr);
        }
        if (!candidate) {
            return nullptr;
        }

        if (candidate->respectCommandInterval && m_hasLastCommand) {
            const auto readyAt = m_lastCommandFinishedAt + m_commandInterval;
            if (std::chrono::steady_clock::now() < readyAt) {
                // 等待间隔期间不预先取走读任务。若新写入队，唤醒后会重新选择，
                // 从而保证“下一次读开始前再次检查写队列”。
                m_cv.wait_until(lock, readyAt);
                continue;
            }
        }

        if (prioritizeWrites() ? !m_writeQueue.empty() : m_readQueue.empty()) {
            candidate = m_writeQueue.front();
            m_writeQueue.pop_front();
        } else {
            candidate = m_readQueue.front();
            m_readQueue.pop_front();
        }
        return candidate;
    }
    return nullptr;
}

void CommunicationSchedulerImpl::completeQueuedCommands(bool result)
{
    std::deque<std::shared_ptr<Command>> reads;
    std::deque<std::shared_ptr<Command>> writes;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        reads.swap(m_readQueue);
        writes.swap(m_writeQueue);
    }

    for (const auto& command : writes) {
        completeCommand(command, result);
    }
    for (const auto& command : reads) {
        completeCommand(command, result);
    }
}

void CommunicationSchedulerImpl::completeCommand(
    const std::shared_ptr<Command>& command,
    bool result)
{
    if (command->promise) {
        command->promise->set_value(result);
    }
    if (command->completion) {
        try {
            command->completion(result);
        } catch (...) {
            // 完成通知不能破坏唯一的 TTY 调度线程。
        }
    }
}
