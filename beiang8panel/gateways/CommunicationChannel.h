#ifndef COMMUNICATIONCHANNEL_H
#define COMMUNICATIONCHANNEL_H

#include "CommunicationScheduler.h"
#include "SerialCommunication.h"
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

class CommunicationChannel {
public:
    virtual ~CommunicationChannel() = default;
    virtual bool start() = 0;
    virtual void stop() = 0;
    virtual bool isRunning() const = 0;
    virtual bool submitRead(std::vector<uint8_t> frame,
        CommunicationScheduler::Completion completion = {}) = 0;
    virtual bool submitWrite(std::vector<uint8_t> frame,
        CommunicationScheduler::Completion completion = {}) = 0;
    virtual std::size_t pendingReadCount() const = 0;
    virtual std::size_t pendingWriteCount() const = 0;
    virtual std::string getLastReadHex() const = 0;
    virtual std::string getLastError() const = 0;
    virtual std::string getTransportName() const = 0;
};

class SerialCommunicationChannel final : public CommunicationChannel {
public:
    SerialCommunicationChannel(const SerialConfig& serialConfig,
        CommunicationSchedulerType schedulerType);
    ~SerialCommunicationChannel() override;

    bool start() override;
    void stop() override;
    bool isRunning() const override { return m_running; }
    bool submitRead(std::vector<uint8_t> frame,
        CommunicationScheduler::Completion completion = {}) override;
    bool submitWrite(std::vector<uint8_t> frame,
        CommunicationScheduler::Completion completion = {}) override;
    std::size_t pendingReadCount() const override;
    std::size_t pendingWriteCount() const override;
    std::string getLastReadHex() const override;
    std::string getLastError() const override;
    std::string getTransportName() const override { return "serial"; }

private:
    bool executeRead(const std::vector<uint8_t>& frame);
    bool executeWrite(const std::vector<uint8_t>& frame);
    void recordTransportFailure();
    static std::string bytesToHex(const std::vector<uint8_t>& bytes);

    SerialConfig m_serialConfig;
    CommunicationSchedulerType m_schedulerType;
    std::unique_ptr<SerialCommunication> m_serial;
    std::unique_ptr<CommunicationScheduler> m_scheduler;
    std::atomic<bool> m_running{false};
    mutable std::mutex m_mutex;
    std::vector<uint8_t> m_lastRead;
    std::string m_lastError;
};

std::unique_ptr<CommunicationChannel> createCommunicationChannel(
    const std::string& transportType,
    const SerialConfig& serialConfig,
    CommunicationSchedulerType schedulerType);

#endif // COMMUNICATIONCHANNEL_H
