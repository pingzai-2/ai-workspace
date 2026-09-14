#include "ModbusMasterScheduler.h"

#include <chrono>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

using namespace std::chrono_literals;

bool waitForCount(const std::function<std::size_t()>& count, std::size_t expected)
{
    const auto deadline = std::chrono::steady_clock::now() + 1s;
    while (std::chrono::steady_clock::now() < deadline) {
        if (count() >= expected) {
            return true;
        }
        std::this_thread::sleep_for(1ms);
    }
    return false;
}

bool testCurrentReadFinishesThenWritesDrainBeforeNextRead()
{
    ModbusMasterScheduler scheduler(40ms);
    if (!scheduler.start()) {
        return false;
    }

    std::mutex orderMutex;
    std::condition_variable readStartedCv;
    std::condition_variable releaseReadCv;
    bool readStarted = false;
    bool releaseRead = false;
    std::vector<std::string> order;
    auto record = [&](const std::string& value) {
        std::lock_guard<std::mutex> lock(orderMutex);
        order.push_back(value);
    };

    std::thread activeRead([&]() {
        scheduler.executeRead([&]() {
            record("read-1-start");
            {
                std::lock_guard<std::mutex> lock(orderMutex);
                readStarted = true;
            }
            readStartedCv.notify_one();
            std::unique_lock<std::mutex> lock(orderMutex);
            releaseReadCv.wait(lock, [&]() { return releaseRead; });
            order.push_back("read-1-end");
            return true;
        });
    });

    {
        std::unique_lock<std::mutex> lock(orderMutex);
        if (!readStartedCv.wait_for(lock, 1s, [&]() { return readStarted; })) {
            scheduler.stop();
            activeRead.join();
            return false;
        }
    }

    std::thread nextRead([&]() {
        scheduler.executeRead([&]() {
            record("read-2");
            return true;
        });
    });
    bool queuesObserved = waitForCount([&]() { return scheduler.pendingReadCount(); }, 1);

    std::thread writeA([&]() {
        scheduler.executeWrite([&]() {
            record("write-a");
            return true;
        });
    });
    queuesObserved = waitForCount([&]() { return scheduler.pendingWriteCount(); }, 1)
        && queuesObserved;
    std::thread writeB([&]() {
        scheduler.executeWrite([&]() {
            record("write-b");
            return true;
        });
    });
    queuesObserved = waitForCount([&]() { return scheduler.pendingWriteCount(); }, 2)
        && queuesObserved;

    {
        std::lock_guard<std::mutex> lock(orderMutex);
        releaseRead = true;
    }
    releaseReadCv.notify_one();

    activeRead.join();
    writeA.join();
    writeB.join();
    nextRead.join();
    scheduler.stop();

    if (!queuesObserved) {
        std::cerr << "scheduler queues were not observable before releasing active read" << std::endl;
        return false;
    }

    const std::vector<std::string> expected {
        "read-1-start", "read-1-end", "write-a", "write-b", "read-2"
    };
    if (order != expected) {
        std::cerr << "unexpected order:";
        for (const auto& item : order) {
            std::cerr << ' ' << item;
        }
        std::cerr << std::endl;
        return false;
    }
    return true;
}

bool testWriteArrivingDuringIntervalBeatsQueuedRead()
{
    ModbusMasterScheduler scheduler(40ms);
    if (!scheduler.start()) {
        return false;
    }

    std::mutex orderMutex;
    std::vector<std::string> order;
    auto record = [&](const std::string& value) {
        std::lock_guard<std::mutex> lock(orderMutex);
        order.push_back(value);
    };

    if (!scheduler.executeRead([&]() {
            record("read-1");
            return true;
        })) {
        scheduler.stop();
        return false;
    }

    std::thread nextRead([&]() {
        scheduler.executeRead([&]() {
            record("read-2");
            return true;
        });
    });
    const bool readQueued = waitForCount([&]() { return scheduler.pendingReadCount(); }, 1);

    std::thread write([&]() {
        scheduler.executeWrite([&]() {
            record("write");
            return true;
        });
    });

    nextRead.join();
    write.join();
    scheduler.stop();

    const std::vector<std::string> expected {"read-1", "write", "read-2"};
    if (!readQueued || order != expected) {
        std::cerr << "write did not preempt queued read during command interval" << std::endl;
        return false;
    }
    return true;
}

