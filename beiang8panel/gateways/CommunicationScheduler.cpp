#include "CommunicationScheduler.h"

#include "ModbusMasterScheduler.h"

const char* communicationSchedulerTypeName(CommunicationSchedulerType type)
{
    switch (type) {
    case CommunicationSchedulerType::ModbusMasterPolling:
        return "modbus-master-polling";
    case CommunicationSchedulerType::CommunicationSchedulerType_2:
        return "communication-scheduler-2";
    case CommunicationSchedulerType::CommunicationSchedulerType_3:
        return "communication-scheduler-3";
    case CommunicationSchedulerType::CommunicationSchedulerType_4:
        return "communication-scheduler-4";
    }
    return "unknown";
}

std::unique_ptr<CommunicationScheduler> createCommunicationScheduler(
    CommunicationSchedulerType type,
    std::chrono::milliseconds commandInterval)
{
    switch (type) {
    case CommunicationSchedulerType::ModbusMasterPolling:
        return std::make_unique<ModbusMasterScheduler>(commandInterval);
    case CommunicationSchedulerType::CommunicationSchedulerType_2:
        return std::make_unique<CommunicationScheduler2>(commandInterval);
    case CommunicationSchedulerType::CommunicationSchedulerType_3:
        return std::make_unique<CommunicationScheduler3>(commandInterval);
    case CommunicationSchedulerType::CommunicationSchedulerType_4:
        return std::make_unique<CommunicationScheduler4>(commandInterval);
    }
    return nullptr;
}
