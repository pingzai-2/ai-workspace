#pragma once

#include "CommunicationSchedulerType.h"
#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace _4CP {

struct SimulatorProcessDefinition {
    std::string name;
    std::string serialPort;
    uint32_t baudRate;
    uint8_t deviceAddress;
    CommunicationSchedulerType schedulerType;
};

int RunSimulatorProcesses(
    const std::string& executablePath,
    const std::vector<SimulatorProcessDefinition>& processes,
    const std::atomic<bool>& stopRequested);

} // namespace _4CP
