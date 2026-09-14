#include "CommunicationScheduler.h"
#include "ModbusSlaveScheduler.h"

namespace _4CP {

const char* CommunicationSchedulerTypeName(CommunicationSchedulerType type) {
    switch (type) {
        case CommunicationSchedulerType::ModbusSlaveResponse:
            return "modbus-slave-response";
    }

    return "unknown";
}

bool ParseCommunicationSchedulerType(
    const std::string& text,
    CommunicationSchedulerType& type) {
    if (text == "modbus-slave-response") {
        type = CommunicationSchedulerType::ModbusSlaveResponse;
        return true;
    }

    return false;
}

std::unique_ptr<CommunicationScheduler> CreateCommunicationScheduler(
    CommunicationSchedulerType type) {
    switch (type) {
        case CommunicationSchedulerType::ModbusSlaveResponse:
            return std::make_unique<ModbusSlaveScheduler>();
    }

    return nullptr;
}

} // namespace _4CP
