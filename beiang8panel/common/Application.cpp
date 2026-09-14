/**
 * Application 实现
 */

#include "Application.h"
#include "DataManager.h"
#include "history/HistoryRecorder.h"
#include "memwatch/MemoryWatchModule.h"
#include "master/DataAcquisitionModule.h"
#include "master/ScheduleController.h"
#include "localdevice/LocalDeviceModule.h"
#include "localdevice/WifiManager.h"
#include "localdevice/OtaManager.h"
#include "modbuscommand/ModbusCommandModule.h"
#include "gateways/CommunicationChannel.h"
#include "common/GlobalDefine.h"
#include "common/LogManager.h"
#include <iostream>
#include <signal.h>
#include <unistd.h>

// 静态成员初始化
Application* Application::s_globalInstance = nullptr;

Application::Application(const std::string& configPath,
    CommunicationSchedulerType communicationSchedulerType,
    ApplicationRole role)
    : m_configPath(configPath)
    , m_communicationSchedulerType(communicationSchedulerType)
    , m_role(role)
    , m_initialized(false)
    , m_shouldStop(false)
{
}

Application::~Application()
{
    shutdown();
}

// RS485开关持久化: /mnt/UDISK/rs485_enable ("0"/"1"), 缺省开启
static const char* kRs485EnableFile = "/mnt/UDISK/rs485_enable";

static bool communicationEndpointAvailable(const DataManager* dataManager)
{
    if (!dataManager || dataManager->getTransportType() != "serial") {
        return true;
    }
    return access(dataManager->getSerialPort().c_str(), R_OK | W_OK) == 0;
}

bool Application::loadRs485Enabled() const
{
    FILE* fp = fopen(kRs485EnableFile, "r");
    if (!fp) return true; // 无文件=默认开启
    int c = fgetc(fp);
    fclose(fp);
    return c != '0';
}

void Application::saveRs485Enabled(bool enable) const
{
    FILE* fp = fopen(kRs485EnableFile, "w");
    if (!fp) {
        std::cerr << "[RS485] persist failed: " << kRs485EnableFile << std::endl;
        return;
    }
    fputc(enable ? '1' : '0', fp);
    fclose(fp);
}

bool Application::setRs485Enabled(bool enable)
{
    if (enable == m_rs485Enabled.load()) {
        return true;
    }
    if (!m_dataAcquisition || !m_modbusCommandModule || !m_scheduleController) {
        std::cerr << "[RS485] communication modules are unavailable" << std::endl;
        return false;
    }
    std::cout << "[RS485] " << (enable ? "enable" : "disable") << " requested" << std::endl;
    if (enable) {
        if (!m_dataAcquisition->start()) {
            std::cerr << "[RS485] DataAcquisitionModule restart failed" << std::endl;
            return false;
        }
        if (!m_modbusCommandModule->start()) {
            std::cerr << "[RS485] ModbusCommandModule restart failed" << std::endl;
            return false;
        }
        if (!m_scheduleController->start()) {
            std::cerr << "[RS485] ScheduleController restart failed" << std::endl;
            return false;
        }
    } else {
        // 全停: 定时任务挂起(关闭期间到期的任务丢弃), 命令队列与轮询停止
        m_scheduleController->stop();
        std::cout << "[RS485] ScheduleController suspended, due tasks dropped" << std::endl;
        m_modbusCommandModule->stop();
        m_dataAcquisition->stop();
    }
    m_rs485Enabled = enable;
    saveRs485Enabled(enable);
    return true;
}

