/**
 * BeiAng8Panel 主程序入口
 *
 * 功能说明：
 * 1. 解析命令行参数
 * 2. 初始化并启动应用程序
 * 3. 处理退出信号
 */

#if defined(ENABLE_HTTP_SERVER) && ENABLE_HTTP_SERVER
#include <hv/hasync.h>
#include <hv/hlog.h> // libhv hlog: HTTP 访问日志落盘与尺寸截断
#endif

#include "ProcessSupervisor.h"
#include "common/Application.h"
#include "DataManager.h"
#include "common/GlobalDefine.h"
#include "common/GlobalFunction.h" // FileUtils: 配置迁移到 /mnt/UDISK 用
#include "common/LogManager.h"
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <set>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

/**
 * @brief 查找可用的配置文件
 * 按优先级搜索多个可能的路径
 * @param userSpecifiedPath 用户指定的路径
 * @return 找到的配置文件路径，如果都找不到则返回默认相对路径
 */
std::string findConfigFile(const std::string& userSpecifiedPath)
{
    // 如果用户指定了路径，直接使用
    if (!userSpecifiedPath.empty()) {
        return userSpecifiedPath;
    }

    // 默认搜索路径列表（按优先级）
    // /mnt/UDISK 可写, 用户修改的配置优先 (rootfs 只读)
    const std::vector<std::string> searchPaths = {
        "/mnt/UDISK/beiang8panel/FactoryConfig.json", // 用户可写配置(优先)
        "config/FactoryConfig.json", // 开发环境相对路径
        "./FactoryConfig.json", // 当前目录
        "/etc/beiang8panel/FactoryConfig.json", // 系统只读出厂配置(兜底)
        "/usr/share/beiang8panel/config/FactoryConfig.json" // 数据目录
    };

    for (const auto& path : searchPaths) {
        // 检查文件是否存在且可读
        if (access(path.c_str(), R_OK) == 0) {
            return path;
        }
    }

    // 如果都找不到，返回第一个默认路径（让后续代码处理错误）
    return searchPaths[0];
}

static std::string findNamedConfigFile(const std::string& fileName)
{
    const std::vector<std::string> searchPaths = {
        "/mnt/UDISK/beiang8panel/" + fileName,
        "config/" + fileName,
        "./" + fileName,
        "/etc/beiang8panel/" + fileName,
        "/usr/share/beiang8panel/config/" + fileName
    };

    for (const auto& path : searchPaths) {
        if (access(path.c_str(), R_OK) == 0) {
            return path;
        }
    }

    return {};
}

// 附加通信配置允许用 endpoint=null 停用对应进程，保留代码和配置文件位置。
// 解析失败不在这里吞掉，仍交给 DataManager 按原有配置错误路径处理。
/**
 * @brief 打印使用说明
 * @param progName 程序名称
 */
void printUsage(const char* progName)
{
    std::cout << "Usage: " << progName << " [options]" << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -c <config>  Specify one process config; repeat -c for more processes" << std::endl;
    std::cout << "  -d           Run as daemon (background)" << std::endl;
    std::cout << "  -h           Show this help message" << std::endl;
    std::cout << "  -v           Show version information" << std::endl;
    std::cout << std::endl;
    std::cout << "Default config search paths:" << std::endl;
    std::cout << "  1. /mnt/UDISK/beiang8panel/FactoryConfig.json (writable, preferred)" << std::endl;
    std::cout << "  2. config/FactoryConfig.json (relative)" << std::endl;
    std::cout << "  3. /etc/beiang8panel/FactoryConfig.json (factory readonly)" << std::endl;
    std::cout << "  4. /usr/share/beiang8panel/config/FactoryConfig.json" << std::endl;
    std::cout << std::endl;
    std::cout << "Multiple communication processes:" << std::endl;
    std::cout << "  " << progName << " -c config/process-x.json -c config/process-y.json" << std::endl;
}

/**
 * @brief 守护进程化
 * 双 fork + setsid 脱离控制终端，标准输入/输出/错误重定向到 /dev/null。
 * 日志由 LogManager 独立写入文件，不受 stdout 重定向影响。
 * 必须在创建任何线程之前调用（main 解析参数后、初始化前）。
 */
void daemonize()
{
    // 第一次 fork：父进程退出，脱离 shell 会话
    pid_t pid = fork();
    if (pid < 0) {
        std::cerr << "[Error] fork() failed: " << strerror(errno) << std::endl;
        exit(1);
    }
    if (pid > 0) {
        exit(0); // 父进程立即返回，shell 拿到提示符
    }

    // 成为新的会话首领，彻底脱离控制终端
    if (setsid() < 0) {
        std::cerr << "[Error] setsid() failed: " << strerror(errno) << std::endl;
        exit(1);
    }

    // 第二次 fork：确保不会重新获取控制终端
    pid = fork();
    if (pid < 0) {
        std::cerr << "[Error] fork() failed: " << strerror(errno) << std::endl;
        exit(1);
    }
    if (pid > 0) {
        exit(0);
    }

    // 切换到根目录，避免占用挂载点（失败不影响 daemon 功能，忽略）
    if (chdir("/") != 0) {
        // 保持当前目录继续运行
    }

    // 重置文件权限掩码
    umask(0);

    // 重定向标准输入/输出/错误到 /dev/null
    int devnull = open("/dev/null", O_RDWR);
    if (devnull >= 0) {
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        if (devnull > STDERR_FILENO) {
            close(devnull);
        }
    }
}

