#ifndef PROCESSSUPERVISOR_H
#define PROCESSSUPERVISOR_H

#include "gateways/CommunicationSchedulerType.h"
#include "common/Application.h"
#include <string>
#include <vector>

struct BackendProcessDefinition {
    std::string name;
    std::string configPath;
    CommunicationSchedulerType schedulerType;
    ApplicationRole role = ApplicationRole::Full;
};

using BackendProcessEntry = int (*)(
    const BackendProcessDefinition& process,
    std::size_t processCount);

int runBackendProcesses(
    const std::vector<BackendProcessDefinition>& processes,
    BackendProcessEntry processEntry);

#endif // PROCESSSUPERVISOR_H