bool Application::initialize()
{
    if (m_initialized) {
        std::cout << "[Application] Already initialized" << std::endl;
        return true;
    }

    printWelcome();
    setGlobalInstance();
    setupSignalHandlers();

    try {
        // 1. 创建数据管理器
        std::cout << "[Init] Creating DataManager..." << std::endl;
        m_dataManager = std::make_unique<DataManager>(
            m_configPath, m_communicationSchedulerType);
        if (!m_dataManager->initialize()) {
            std::cerr << "[Error] Failed to initialize DataManager" << std::endl;
            return false;
        }
        std::cout << "[Init] DataManager created successfully" << std::endl;

        const bool isCommunicationOnly = m_role == ApplicationRole::CommunicationOnly;
        bool communicationReady = communicationEndpointAvailable(m_dataManager.get());
        if (!communicationReady) {
            std::cerr << "[Init] Communication endpoint unavailable; "
                      << "communication modules will be skipped: "
                      << m_dataManager->getSerialPort() << std::endl;
        }
        if (isCommunicationOnly) {
            if (communicationReady) {
                SerialConfig serialConfig;
                serialConfig.port = m_dataManager->getSerialPort();
                serialConfig.baudRate = m_dataManager->getSerialBaudRate();
                serialConfig.dataBits = m_dataManager->getSerialDataBits();
                serialConfig.stopBits = m_dataManager->getSerialStopBits();
                serialConfig.parity = m_dataManager->getSerialParity();
                serialConfig.timeoutMs = m_dataManager->getSerialTimeout();
                m_communicationChannel = createCommunicationChannel(
                    m_dataManager->getTransportType(), serialConfig,
                    m_communicationSchedulerType);
                if (!m_communicationChannel || !m_communicationChannel->start()) {
                    std::cerr << "[Warn] Communication channel unavailable; continuing without communication"
                              << std::endl;
                    m_communicationChannel.reset();
                    communicationReady = false;
                }
            } else {
                std::cerr << "[Init] Communication channel skipped" << std::endl;
            }
        } else {
            // 2. 启动设备数据采集模块
            if (communicationReady) {
                std::cout << "[Init] Starting DataAcquisitionModule..." << std::endl;
                m_dataAcquisition = std::make_unique<DataAcquisitionModule>(m_dataManager.get());
                if (!m_dataAcquisition->start()) {
                    std::cerr << "[Warn] DataAcquisitionModule unavailable; continuing without communication"
                              << std::endl;
                    m_dataAcquisition.reset();
                    communicationReady = false;
                } else {
                    std::cout << "[Init] DataAcquisitionModule started successfully" << std::endl;
                }
            } else {
                std::cerr << "[Init] DataAcquisitionModule skipped" << std::endl;
            }
        }

        if (m_role == ApplicationRole::Full) {
            // 2.5 启动历史趋势采样(只读寄存器缓存,不碰串口;失败不阻断启动)
            if (HistoryRecorder* recorder = m_dataManager->getHistoryRecorder()) {
                if (!recorder->start()) {
                    std::cerr << "[Warn] Failed to start HistoryRecorder, history disabled" << std::endl;
                }
            }

            // 2.6 启动内存水位监控(MemAvailable 分级处置;失败不阻断启动)
            if (MemoryWatchModule* memWatch = m_dataManager->getMemoryWatchModule()) {
                if (!memWatch->start()) {
                    std::cerr << "[Warn] Failed to start MemoryWatchModule, memwatch disabled" << std::endl;
                }
            }
        }

        // 3. 启动 Modbus 写命令线程。HTTP 只入队，实际写入仍经过通信调度器。
        if (!isCommunicationOnly) {
            if (communicationReady) {
                std::cout << "[Init] Starting ModbusCommandModule..." << std::endl;
                m_modbusCommandModule = std::make_unique<ModbusCommandModule>(m_dataManager.get());
                if (!m_modbusCommandModule->start()) {
                    std::cerr << "[Warn] ModbusCommandModule unavailable; continuing without communication"
                              << std::endl;
                    m_modbusCommandModule.reset();
                    communicationReady = false;
                } else {
                    std::cout << "[Init] ModbusCommandModule started successfully" << std::endl;
                }
            } else {
                m_rs485Enabled = false;
                std::cerr << "[Init] ModbusCommandModule skipped" << std::endl;
            }
        }

        if (m_role == ApplicationRole::Full) {
            // 4. 启动本机设备数据与命令线程
            std::cout << "[Init] Starting LocalDeviceModule..." << std::endl;
            m_localDeviceModule = std::make_unique<LocalDeviceModule>(m_dataManager.get());
            if (!m_localDeviceModule->start()) {
                std::cerr << "[Error] Failed to start LocalDeviceModule" << std::endl;
                return false;
            }
            std::cout << "[Init] LocalDeviceModule started successfully" << std::endl;

            // 5. WiFi 扫描/连接独立运行，不阻塞亮度和本机传感器。
            std::cout << "[Init] Starting WifiManager..." << std::endl;
            m_wifiManager = std::make_unique<WifiManager>(m_dataManager.get());
            if (!m_wifiManager->start()) {
                std::cerr << "[Error] Failed to start WifiManager" << std::endl;
                return false;
            }
            std::cout << "[Init] WifiManager started successfully" << std::endl;

            // 5.5 启动OTA管理器（持有模组串口，须在HttpServer之前）
            std::cout << "[Init] Starting OtaManager..." << std::endl;
            m_otaManager = std::make_unique<OtaManager>(m_dataManager.get());
            m_otaManager->setNetConnectedCallback(
                [this]() { m_wifiManager->requestTimeSync(); });
            if (!m_otaManager->start()) {
                std::cerr << "[Warn] Failed to start OtaManager, OTA disabled" << std::endl;
            }

            // 6. 启动定时任务调度器
            std::cout << "[Init] Starting ScheduleController..." << std::endl;
            m_scheduleController = std::make_unique<ScheduleController>();
            if (!m_scheduleController->start()) {
                std::cerr << "[Error] Failed to start ScheduleController" << std::endl;
                return false;
            }
            std::cout << "[Init] ScheduleController started successfully" << std::endl;

            // RS485开关: 读取持久化状态(默认开启), 若上次为关闭则全停
            if (!loadRs485Enabled()) {
                std::cout << "[Init] RS485 disabled (persisted), stopping modbus modules" << std::endl;
                m_rs485Enabled = false;
                if (m_scheduleController) {
                    m_scheduleController->stop();
                }
                if (m_modbusCommandModule) {
                    m_modbusCommandModule->stop();
                }
                if (m_dataAcquisition) {
                    m_dataAcquisition->stop();
                }
            }
        }

#ifdef ENABLE_HTTP_SERVER
        // 7. 启动HTTP服务器
        std::cout << "[Init] Starting HttpServer..." << std::endl;
        m_httpServer = std::make_unique<HttpServerBasedOnLibhv>(
            m_dataManager.get(),
            m_modbusCommandModule.get(),
            m_localDeviceModule.get(),
            m_wifiManager.get(),
            m_otaManager.get(),
            m_role == ApplicationRole::Full
                ? HttpServerMode::Full
                : (m_role == ApplicationRole::FourCpCommunication
                    ? HttpServerMode::ProtocolOnly
                    : HttpServerMode::CommunicationOnly),
            m_communicationChannel.get());
        m_httpServer->setHost(m_dataManager->getHttpHost());
        m_httpServer->setPort(m_dataManager->getHttpPort());
        if (m_role == ApplicationRole::Full) {
            m_httpServer->setRs485Control(
                [this](bool enable) { return setRs485Enabled(enable); },
                [this]() { return isRs485Enabled(); });
        }
        if (!m_httpServer->start()) {
            std::cerr << "[Error] Failed to start HttpServer" << std::endl;
            return false;
        }
        std::cout << "[Success] BeiAng8Panel started successfully!" << std::endl;
        std::cout << "[Info] HTTP server listening on port " << m_dataManager->getHttpPort() << std::endl;
#else
        std::cout << "[Success] BeiAng8Panel started successfully!" << std::endl;
        std::cout << "[Info] HTTP server is disabled (ENABLE_HTTP_SERVER=OFF)" << std::endl;
#endif

        m_initialized = true;
        return true;

    } catch (const std::exception& e) {
        std::cerr << "[Exception] " << e.what() << std::endl;
        return false;
    }
}

