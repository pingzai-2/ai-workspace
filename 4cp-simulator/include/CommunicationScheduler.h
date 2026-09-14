#pragma once

#include "CommunicationSchedulerType.h"
#include "SerialConfig.h"
#include <cstdint>
#include <memory>

namespace _4CP {

class CommunicationScheduler {
public:
    virtual ~CommunicationScheduler() = default;

    virtual bool Start(
        const SerialConfig& serialConfig,
        uint8_t deviceAddress) = 0;
    virtual void Stop() = 0;
    virtual bool IsRunning() const = 0;
};

std::unique_ptr<CommunicationScheduler> CreateCommunicationScheduler(
    CommunicationSchedulerType type);

} // namespace _4CP
