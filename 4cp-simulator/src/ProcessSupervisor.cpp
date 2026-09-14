#include "ProcessSupervisor.h"
#include "Logger.h"
#include <chrono>
#include <iostream>
#include <sstream>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace _4CP {

#ifdef _WIN32

struct ChildProcess {
    std::string name;
    PROCESS_INFORMATION processInfo;
};

static std::string QuoteArgument(const std::string& value) {
    return "\"" + value + "\"";
}

static std::string BuildChildCommand(
    const std::string& executablePath,
    const SimulatorProcessDefinition& process) {
    std::ostringstream command;
    command << QuoteArgument(executablePath)
            << " --child"
            << " --name " << QuoteArgument(process.name)
            << " --port " << QuoteArgument(process.serialPort)
            << " --baudrate " << process.baudRate
            << " --addr " << static_cast<unsigned int>(process.deviceAddress)
            << " --scheduler "
            << CommunicationSchedulerTypeName(process.schedulerType);
    return command.str();
}

static void CloseChildProcess(ChildProcess& child) {
    if (child.processInfo.hThread != nullptr) {
        CloseHandle(child.processInfo.hThread);
        child.processInfo.hThread = nullptr;
    }
    if (child.processInfo.hProcess != nullptr) {
        CloseHandle(child.processInfo.hProcess);
        child.processInfo.hProcess = nullptr;
    }
}

static void WaitForChildrenToStop(std::vector<ChildProcess>& children) {
    const auto deadline =
        std::chrono::steady_clock::now() + std::chrono::seconds(2);

    while (std::chrono::steady_clock::now() < deadline) {
        bool allStopped = true;
        for (ChildProcess& child : children) {
            if (WaitForSingleObject(child.processInfo.hProcess, 0) == WAIT_TIMEOUT) {
                allStopped = false;
                break;
            }
        }
        if (allStopped) {
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    for (ChildProcess& child : children) {
        if (WaitForSingleObject(child.processInfo.hProcess, 0) == WAIT_TIMEOUT) {
            TerminateProcess(child.processInfo.hProcess, 1);
        }
    }
}

#endif

int RunSimulatorProcesses(
    const std::string& executablePath,
    const std::vector<SimulatorProcessDefinition>& processes,
    const std::atomic<bool>& stopRequested) {
#ifdef _WIN32
    std::vector<ChildProcess> children;
    children.reserve(processes.size());

    for (const SimulatorProcessDefinition& process : processes) {
        STARTUPINFOA startupInfo = {};
        startupInfo.cb = static_cast<DWORD>(sizeof(startupInfo));

        ChildProcess child = {};
        child.name = process.name;

        const std::string command =
            BuildChildCommand(executablePath, process);
        std::vector<char> mutableCommand(command.begin(), command.end());
        mutableCommand.push_back('\0');

        if (!CreateProcessA(
                executablePath.c_str(),
                mutableCommand.data(),
                nullptr,
                nullptr,
                FALSE,
                0,
                nullptr,
                nullptr,
                &startupInfo,
                &child.processInfo)) {
            std::cerr << "Failed to create process " << process.name
                      << ", error=" << GetLastError() << std::endl;
            for (ChildProcess& startedChild : children) {
                TerminateProcess(startedChild.processInfo.hProcess, 1);
                CloseChildProcess(startedChild);
            }
            return 1;
        }

        CloseHandle(child.processInfo.hThread);
        child.processInfo.hThread = nullptr;
        LOG("[SUPERVISOR] Created " << process.name
            << ", PID=" << child.processInfo.dwProcessId
            << ", port=" << process.serialPort
            << ", scheduler="
            << CommunicationSchedulerTypeName(process.schedulerType));
        children.push_back(child);
    }

    int exitCode = 0;
    bool allStopped = false;
    while (!stopRequested && !allStopped) {
        allStopped = true;
        for (ChildProcess& child : children) {
            const DWORD waitResult =
                WaitForSingleObject(child.processInfo.hProcess, 0);
            if (waitResult == WAIT_TIMEOUT) {
                allStopped = false;
            } else if (waitResult == WAIT_OBJECT_0) {
                DWORD childExitCode = 0;
                GetExitCodeProcess(child.processInfo.hProcess, &childExitCode);
                if (childExitCode != 0) {
                    exitCode = 1;
                }
            } else {
                exitCode = 1;
            }
        }

        if (!allStopped) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

    if (stopRequested) {
        WaitForChildrenToStop(children);
    }

    for (ChildProcess& child : children) {
        CloseChildProcess(child);
    }

    return exitCode;
#else
    (void)executablePath;
    (void)processes;
    (void)stopRequested;
    std::cerr << "Process supervisor is only supported on Windows"
              << std::endl;
    return 1;
#endif
}

} // namespace _4CP
