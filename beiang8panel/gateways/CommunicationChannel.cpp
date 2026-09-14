#include "CommunicationChannel.h"

#include "common/LogManager.h"
#include <chrono>
#include <thread>

SerialCommunicationChannel::SerialCommunicationChannel(
    const SerialConfig& serialConfig,
    CommunicationSchedulerType schedulerType)
    : m_serialConfig(serialConfig)
    , m_schedulerType(schedulerType)
{
}

SerialCommunicationChannel::~SerialCommunicationChannel()
{
    stop();
}

bool SerialCommunicationChannel::start()
{
    if (m_running) {
        return true;
    }
    m_serial = std::make_unique<SerialCommunication>(m_serialConfig);
    if (!m_serial->open()) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_lastError = m_serial->getLastError();
        m_serial.reset();
        return false;
    }
    m_scheduler = createCommunicationScheduler(
        m_schedulerType, std::chrono::milliseconds(250));
    if (!m_scheduler || !m_scheduler->start()) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_lastError = "communication scheduler start failed";
        m_serial->close();
        m_scheduler.reset();
        m_serial.reset();
        return false;
    }
    m_running = true;
    LOG_INFO("[CommunicationChannel] Started serial transport on {} using {}",
        m_serialConfig.port, communicationSchedulerTypeName(m_schedulerType));
    return true;
}

void SerialCommunicationChannel::stop()
{
    m_running = false;
    if (m_scheduler) {
        m_scheduler->stop();
        m_scheduler.reset();
    }
    if (m_serial) {
        m_serial->close();
        m_serial.reset();
    }
}

bool SerialCommunicationChannel::submitRead(
    std::vector<uint8_t> frame,
    CommunicationScheduler::Completion completion)
{
    if (!m_running || frame.empty() || !m_scheduler) {
        return false;
    }
    return m_scheduler->submitRead(
        [this, frame = std::move(frame)]() { return executeRead(frame); },
        std::move(completion), 1);
}

bool SerialCommunicationChannel::submitWrite(
    std::vector<uint8_t> frame,
    CommunicationScheduler::Completion completion)
{
    if (!m_running || frame.empty() || !m_scheduler) {
        return false;
    }
    return m_scheduler->submitWrite(
        [this, frame = std::move(frame)]() { return executeWrite(frame); },
        std::move(completion), 1);
}

bool SerialCommunicationChannel::executeRead(const std::vector<uint8_t>& frame)
{
    if (!m_running) {
        return false;
    }
    if (!m_serial || m_serial->write(frame.data(), frame.size())
        != static_cast<int>(frame.size())) {
        recordTransportFailure();
        return false;
    }

    std::vector<uint8_t> response;
    const auto deadline = std::chrono::steady_clock::now()
        + std::chrono::milliseconds(m_serialConfig.timeoutMs);
    uint8_t buffer[256];
    while (std::chrono::steady_clock::now() < deadline) {
        const int count = m_serial->read(buffer, sizeof(buffer));
        if (count > 0) {
            response.insert(response.end(), buffer, buffer + count);
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    std::lock_guard<std::mutex> lock(m_mutex);
    if (response.empty()) {
        m_lastError = "communication read timeout";
        return false;
    }
    m_lastRead = std::move(response);
    m_lastError.clear();
    LOG_INFO("[CommunicationChannel] Read response: {}", bytesToHex(m_lastRead));
    return true;
}

bool SerialCommunicationChannel::executeWrite(const std::vector<uint8_t>& frame)
{
    if (!m_running) {
        return false;
    }
    if (!m_serial || m_serial->write(frame.data(), frame.size())
        != static_cast<int>(frame.size())) {
        recordTransportFailure();
        return false;
    }
    std::lock_guard<std::mutex> lock(m_mutex);
    m_lastError.clear();
    LOG_INFO("[CommunicationChannel] Write frame: {}", bytesToHex(frame));
    return true;
}

void SerialCommunicationChannel::recordTransportFailure()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_lastError = m_serial ? m_serial->getLastError() : "transport is not open";
    if (m_serial && m_serial->hasFatalError()) {
        // 不在调度器工作线程内调用 stop()，避免线程自等待；拒绝后续提交，
        // 由 Application 的正常关闭路径回收调度器和串口对象。
        m_running = false;
        LOG_ERROR("[CommunicationChannel] Fatal transport error, channel stopped: {}",
            m_lastError);
    }
}

std::size_t SerialCommunicationChannel::pendingReadCount() const
{
    return m_scheduler ? m_scheduler->pendingReadCount() : 0;
}

std::size_t SerialCommunicationChannel::pendingWriteCount() const
{
    return m_scheduler ? m_scheduler->pendingWriteCount() : 0;
}

std::string SerialCommunicationChannel::getLastReadHex() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return bytesToHex(m_lastRead);
}

std::string SerialCommunicationChannel::getLastError() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastError;
}

std::string SerialCommunicationChannel::bytesToHex(const std::vector<uint8_t>& bytes)
{
    static const char* digits = "0123456789ABCDEF";
    std::string result;
    result.reserve(bytes.size() * 3);
    for (std::size_t index = 0; index < bytes.size(); ++index) {
        if (index != 0) {
            result.push_back(' ');
        }
        result.push_back(digits[(bytes[index] >> 4) & 0x0F]);
        result.push_back(digits[bytes[index] & 0x0F]);
    }
    return result;
}

std::unique_ptr<CommunicationChannel> createCommunicationChannel(
    const std::string& transportType,
    const SerialConfig& serialConfig,
    CommunicationSchedulerType schedulerType)
{
    if (transportType == "serial") {
        return std::make_unique<SerialCommunicationChannel>(
            serialConfig, schedulerType);
    }
    return nullptr;
}
