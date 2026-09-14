#ifndef COMMUNICATIONSCHEDULERTYPE_H
#define COMMUNICATIONSCHEDULERTYPE_H

enum class CommunicationSchedulerType {
    // 进程 1 的既有 4CP 实现，保留作为兼容入口。
    ModbusMasterPolling,
    CommunicationSchedulerType_2,
    CommunicationSchedulerType_3,
    CommunicationSchedulerType_4
};

const char* communicationSchedulerTypeName(CommunicationSchedulerType type);

#endif // COMMUNICATIONSCHEDULERTYPE_H