void Application::shutdown()
{
    if (!m_initialized) {
        return;
    }

    std::cout << "[Application] Shutting down..." << std::endl;

#ifdef ENABLE_HTTP_SERVER
    // 按逆序关闭各模块
    if (m_httpServer) {
        m_httpServer->stop();
        m_httpServer.reset();
    }
#endif

    if (m_scheduleController) {
        m_scheduleController->stop();
        m_scheduleController.reset();
    }

    // OtaManager 持有模组串口，先于 WiFi 停止（逆序关闭）
    if (m_otaManager) {
        m_otaManager->stop();
        m_otaManager.reset();
    }

    if (m_wifiManager) {
        m_wifiManager->stop();
        m_wifiManager.reset();
    }

    if (m_localDeviceModule) {
        m_localDeviceModule->stop();
        m_localDeviceModule.reset();
    }

    if (m_modbusCommandModule) {
        m_modbusCommandModule->stop();
        m_modbusCommandModule.reset();
    }

    if (m_communicationChannel) {
        m_communicationChannel->stop();
        m_communicationChannel.reset();
    }


    // 内存监控最先停(关闭期不得再杀 Flutter/重启设备)
    if (m_dataManager && m_dataManager->getMemoryWatchModule()) {
        m_dataManager->getMemoryWatchModule()->stop();
    }

    // 历史采样线程先于采集模块停止(采样读采集维护的寄存器缓存)
    if (m_dataManager && m_dataManager->getHistoryRecorder()) {
        m_dataManager->getHistoryRecorder()->stop();
    }

    if (m_dataAcquisition) {
        m_dataAcquisition->stop();
        m_dataAcquisition.reset();
    }

    if (m_dataManager) {
        m_dataManager->shutdown();
        m_dataManager.reset();
    }

    // 确保日志在退出前刷新
    LogManager::getInstance().flush();

    m_initialized = false;
    std::cout << "[Application] Shutdown complete" << std::endl;
}

int Application::run()
{
    if (!m_initialized) {
        std::cerr << "[Error] Application not initialized" << std::endl;
        return 1;
    }

    // 主循环
    while (!m_shouldStop) {
        sleep(1);
        // 可以在这里添加主循环逻辑
    }

    return 0;
}

void Application::requestStop()
{
    m_shouldStop = true;
}

void Application::printWelcome()
{
    std::cout << "========================================" << std::endl;
    std::cout << "    BeiAng8Panel Backend Service" << std::endl;
    std::cout << "    Version: " << BEIANG_8PANEL_VERSION << std::endl;
    std::cout << "    Build: " << __DATE__ << " " << __TIME__ << std::endl;
    std::cout << "========================================" << std::endl;
}

void Application::setupSignalHandlers()
{
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
}

void Application::signalHandler(int signal)
{
    std::cout << "Received signal " << signal << ", shutting down..." << std::endl;

    if (s_globalInstance) {
        s_globalInstance->requestStop();
    }
}

void Application::setGlobalInstance()
{
    s_globalInstance = this;
}
