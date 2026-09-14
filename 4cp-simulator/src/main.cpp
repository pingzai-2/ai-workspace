#include "4CP_Protocol.h"
#include "CommunicationScheduler.h"
#include "Logger.h"
#include "ProcessSupervisor.h"
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstring>
#include <exception>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <vector>

using namespace _4CP;

static std::atomic<bool> g_stopRequested(false);

static void SignalHandler(int signal) {
    (void)signal;
    g_stopRequested = true;
}

static void PrintUsage(const char* programName) {
    LOG("Usage:");
    LOG("  " << programName << " [single-process options]");
    LOG("  " << programName
        << " --process <name> <port> <baudrate> <addr> <scheduler> [...]");
    LOG("");
    LOG("Single-process options:");
    LOG("  -p, --port <port>       Serial port (default: COM1)");
    LOG("  -b, --baudrate <rate>   Baud rate (default: 9600)");
    LOG("  -a, --addr <addr>       Device address (default: 209 = 0xD1)");
    LOG("  -s, --scheduler <type>  Communication scheduler");
    LOG("  -h, --help              Show this help");
    LOG("");
    LOG("Schedulers:");
    LOG("  modbus-slave-response   Wait request, process, reply immediately");
    LOG("");
    LOG("Multi-process example:");
    LOG("  " << programName
        << " --process process-1 COM10 9600 0xD1 modbus-slave-response"
        << " --process process-2 COM11 9600 0xD1 modbus-slave-response");
}

static bool ReadOptionValue(
    int argc,
    char* argv[],
    int& index,
    const char*& value) {
    if (index + 1 >= argc) {
        return false;
    }

    value = argv[++index];
    return true;
}

static bool ParseProcessDefinition(
    int argc,
    char* argv[],
    int& index,
    SimulatorProcessDefinition& process) {
    if (index + 5 >= argc) {
        return false;
    }

    process.name = argv[++index];
    process.serialPort = argv[++index];
    process.baudRate = static_cast<uint32_t>(std::stoul(argv[++index]));
    process.deviceAddress =
        static_cast<uint8_t>(std::stoul(argv[++index], nullptr, 0));
    return ParseCommunicationSchedulerType(
        argv[++index], process.schedulerType);
}