static std::string getLogDirectory()
{
    const char* overrideDir = std::getenv("BEIANG_LOG_DIR");
    if (overrideDir != nullptr && overrideDir[0] != '\0') {
        return overrideDir;
    }

#ifdef BEIANG_NATIVE_BUILD
    return "logs";
#else
    return "/mnt/UDISK/beiang8panel/logs";
#endif
}

// 每个通信进程都从这里进入。
// 日志、内存检查和系统资源清理必须在 fork 之后由各子进程分别执行。
static int runBackendApplicationProcess(
    const BackendProcessDefinition& process,
    std::size_t processCount)
{
    // 初始化日志管理器。
    // 板端使用 /mnt/UDISK 可写目录；本地构建使用工程 logs 目录。
    const std::string logFileName = processCount == 1
        ? "beiang8panel"
        : "beiang8panel-" + process.name;
    if (!LogManager::getInstance().initialize(
            getLogDirectory(), logFileName, LogLevel::INFO, true)) {
        std::cerr << "[Error] Failed to initialize LogManager for "
                  << process.name << std::endl;
        return 1;
    }

    LOG_INFO("BeiAng8Panel version: {}", BEIANG_8PANEL_VERSION);

    // libhv HTTP 日志: 不配置时默认写到 cwd/libhv.<日期>.log 且按天无限累积;
    // 改为固定文件 + 1MB 截断(libhv 超限自截断, 见 base/hlog.c truncate_percent)
    mkdir("/mnt/UDISK/logs", 0755);
    hlog_set_file("/mnt/UDISK/logs/libhv.log");
    hlog_set_max_filesize_by_str("1M");    LOG_INFO("Process: {}, pid: {}", process.name, static_cast<long>(getpid()));
    LOG_INFO("Config file: {}", process.configPath);
    LOG_INFO("Communication scheduler: {}",
        communicationSchedulerTypeName(process.schedulerType));
    LOG_INFO("Application role: {}",
        process.role == ApplicationRole::Full
            ? "full"
            : (process.role == ApplicationRole::FourCpCommunication
                ? "4cp-communication"
                : "communication-only"));

#if defined(ENABLE_HTTP_SERVER) && ENABLE_HTTP_SERVER
    // 内存泄漏检测（仅调试用，进程退出时打印内存统计）。
    HV_MEMCHECK;
#endif

    // 创建并运行应用程序；该进程使用配置区明确选择的通信调度器。
    Application app(process.configPath, process.schedulerType, process.role);
    if (!app.initialize()) {
        LOG_CRITICAL("Failed to initialize {}", process.name);
        return 1;
    }

    const int exitCode = app.run();

#if defined(ENABLE_HTTP_SERVER) && ENABLE_HTTP_SERVER
    // 清理当前进程的 libhv 全局资源。
    hv::async::cleanup();
#endif

    return exitCode;
}

/**
 * @brief 主函数
 * @param argc 参数计数
 * @param argv 参数值
 * @return int 退出码
 */