bool testRetryReturnsToPulseAndAllowsWriteToRunFirst()
{
    constexpr auto commandInterval = 40ms;
    ModbusMasterScheduler scheduler(commandInterval);
    if (!scheduler.start()) {
        return false;
    }

    std::mutex mutex;
    std::condition_variable firstAttemptCv;
    bool firstAttemptFinished = false;
    int readAttempts = 0;
    std::vector<std::string> order;
    std::vector<std::chrono::steady_clock::time_point> startedAt;
    auto record = [&](const std::string& value) {
        std::lock_guard<std::mutex> lock(mutex);
        order.push_back(value);
        startedAt.push_back(std::chrono::steady_clock::now());
    };

    std::thread read([&]() {
        scheduler.executeRead([&]() {
            ++readAttempts;
            record(readAttempts == 1 ? "read-1" : "read-2");
            if (readAttempts == 1) {
                {
                    std::lock_guard<std::mutex> lock(mutex);
                    firstAttemptFinished = true;
                }
                firstAttemptCv.notify_one();
                return false;
            }
            return true;
        }, 2);
    });

    {
        std::unique_lock<std::mutex> lock(mutex);
        if (!firstAttemptCv.wait_for(lock, 1s, [&]() { return firstAttemptFinished; })) {
            scheduler.stop();
            read.join();
            return false;
        }
    }

    std::thread write([&]() {
        scheduler.executeWrite([&]() {
            record("write");
            return true;
        });
    });

    read.join();
    write.join();
    scheduler.stop();

    const std::vector<std::string> expected {"read-1", "write", "read-2"};
    if (order != expected || startedAt.size() != expected.size()) {
        std::cerr << "retry did not return to the write-preferring pulse queue" << std::endl;
        return false;
    }
    const auto minimumObservedInterval = commandInterval - 5ms;
    if (startedAt[1] - startedAt[0] < minimumObservedInterval ||
        startedAt[2] - startedAt[1] < minimumObservedInterval) {
        std::cerr << "read/write/retry did not share the command interval" << std::endl;
        return false;
    }
    return true;
}

bool testAsyncWritesShareTheOnlyPriorityQueue()
{
    ModbusMasterScheduler scheduler(20ms);
    if (!scheduler.start()) {
        return false;
    }

    std::mutex mutex;
    std::condition_variable readStartedCv;
    std::condition_variable releaseReadCv;
    std::condition_variable writesCompletedCv;
    bool readStarted = false;
    bool releaseRead = false;
    int writesCompleted = 0;
    std::vector<std::string> order;

    std::thread activeRead([&]() {
        scheduler.executeRead([&]() {
            std::unique_lock<std::mutex> lock(mutex);
            order.push_back("read-1");
            readStarted = true;
            readStartedCv.notify_one();
            releaseReadCv.wait(lock, [&]() { return releaseRead; });
            return true;
        });
    });

    {
        std::unique_lock<std::mutex> lock(mutex);
        if (!readStartedCv.wait_for(lock, 1s, [&]() { return readStarted; })) {
            scheduler.stop();
            activeRead.join();
            return false;
        }
    }

    auto completeWrite = [&](bool success) {
        std::lock_guard<std::mutex> lock(mutex);
        if (success) {
            ++writesCompleted;
        }
        writesCompletedCv.notify_one();
    };
    const bool submittedA = scheduler.submitWrite([&]() {
        std::lock_guard<std::mutex> lock(mutex);
        order.push_back("write-a");
        return true;
    }, completeWrite);
    const bool submittedB = scheduler.submitWrite([&]() {
        std::lock_guard<std::mutex> lock(mutex);
        order.push_back("write-b");
        return true;
    }, completeWrite);

    std::thread nextRead([&]() {
        scheduler.executeRead([&]() {
            std::lock_guard<std::mutex> lock(mutex);
            order.push_back("read-2");
            return true;
        });
    });

    {
        std::lock_guard<std::mutex> lock(mutex);
        releaseRead = true;
    }
    releaseReadCv.notify_one();
    activeRead.join();

    bool completed = false;
    {
        std::unique_lock<std::mutex> lock(mutex);
        completed = writesCompletedCv.wait_for(
            lock, 2s, [&]() { return writesCompleted == 2; });
    }
    nextRead.join();
    scheduler.stop();

    const std::vector<std::string> expected {
        "read-1", "write-a", "write-b", "read-2"
    };
    return submittedA && submittedB && completed && order == expected;
}