static int RunSimulatorProcess(const SimulatorProcessDefinition& process) {
    LOG("========================================");
    LOG("   4CP Modbus RTU Simulator v1.21");
    LOG("========================================");
    LOG("Process configuration:");
    LOG("  Name: " << process.name);
    LOG("  Port: " << process.serialPort);
    LOG("  Baud rate: " << process.baudRate);
    LOG("  Device address: 0x" << std::hex
        << static_cast<int>(process.deviceAddress)
        << " (" << std::dec << static_cast<int>(process.deviceAddress) << ")");
    LOG("  Scheduler: "
        << CommunicationSchedulerTypeName(process.schedulerType));
    LOG("----------------------------------------");

    std::unique_ptr<CommunicationScheduler> scheduler =
        CreateCommunicationScheduler(process.schedulerType);
    if (!scheduler) {
        std::cerr << "Failed to create communication scheduler" << std::endl;
        return 1;
    }

    const SerialConfig serialConfig(process.serialPort, process.baudRate);
    if (!scheduler->Start(serialConfig, process.deviceAddress)) {
        std::cerr << "Failed to start communication scheduler" << std::endl;
        return 1;
    }

    LOG("Simulator process running. Press Ctrl+C to stop...");
    while (!g_stopRequested && scheduler->IsRunning()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    const bool stoppedByRequest = g_stopRequested;
    scheduler->Stop();
    if (!stoppedByRequest) {
        std::cerr
            << "Simulator stopped because the serial port became unavailable"
            << std::endl;
        return 1;
    }
    return 0;
}

int main(int argc, char* argv[]) {
    SimulatorProcessDefinition commandLineProcess;
    commandLineProcess.name = "process-1";
    commandLineProcess.serialPort = "COM1";
    commandLineProcess.baudRate = 9600;
    commandLineProcess.deviceAddress = DEVICE_ADDRESS;
    commandLineProcess.schedulerType =
        CommunicationSchedulerType::ModbusSlaveResponse;

    std::vector<SimulatorProcessDefinition> requestedProcesses;
    bool isChildProcess = false;

    try {
        for (int index = 1; index < argc; ++index) {
            if (std::strcmp(argv[index], "--process") == 0) {
                SimulatorProcessDefinition process;
                if (!ParseProcessDefinition(argc, argv, index, process)) {
                    std::cerr << "Invalid --process definition" << std::endl;
                    PrintUsage(argv[0]);
                    return 2;
                }
                requestedProcesses.push_back(process);
            } else if (std::strcmp(argv[index], "--child") == 0) {
                isChildProcess = true;
            } else if (std::strcmp(argv[index], "--name") == 0) {
                const char* value = nullptr;
                if (!ReadOptionValue(argc, argv, index, value)) {
                    return 2;
                }
                commandLineProcess.name = value;
            } else if (std::strcmp(argv[index], "-p") == 0 ||
                       std::strcmp(argv[index], "--port") == 0) {
                const char* value = nullptr;
                if (!ReadOptionValue(argc, argv, index, value)) {
                    return 2;
                }
                commandLineProcess.serialPort = value;
            } else if (std::strcmp(argv[index], "-b") == 0 ||
                       std::strcmp(argv[index], "--baudrate") == 0) {
                const char* value = nullptr;
                if (!ReadOptionValue(argc, argv, index, value)) {
                    return 2;
                }
                commandLineProcess.baudRate =
                    static_cast<uint32_t>(std::stoul(value));
            } else if (std::strcmp(argv[index], "-a") == 0 ||
                       std::strcmp(argv[index], "--addr") == 0) {
                const char* value = nullptr;
                if (!ReadOptionValue(argc, argv, index, value)) {
                    return 2;
                }
                commandLineProcess.deviceAddress =
                    static_cast<uint8_t>(std::stoul(value, nullptr, 0));
            } else if (std::strcmp(argv[index], "-s") == 0 ||
                       std::strcmp(argv[index], "--scheduler") == 0) {
                const char* value = nullptr;
                if (!ReadOptionValue(argc, argv, index, value) ||
                    !ParseCommunicationSchedulerType(
                        value, commandLineProcess.schedulerType)) {
                    std::cerr << "Invalid communication scheduler" << std::endl;
                    return 2;
                }
            } else if (std::strcmp(argv[index], "-h") == 0 ||
                       std::strcmp(argv[index], "--help") == 0) {
                PrintUsage(argv[0]);
                return 0;
            } else {
                std::cerr << "Unknown option: " << argv[index] << std::endl;
                PrintUsage(argv[0]);
                return 2;
            }
        }
    } catch (const std::exception& error) {
        std::cerr << "Invalid command line: " << error.what() << std::endl;
        return 2;
    }

    std::signal(SIGINT, SignalHandler);
    std::signal(SIGTERM, SignalHandler);

    // ==================== 进程配置区 ====================
    // 进程 1：一路串口、一个设备地址、一个明确选择的通信调度器。
    std::vector<SimulatorProcessDefinition> processes;
    if (requestedProcesses.empty()) {
        SimulatorProcessDefinition process1;
        process1.name = commandLineProcess.name;
        process1.serialPort = commandLineProcess.serialPort;
        process1.baudRate = commandLineProcess.baudRate;
        process1.deviceAddress = commandLineProcess.deviceAddress;
        process1.schedulerType = commandLineProcess.schedulerType;
        processes.push_back(process1);
    } else {
        processes = requestedProcesses;
    }

    // 进程 2、进程 3……按相同结构并列配置；每个进程可独立选择调度器。
    if (isChildProcess || processes.size() == 1) {
        return RunSimulatorProcess(processes.front());
    }

    return RunSimulatorProcesses(argv[0], processes, g_stopRequested);
}