int main(int argc, char* argv[])
{
    // 解析命令行参数
    std::vector<std::string> userConfigPaths;
    bool runAsDaemon = false;

    int opt;
    while ((opt = getopt(argc, argv, "c:dhv")) != -1) {
        switch (opt) {
        case 'c':
            userConfigPaths.emplace_back(optarg);
            break;
        case 'd':
            runAsDaemon = true;
            break;
        case 'h':
            printUsage(argv[0]);
            return 0;
        case 'v':
            std::cout << "BeiAng8Panel Version: " << BEIANG_8PANEL_VERSION << std::endl;
            return 0;
        default:
            printUsage(argv[0]);
            return 1;
        }
    }

    // 后台运行模式（-d）：双 fork 脱离终端后继续执行
    // 必须在 LogManager/线程初始化之前调用，保证 fork 时无多线程
    if (runAsDaemon) {
        daemonize();
    }

    // 首次启动初始化: 确保 /mnt/UDISK/beiang8panel 可写配置目录存在
    // (rootfs 只读, 配置修改需落到 /mnt/UDISK; 首次从出厂只读配置复制)
    if (userConfigPaths.empty()) {
        FileUtils::createDirectories("/mnt/UDISK/beiang8panel");
        const std::string udiskConfig = "/mnt/UDISK/beiang8panel/FactoryConfig.json";
        if (!FileUtils::fileExists(udiskConfig)) {
            const std::string factoryConfig = "/etc/beiang8panel/FactoryConfig.json";
            if (FileUtils::fileExists(factoryConfig)) {
                FileUtils::writeFile(udiskConfig, FileUtils::readFile(factoryConfig));
            }
        }
    }

    // ==================== 进程配置区 ====================
    // 每个配置文件对应一个独立进程；进程与通信调度器在这里明确组合。
    std::vector<std::string> processConfigPaths;
    if (userConfigPaths.empty()) {
        processConfigPaths.push_back(findConfigFile(""));
        for (const char* fileName : {
                 "FactoryConfig_2.json",
                 "FactoryConfig_3.json",
                 "FactoryConfig_4.json"}) {
            const std::string path = findNamedConfigFile(fileName);
            // 保留固定槽位：缺少 2 不会让 3/4 错位成前一路。
            processConfigPaths.push_back(path);
        }
    } else {
        processConfigPaths.reserve(userConfigPaths.size());
        for (const std::string& configPath : userConfigPaths) {
            processConfigPaths.push_back(findConfigFile(configPath));
        }
    }

    // 在 fork 前完成只读校验；异常配置和明确停用都不会进入对应进程。
    // 配置文件仍由子进程启动时再次加载为运行态快照，运行中不热加载。
    std::set<int> httpPorts;
    for (std::size_t index = 0; index < processConfigPaths.size(); ++index) {
        const std::string& configPath = processConfigPaths[index];
        if (configPath.empty()) {
            continue;
        }

        DataManager::ConfigFileInfo info;
        std::string error;
        if (!DataManager::inspectConfigFile(configPath, info, error)) {
            std::cerr << "[Config] process-" << (index + 1)
                      << " disabled: " << configPath << " (" << error << ")"
                      << std::endl;
            processConfigPaths[index].clear();
            continue;
        }
        if (info.disabled) {
            std::cout << "[Config] process-" << (index + 1)
                      << " disabled by endpoint=null: " << configPath << std::endl;
            processConfigPaths[index].clear();
            continue;
        }
        // 通信端点不可用时保留对应进程，通信相关模块自行跳过。
        if (info.transportType == "serial"
            && access(info.endpoint.c_str(), R_OK | W_OK) != 0) {
            std::cerr << "[Config] process-" << (index + 1)
                      << " endpoint unavailable: " << info.endpoint << std::endl;
        }
        if (!httpPorts.insert(info.httpPort).second) {
            std::cerr << "[Config] process-" << (index + 1)
                      << " disabled: duplicate HTTP port " << info.httpPort << std::endl;
            processConfigPaths[index].clear();
            continue;
        }
    }

    std::vector<BackendProcessDefinition> processes;
    processes.reserve(processConfigPaths.size());

    // 进程 1：既有 4CP 业务进程，保留 ModbusMasterPolling 入口。
    if (!processConfigPaths.empty() && !processConfigPaths[0].empty()) {
        BackendProcessDefinition process1;
        process1.name = "process-1";
        process1.configPath = processConfigPaths[0];
        process1.schedulerType = CommunicationSchedulerType::ModbusMasterPolling;
        process1.role = ApplicationRole::Full;
        processes.push_back(process1);
    }

    // 进程 2：当前用于验证多进程通信彼此独立，后续可按项目需要调整通信用途。
    // 功能：独立运行 4CP 通信进程，使用自己的配置、通信端点和进程资源；当前复用现有 4CP 协议实现。
    if (processConfigPaths.size() > 1 && !processConfigPaths[1].empty()) {
        BackendProcessDefinition process2;
        process2.name = "process-2";
        process2.configPath = processConfigPaths[1];
        process2.schedulerType = CommunicationSchedulerType::CommunicationSchedulerType_2;
        process2.role = ApplicationRole::FourCpCommunication;
        processes.push_back(process2);
    }

    // 进程 3：当前用于验证独立通信调度，后续可按项目需要调整通信用途。
    // 功能：独立运行通用通信进程，使用自己的配置、通信端点和进程资源；通信策略和设备实现可独立更新。
    if (processConfigPaths.size() > 2 && !processConfigPaths[2].empty()) {
        BackendProcessDefinition process3;
        process3.name = "process-3";
        process3.configPath = processConfigPaths[2];
        process3.schedulerType = CommunicationSchedulerType::CommunicationSchedulerType_3;
        process3.role = ApplicationRole::CommunicationOnly;
        processes.push_back(process3);
    }

    // 进程 4：当前用于验证独立通信调度，后续可按项目需要调整通信用途。
    // 功能：独立运行通用通信进程，使用自己的配置、通信端点和进程资源；通信策略和设备实现可独立更新。
    if (processConfigPaths.size() > 3 && !processConfigPaths[3].empty()) {
        BackendProcessDefinition process4;
        process4.name = "process-4";
        process4.configPath = processConfigPaths[3];
        process4.schedulerType = CommunicationSchedulerType::CommunicationSchedulerType_4;
        process4.role = ApplicationRole::CommunicationOnly;
        processes.push_back(process4);
    }

    // 配置完成后统一启动；进程管理器只负责 fork、等待和信号转发。
    return runBackendProcesses(processes, runBackendApplicationProcess);
}