bool testWriteCompletionReadbackReturnsToNormalReadQueue()
{
    ModbusMasterScheduler scheduler(10ms);
    if (!scheduler.start()) {
        return false;
    }

    std::mutex mutex;
    std::condition_variable writeStartedCv;
    std::condition_variable releaseWriteCv;
    std::condition_variable readbackCompletedCv;
    bool writeStarted = false;
    bool releaseWrite = false;
    bool readbackCompleted = false;
    std::vector<std::string> order;

    const bool submittedA = scheduler.submitWrite(
        [&]() {
            std::unique_lock<std::mutex> lock(mutex);
            order.push_back("write-a");
            writeStarted = true;
            writeStartedCv.notify_one();
            releaseWriteCv.wait(lock, [&]() { return releaseWrite; });
            return true;
        },
        [&](bool success) {
            if (!success) {
                return;
            }
            scheduler.submitRead(
                [&]() {
                    std::lock_guard<std::mutex> lock(mutex);
                    order.push_back("readback-a");
                    return true;
                },
                [&](bool readbackSuccess) {
                    std::lock_guard<std::mutex> lock(mutex);
                    readbackCompleted = readbackSuccess;
                    readbackCompletedCv.notify_one();
                });
        });

    {
        std::unique_lock<std::mutex> lock(mutex);
        if (!submittedA || !writeStartedCv.wait_for(
                lock, 1s, [&]() { return writeStarted; })) {
            scheduler.stop();
            return false;
        }
    }

    const bool submittedB = scheduler.submitWrite([&]() {
        std::lock_guard<std::mutex> lock(mutex);
        order.push_back("write-b");
        return true;
    });

    {
        std::lock_guard<std::mutex> lock(mutex);
        releaseWrite = true;
    }
    releaseWriteCv.notify_one();

    bool completed = false;
    {
        std::unique_lock<std::mutex> lock(mutex);
        completed = readbackCompletedCv.wait_for(
            lock, 2s, [&]() { return readbackCompleted; });
    }
    scheduler.stop();

    const std::vector<std::string> expected {
        "write-a", "write-b", "readback-a"
    };
    if (!submittedB || !completed || order != expected) {
        std::cerr << "write readback bypassed write priority" << std::endl;
        return false;
    }
    return true;
}

} // namespace

int main()
{
    if (!testCurrentReadFinishesThenWritesDrainBeforeNextRead()) {
        return 1;
    }
    if (!testWriteArrivingDuringIntervalBeatsQueuedRead()) {
        return 1;
    }
    if (!testRetryReturnsToPulseAndAllowsWriteToRunFirst()) {
        return 1;
    }
    if (!testAsyncWritesShareTheOnlyPriorityQueue()) {
        return 1;
    }
    if (!testWriteCompletionReadbackReturnsToNormalReadQueue()) {
        return 1;
    }
    std::cout << "ModbusMasterScheduler tests passed" << std::endl;
    return 0;
}
