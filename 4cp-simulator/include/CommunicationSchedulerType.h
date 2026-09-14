#pragma once

#include <string>

namespace _4CP {

enum class CommunicationSchedulerType {
    ModbusSlaveResponse = 0
};

const char* CommunicationSchedulerTypeName(CommunicationSchedulerType type);
bool ParseCommunicationSchedulerType(
    const std::string& text,
    CommunicationSchedulerType& type);

} // namespace _4CP
