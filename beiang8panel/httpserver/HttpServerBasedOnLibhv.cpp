/**
 * 基于libhv的HTTP服务器实现
 */

// 先包含libhv头文件
#include <cctype>
#include <curl/curl.h>
#include <hv/HttpServer.h>
#include <hv/HttpService.h>
#include <iconv.h>

// 包含项目头文件
#include "HttpServerBasedOnLibhv.h"
#include "DataManager.h"
#include "common/GlobalDefine.h"
#include "common/LogManager.h"
#include "gateways/BeiAng4CPGateway.h"
#include "gateways/CommunicationChannel.h"
#include "modbuscommand/ModbusCommandModule.h"
#include "localdevice/LocalDeviceModule.h"
#include "localdevice/WifiManager.h"
#include "localdevice/OtaManager.h"

// 包含uiservice头文件
#include "uiservice/DeviceMaintenancePage.h"
#include "uiservice/EngineeringModePage.h"
#include "uiservice/HistoryTrendPage.h"
#include "uiservice/HomePage.h"
#include "uiservice/IdlePage.h"
#include "uiservice/ManualModePage.h"
#include "uiservice/SmartModePage.h"
#include "uiservice/SystemSettingsPage.h"

#include "history/HistoryAggregation.h"
#include "memwatch/MemoryWatchModule.h"

#include <algorithm> // for std::find
#include <cstring> // for strlen
#include <ctime> // for time, localtime, strftime
#include <fstream> // for file reading
#include <sstream> // for std::istringstream
#include <iostream>
#include <nlohmann/json.hpp>
#include <vector>
#include <map>
#include <cmath>

using json = nlohmann::json;

// CURL 回调函数：将响应数据写入字符串
static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp)
{
    size_t totalSize = size * nmemb;
    std::string* response = static_cast<std::string*>(userp);
    response->append(static_cast<char*>(contents), totalSize);
    return totalSize;
}

static json localDeviceSnapshotToJson(const LocalDeviceDataStructure& data)
{
    json networks = json::array();
    for (const WifiNetworkData& network : data.wifi.scanResults) {
        networks.push_back({
            {"ssid", network.ssid},
            {"rssi", network.rssi},
            {"secured", network.secured}
        });
    }

    return {
        {"timestamp", data.timestamp},
        {"wifi", {
            {"available", data.wifi.available},
            {"enabled", data.wifi.enabled},
            {"connected", data.wifi.connected},
            {"state", data.wifi.state},
            {"targetSsid", data.wifi.targetSsid},
            {"connectedSsid", data.wifi.connectedSsid},
            {"ipAddress", data.wifi.ipAddress},
            {"rssi", data.wifi.rssi},
            {"pending", data.wifi.commandPending},
            {"success", data.wifi.lastCommandSuccess},
            {"error", data.wifi.lastError},
            {"scanResults", networks},
            {"timestamp", data.wifi.timestamp}
        }},
        {"screen", {
            {"brightnessAvailable", data.screen.brightnessAvailable},
            {"minBrightness", data.screen.minBrightness},
            {"maxBrightness", data.screen.maxBrightness},
            {"currentBrightness", data.screen.currentBrightness},
            {"sleepStateAvailable", data.screen.sleepStateAvailable},
            {"sleeping", data.screen.sleeping},
            {"pending", data.screen.commandPending},
            {"success", data.screen.lastCommandSuccess},
            {"error", data.screen.lastError}
        }},
        {"temperatureHumidity", {
            {"temperatureAvailable", data.temperatureHumidity.temperatureAvailable},
            {"humidityAvailable", data.temperatureHumidity.humidityAvailable},
            {"serialAvailable", data.temperatureHumidity.serialAvailable},
            {"temperature", data.temperatureHumidity.temperature},
            {"humidity", data.temperatureHumidity.humidity},
            {"serial", data.temperatureHumidity.serial},
            {"timestamp", data.temperatureHumidity.timestamp}
        }},
        {"radar", {
            {"enable", data.radar.enable},
            {"online", data.radar.online},
            {"distance", data.radar.distance},
            {"velocity", data.radar.velocity},
            {"signal", data.radar.signal},
            {"gesture", data.radar.gesture},
            {"approach", data.radar.approach},
            {"depart", data.radar.depart},
            {"direction", data.radar.direction},
            {"timestamp", data.radar.timestamp},
            {"pending", data.radar.commandPending},
            {"success", data.radar.lastCommandSuccess},
            {"error", data.radar.lastError}
        }},
        {"aqiLed", {
            {"stateAvailable", data.aqiLed.stateAvailable},
            {"enabled", data.aqiLed.level != 0},
            {"level", data.aqiLed.level},
            {"color", data.aqiLed.color},
            // 保留旧字段，避免已有调试客户端立即失效。
            {"lastRequestedLevel", data.aqiLed.level},
            {"lastRequestedColor", data.aqiLed.color},
            {"pending", data.aqiLed.commandPending},
            {"success", data.aqiLed.lastCommandSuccess},
            {"error", data.aqiLed.lastError}
        }},
        {"speaker", {
            {"available", data.speaker.available},
            {"enabled", data.speaker.enabled},
            {"pending", data.speaker.commandPending},
            {"success", data.speaker.lastCommandSuccess},
            {"error", data.speaker.lastError}
        }},
        {"ota", {
            {"available", data.ota.available},
            {"updateAvailable", data.ota.updateAvailable},
            {"currentVersion", data.ota.currentVersion},
            {"targetVersion", data.ota.targetVersion},
            {"fwSize", data.ota.fwSize},
            {"fwMd5", data.ota.fwMd5},
            {"state", data.ota.state},
            {"percent", data.ota.percent},
            {"downloadedBytes", data.ota.downloadedBytes},
            {"pending", data.ota.commandPending},
            {"success", data.ota.lastCommandSuccess},
            {"error", data.ota.lastError},
            {"timestamp", data.ota.timestamp}
        }}
    };
}

static json confirmedFaultsToJson(const ModbusRegisterCache& cache)
{
    static const struct {
        uint16_t bit;
        const char* name;
    } definitions[] = {
        {64, "freshAirFanAbnormal"},
        {65, "exhaustFanAbnormal"},
        {66, "boostFanAbnormal"},
        {68, "humidifierCommunicationLost"},
        {69, "humidifierInletFloatAlarm"},
        {70, "humidifierDrainFloatAlarm"},
        {71, "humidifierDrainFloatNotFalling"},
        {72, "humidifierInletWaterShortage"},
        {73, "humidifierAuxHeat1Protection"},
        {74, "humidifierAuxHeat2Protection"},
        {75, "humidifierInletFloatAbnormal"},
        {76, "humidifierDrainFloatAbnormal"}
    };

    json active = json::array();
    if (cache.discreteValid) {
        for (const auto& definition : definitions) {
            if (cache.discreteInputs[definition.bit] != 0) {
                active.push_back({
                    {"bit", definition.bit},
                    {"name", definition.name}
                });
            }
        }
    }
    // bit64 为故障总标志：1 表示设备存在故障（需结合 active 明细解析类型）
    const bool anyFault = cache.discreteValid
        && cache.discreteInputs[64] != 0;
    return {
        {"valid", cache.discreteValid},
        {"anyFault", anyFault},
        {"active", std::move(active)}
    };
}

static json confirmedNotificationsToJson(const ModbusRegisterCache& cache)
{
    static const struct {
        uint16_t address;
        const char* name;
    } definitions[] = {
        {0x1031, "filter1Maintenance"},
        {0x1032, "filter2Maintenance"},
        {0x1033, "filter3Maintenance"},
        {0x1034, "humidityModuleMaintenance"},
        {0x1035, "iefCleaning"}
    };
    constexpr uint16_t kNoticeThresholdHours = 15 * 24;

    json active = json::array();
    if (cache.holdingValid) {
        for (const auto& definition : definitions) {
            const uint16_t offset = static_cast<uint16_t>(
                definition.address - ModbusRegisterCache::HOLDING_START);
            const uint16_t remainingHours = cache.holdingRegs[offset];
            if (remainingHours <= kNoticeThresholdHours) {
                active.push_back({
                    {"address", definition.address},
                    {"name", definition.name},
                    {"remainingHours", remainingHours}
                });
            }
        }
    }
    return {
        {"valid", cache.holdingValid},
        {"active", std::move(active)}
    };
}

static json registerCacheToJson(const ModbusRegisterCache& cache)
{
    return {
        {"holding", {
            {"valid", cache.holdingValid},
            {"start", ModbusRegisterCache::HOLDING_START},
            {"count", ModbusRegisterCache::HOLDING_COUNT},
            {"words", std::vector<uint16_t>(
                cache.holdingRegs,
                cache.holdingRegs + ModbusRegisterCache::HOLDING_COUNT)}
        }},
        {"input", {
            {"valid", cache.inputValid},
            {"start", ModbusRegisterCache::INPUT_START},
            {"count", ModbusRegisterCache::INPUT_COUNT},
            {"words", std::vector<uint16_t>(
                cache.inputRegs,
                cache.inputRegs + ModbusRegisterCache::INPUT_COUNT)}
        }},
        {"discrete", {
            {"valid", cache.discreteValid},
            {"start", ModbusRegisterCache::DISCRETE_START},
            {"bitCount", ModbusRegisterCache::DISCRETE_COUNT},
            {"words", std::vector<uint16_t>(
                cache.discreteWords,
                cache.discreteWords + ModbusRegisterCache::DISCRETE_WORD_COUNT)}
        }}
    };
}

HttpServerBasedOnLibhv::HttpServerBasedOnLibhv(
    DataManager* dataManager,
    ModbusCommandModule* modbusCommandModule,
    LocalDeviceModule* localDeviceModule,
    WifiManager* wifiManager,
    OtaManager* otaManager,
    HttpServerMode mode,
    CommunicationChannel* communicationChannel)
    : m_dataManager(dataManager)
    , m_modbusCommandModule(modbusCommandModule)
    , m_localDeviceModule(localDeviceModule)
    , m_wifiManager(wifiManager)
    , m_otaManager(otaManager)
    , m_mode(mode)
    , m_communicationChannel(communicationChannel)
    , m_host("0.0.0.0")
    , m_port(8080)
    , m_isRunning(false)
    , m_shouldStop(false)
{
    m_server.service = &m_service;
}

HttpServerBasedOnLibhv::~HttpServerBasedOnLibhv()
{
    stop();
}

bool HttpServerBasedOnLibhv::start()
{
    if (m_isRunning) {
        LOG_WARN("[HttpServer] Already running");
        return true;
    }

    registerRoutes();

    m_server.setHost(m_host.c_str());
    m_server.setPort(m_port);
    m_server.setThreadNum(4);

    m_shouldStop = false;
    m_serverThread = std::make_unique<std::thread>([this]() {
        LOG_INFO("[HttpServer] Starting HTTP server on {}:{}", m_host, m_port);
        // 使用 run() 阻塞运行，直到服务器停止
        m_server.run();

        std::unique_lock<std::mutex> lock(m_mutex);
        m_isRunning = false;
        m_cv.notify_all();
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    m_isRunning = true;

    LOG_INFO("[HttpServer] HTTP server started successfully");
    return true;
}

void HttpServerBasedOnLibhv::stop()
{
    if (!m_isRunning) {
        return;
    }

    LOG_INFO("[HttpServer] Stopping HTTP server...");

    m_shouldStop = true;
    m_server.stop();

    if (m_serverThread && m_serverThread->joinable()) {
        std::unique_lock<std::mutex> lock(m_mutex);
        if (m_cv.wait_for(lock, std::chrono::seconds(5), [this] { return !m_isRunning.load(); })) {
            LOG_INFO("[HttpServer] Server thread stopped");
        } else {
            LOG_WARN("[HttpServer] Server thread stop timeout");
        }
        m_serverThread->join();
        m_serverThread.reset();
    }

    m_isRunning = false;
    LOG_INFO("[HttpServer] HTTP server stopped");
}

void HttpServerBasedOnLibhv::setHost(const std::string& host)
{
    m_host = host;
}

void HttpServerBasedOnLibhv::setPort(int port)
{
    m_port = port;
}

void HttpServerBasedOnLibhv::registerRoutes()
{
    using namespace hv;

    // 添加中间件设置通用响应头，参考 http_server_test.cpp
    m_service.Use([](const HttpContextPtr& ctx) {
        ctx->response->SetHeader("Server", "BeiAng8Panel/1.0");
        return HTTP_STATUS_NEXT;
    });

    if (m_mode == HttpServerMode::CommunicationOnly) {
        m_service.GET("/api/ping", [this](const HttpContextPtr& ctx) {
            return handlePing(ctx);
        });
        m_service.GET("/api/health", [this](const HttpContextPtr& ctx) {
            return handleHealth(ctx);
        });
        m_service.GET("/api/version", [this](const HttpContextPtr& ctx) {
            return handleVersion(ctx);
        });
        m_service.GET("/api/paths", [this](const HttpContextPtr& ctx) {
            return handlePaths(ctx);
        });
        m_service.GET("/api/communication/status", [this](const HttpContextPtr& ctx) {
            return handleCommunicationStatus(ctx);
        });
        m_service.POST("/api/communication/read", [this](const HttpContextPtr& ctx) {
            return handleCommunicationRead(ctx);
        });
        m_service.POST("/api/communication/write", [this](const HttpContextPtr& ctx) {
            return handleCommunicationWrite(ctx);
        });
        m_service.AllowCORS();
        LOG_INFO("[HttpServer] Registered communication-only routes");
        return;
    }

    // 首页API
    m_service.GET("/api/device/status", [this](const HttpContextPtr& ctx) {
        return handleGetDeviceStatus(ctx);
    });

    // UI 周期读取统一走这一条内存快照，不触发 TTY、本机设备或外部网络操作。
    m_service.GET("/api/runtime/snapshot", [this](const HttpContextPtr& ctx) {
        return handleGetRuntimeSnapshot(ctx);
    });

    m_service.POST("/api/device/ief-purification", [this](const HttpContextPtr& ctx) {
        return handleSetIefPurification(ctx);
    });

    m_service.POST("/api/device/power", [this](const HttpContextPtr& ctx) {
        return handleQuickPowerOn(ctx);
    });

    m_service.POST("/api/device/mode", [this](const HttpContextPtr& ctx) {
        return handleQuickSetMode(ctx);
    });

    // 一键离家开关API（1006H，v1.22由手动/自动改为一键离家）
    m_service.POST("/api/device/leave-home", [this](const HttpContextPtr& ctx) {
        return handleSetLeaveHomeSwitch(ctx);
    });
    m_service.GET("/api/device/leave-home/status", [this](const HttpContextPtr& ctx) {
        return handleGetLeaveHomeStatus(ctx);
    });

    // 整机运行模式API（100AH，v1.22新增：0无/手动 1标准 2会客 3干爽 4温润 5旅行）
    m_service.POST("/api/device/unit-run-mode", [this](const HttpContextPtr& ctx) {
        return handleSetWholeUnitRunMode(ctx);
    });
    m_service.GET("/api/device/unit-run-mode/status", [this](const HttpContextPtr& ctx) {
        return handleGetWholeUnitRunModeStatus(ctx);
    });

    // 新风模块API
    m_service.POST("/api/freshair/switch", [this](const HttpContextPtr& ctx) {
        return handleSetFreshAirSwitch(ctx);
    });

    m_service.GET("/api/freshair/status", [this](const HttpContextPtr& ctx) {
        return handleGetFreshAirStatus(ctx);
    });

    // 调湿模块API
    m_service.POST("/api/humidity-module/switch", [this](const HttpContextPtr& ctx) {
        return handleSetHumidityModuleSwitch(ctx);
    });

    m_service.GET("/api/humidity-module/status", [this](const HttpContextPtr& ctx) {
        return handleGetHumidityModuleStatus(ctx);
    });

    // 超净模式API
    m_service.POST("/api/super-pure/switch", [this](const HttpContextPtr& ctx) {
        return handleSetSuperPureSwitch(ctx);
    });

    m_service.GET("/api/super-pure/status", [this](const HttpContextPtr& ctx) {
        return handleGetSuperPureStatus(ctx);
    });

    // 新风风速设定API
    m_service.POST("/api/freshair/speed", [this](const HttpContextPtr& ctx) {
        return handleSetFreshAirSpeed(ctx);
    });

    // 新风运行模式设置API
    m_service.POST("/api/freshair/runmode", [this](const HttpContextPtr& ctx) {
        return handleSetFreshAirRunMode(ctx);
    });

    // UI 使用的语义模式入口；手动/自动和运行模式由后端一次校验并组合写入。
    m_service.POST("/api/freshair/mode", [this](const HttpContextPtr& ctx) {
        return handleSetFreshAirMode(ctx);
    });

    // 加湿/除湿开关API（1004H/1005H，调湿模块1003H开启时只读）
    m_service.POST("/api/humidity-module/humidify", [this](const HttpContextPtr& ctx) {
        return handleSetHumidifySwitch(ctx);
    });

    m_service.POST("/api/humidity-module/dehumidify", [this](const HttpContextPtr& ctx) {
        return handleSetDehumidifySwitch(ctx);
    });

    // 排风风量档位API（1009H，协议预留）
    m_service.POST("/api/freshair/exhaust-speed", [this](const HttpContextPtr& ctx) {
        return handleSetExhaustFanSpeed(ctx);
    });

    // 无极风量控制开关API（100BH）
    m_service.POST("/api/freshair/stepless", [this](const HttpContextPtr& ctx) {
        return handleSetSteplessFanControl(ctx);
    });

    // 风量占空比API（100CH/100DH/100EH）
    m_service.POST("/api/freshair/duty", [this](const HttpContextPtr& ctx) {
        return handleSetFanDutyCycle(ctx);
    });

    // 目标温度设定API（1010H，实际温度×10）
    m_service.POST("/api/device/target-temperature", [this](const HttpContextPtr& ctx) {
        return handleSetTargetTemperature(ctx);
    });

    // 等离子消毒开关API（1011H）
    m_service.POST("/api/device/plasma-disinfect", [this](const HttpContextPtr& ctx) {
        return handleSetPlasmaDisinfect(ctx);
    });

    // 电辅热选择API（1013H）
    m_service.POST("/api/device/aux-heat", [this](const HttpContextPtr& ctx) {
        return handleSetAuxHeat(ctx);
    });

    // SA风量与增压风机比例API（1015H，实际值×10）
    m_service.POST("/api/device/sa-fan-ratio", [this](const HttpContextPtr& ctx) {
        return handleSetSaFanRatio(ctx);
    });

    // 关机后延时关风机时间API（1020H，分钟）
    m_service.POST("/api/device/fan-delay-off", [this](const HttpContextPtr& ctx) {
        return handleSetFanDelayOff(ctx);
    });

    // 压缩机设定API（1028H-102AH）
    m_service.POST("/api/device/compressor", [this](const HttpContextPtr& ctx) {
        return handleSetCompressorSettings(ctx);
    });

    // 厂测模式API（1030H，开启需confirm）
    m_service.POST("/api/device/factory-test", [this](const HttpContextPtr& ctx) {
        return handleSetFactoryTestMode(ctx);
    });
    m_service.GET("/api/device/factory-test/status", [this](const HttpContextPtr& ctx) {
        return handleGetFactoryTestStatus(ctx);
    });

    // 高/低压开关API（102BH/102CH，仅厂测模式）
    m_service.POST("/api/device/pressure-switch", [this](const HttpContextPtr& ctx) {
        return handleSetPressureSwitch(ctx);
    });

    // 厂测FAN风量设定API（1038H-103BH，仅厂测模式）
    m_service.POST("/api/factory/fan", [this](const HttpContextPtr& ctx) {
        return handleSetFactoryFan(ctx);
    });

    // 厂测阀门状态设定API（103CH-103EH，仅厂测模式）
    m_service.POST("/api/factory/valve", [this](const HttpContextPtr& ctx) {
        return handleSetFactoryValve(ctx);
    });

    // 滤网/保养剩余时间设定API（1031H-1036H）
    m_service.POST("/api/maintenance/filter", [this](const HttpContextPtr& ctx) {
        return handleSetFilterRemaining(ctx);
    });

    // 恢复出厂API（1040H，只写，高危，需confirm）
    m_service.POST("/api/device/factory-reset", [this](const HttpContextPtr& ctx) {
        return handleFactoryReset(ctx);
    });

    // FAN内外循环各档风量标定API（1041H-1070H，仅厂测模式）
    m_service.POST("/api/factory/fan-flow", [this](const HttpContextPtr& ctx) {
        return handleSetFactoryFanFlow(ctx);
    });

    // 风阀方向/步数设定API（1071H-1076H，仅厂测模式）
    m_service.POST("/api/factory/damper", [this](const HttpContextPtr& ctx) {
        return handleSetFactoryDamper(ctx);
    });

    // 目标湿度设定API
    m_service.POST("/api/humidity-module/target", [this](const HttpContextPtr& ctx) {
        return handleSetTargetHumidity(ctx);
    });

    // 加湿/除湿强度设定API（1014H）
    m_service.POST("/api/humidity-module/intensity", [this](const HttpContextPtr& ctx) {
        return handleSetHumidityIntensity(ctx);
    });

    // 手动模式API
    m_service.GET("/api/manual/status", [this](const HttpContextPtr& ctx) {
        return handleGetManualMode(ctx);
    });

    m_service.POST("/api/manual/control", [this](const HttpContextPtr& ctx) {
        return handleSetManualMode(ctx);
    });

    // 智能模式API
    m_service.GET("/api/smart/status", [this](const HttpContextPtr& ctx) {
        return handleGetSmartMode(ctx);
    });

    m_service.POST("/api/smart/control", [this](const HttpContextPtr& ctx) {
        return handleSetSmartMode(ctx);
    });

    // 待机模式API
    m_service.GET("/api/idle/status", [this](const HttpContextPtr& ctx) {
        return handleGetIdleMode(ctx);
    });

    m_service.POST("/api/idle/control", [this](const HttpContextPtr& ctx) {
        return handleSetIdleMode(ctx);
    });

    // 系统设置API
    m_service.GET("/api/system/settings", [this](const HttpContextPtr& ctx) {
        return handleGetSystemSettings(ctx);
    });

    m_service.POST("/api/system/settings", [this](const HttpContextPtr& ctx) {
        return handleSetSystemSettings(ctx);
    });

    // 设备维护API
    m_service.GET("/api/maintenance/status", [this](const HttpContextPtr& ctx) {
        return handleGetDeviceMaintenance(ctx);
    });

    m_service.POST("/api/maintenance/filter/reset", [this](const HttpContextPtr& ctx) {
        return handleResetFilter(ctx);
    });

    // 工程模式API
    m_service.GET("/api/engineering/status", [this](const HttpContextPtr& ctx) {
        return handleGetEngineeringMode(ctx);
    });

    m_service.POST("/api/engineering/control", [this](const HttpContextPtr& ctx) {
        return handleSetEngineeringMode(ctx);
    });

    // 历史趋势API(数据源: 寄存器 200DH-2014H 周期采样落盘 UDISK)
    m_service.GET("/api/history/trend", [this](const HttpContextPtr& ctx) {
        return handleGetHistoryTrend(ctx);
    });

    m_service.GET("/api/history/status", [this](const HttpContextPtr& ctx) {
        return handleGetHistoryStatus(ctx);
    });

    // 内存水位监控(分级处置状态, v1.4.1)
    m_service.GET("/api/memwatch/status", [this](const HttpContextPtr& ctx) {
        return handleGetMemWatchStatus(ctx);
    });

    // ========== 测试接口 ==========
    m_service.GET("/api/ping", [this](const HttpContextPtr& ctx) {
        return handlePing(ctx);
    });

    m_service.GET("/api/health", [this](const HttpContextPtr& ctx) {
        return handleHealth(ctx);
    });

    m_service.GET("/api/version", [this](const HttpContextPtr& ctx) {
        return handleVersion(ctx);
    });

    m_service.GET("/api/paths", [this](const HttpContextPtr& ctx) {
        return handlePaths(ctx);
    });

    // Modbus寄存器读取接口
    m_service.GET("/api/modbus/read", [this](const HttpContextPtr& ctx) {
        return handleReadRegister(ctx);
    });

    // Modbus寄存器写入接口
    m_service.POST("/api/modbus/write", [this](const HttpContextPtr& ctx) {
        return handleWriteRegister(ctx);
    });

    if (m_mode == HttpServerMode::Full) {
    // WiFi接口
    m_service.GET("/getWifiInfo", [this](const HttpContextPtr& ctx) {
        return handleGetWifiInfo(ctx);
    });

    m_service.GET("/getConnectedWifi", [this](const HttpContextPtr& ctx) {
        return handleGetConnectedWifi(ctx);
    });

    m_service.POST("/wifiOpen", [this](const HttpContextPtr& ctx) {
        return handleWifiOpen(ctx);
    });

    m_service.POST("/disconnectWifi", [this](const HttpContextPtr& ctx) {
        return handleDisconnectWifi(ctx);
    });

    m_service.POST("/connectWifi", [this](const HttpContextPtr& ctx) {
        return handleConnectWifi(ctx);
    });

    m_service.POST("/scanWifi", [this](const HttpContextPtr& ctx) {
        return handleScanWifi(ctx);
    });
    m_service.POST("/api/local-device/wifi/enabled", [this](const HttpContextPtr& ctx) {
        return handleWifiOpen(ctx);
    });
    m_service.POST("/api/local-device/wifi/connect", [this](const HttpContextPtr& ctx) {
        return handleConnectWifi(ctx);
    });
    m_service.POST("/api/local-device/wifi/disconnect", [this](const HttpContextPtr& ctx) {
        return handleDisconnectWifi(ctx);
    });

    // ========== WiFi/RS485补充接口 (local-device风格) ==========
    // 同步聚合扫描: 阻塞等待完成(最长12s), 返回current+networks
    m_service.GET("/api/local-device/wifi/scan", [this](const HttpContextPtr& ctx) {
        return handleLocalWifiScanSync(ctx);
    });
    // 连接过程轮询: state为 idle/connecting/connected/failed
    m_service.GET("/api/local-device/wifi/status", [this](const HttpContextPtr& ctx) {
        return handleLocalWifiStatus(ctx);
    });
    // RS485通讯开关(全停语义, 持久化)
    m_service.POST("/api/local-device/rs485/enabled", [this](const HttpContextPtr& ctx) {
        return handleLocalRs485SetEnabled(ctx);
    });
    // RS485开关状态查询
    m_service.GET("/api/local-device/rs485/enabled", [this](const HttpContextPtr& ctx) {
        return handleLocalRs485GetEnabled(ctx);
    });
    m_service.GET("/api/local-device/status", [this](const HttpContextPtr& ctx) {
        return handleGetLocalDeviceStatus(ctx);
    });

    // OTA升级接口
    m_service.GET("/api/ota/status", [this](const HttpContextPtr& ctx) {
        return handleGetOtaStatus(ctx);
    });

    m_service.POST("/api/ota/start", [this](const HttpContextPtr& ctx) {
        return handleStartOtaDownload(ctx);
    });

    m_service.POST("/api/ota/cancel", [this](const HttpContextPtr& ctx) {
        return handleCancelOtaDownload(ctx);
    });

    // 屏幕休眠控制接口
    m_service.POST("/setScreenSleep", [this](const HttpContextPtr& ctx) {
        return handleSetScreenSleep(ctx);
    });

    // 屏幕背光亮度查询接口
    m_service.GET("/getScreenBrightness", [this](const HttpContextPtr& ctx) {
        return handleGetScreenBrightness(ctx);
    });

    // 屏幕背光亮度设置接口
    m_service.POST("/setScreenBrightness", [this](const HttpContextPtr& ctx) {
        return handleSetScreenBrightness(ctx);
    });
    m_service.POST("/api/local-device/screen/brightness", [this](const HttpContextPtr& ctx) {
        return handleSetScreenBrightness(ctx);
    });

    // 温湿度传感器数据接口
    m_service.GET("/getTempHumi", [this](const HttpContextPtr& ctx) {
        return handleGetTemperatureHumidity(ctx);
    });

    // 传感器序列号接口
    m_service.GET("/getSensorSerial", [this](const HttpContextPtr& ctx) {
        return handleGetSensorSerial(ctx);
    });

    // 人感雷达控制接口
    m_service.POST("/setHumanPresenceRadar", [this](const HttpContextPtr& ctx) {
        return handleSetHumanPresenceRadar(ctx);
    });
    m_service.POST("/api/local-device/radar/enabled", [this](const HttpContextPtr& ctx) {
        return handleSetHumanPresenceRadar(ctx);
    });

    // 人感雷达状态查询接口
    m_service.GET("/getHumanPresenceRadar", [this](const HttpContextPtr& ctx) {
        return handleGetHumanPresenceRadar(ctx);
    });

    // AQI指示灯控制接口
    m_service.POST("/setAQILed", [this](const HttpContextPtr& ctx) {
        return handleSetAQILed(ctx);
    });
    m_service.POST("/api/local-device/aqi-led/level", [this](const HttpContextPtr& ctx) {
        return handleSetAQILed(ctx);
    });
    m_service.POST("/api/local-device/aqi-led/enabled", [this](const HttpContextPtr& ctx) {
        return handleSetAQILed(ctx);
    });

    // 扬声器控制接口
    m_service.POST("/setSpeaker", [this](const HttpContextPtr& ctx) {
        return handleSetSpeaker(ctx);
    });

    // 获取区域天气接口
    m_service.GET("/getWeather", [this](const HttpContextPtr& ctx) {
        return handleGetWeather(ctx);
    });

    // 获取区域信息接口
    m_service.GET("/getLocation", [this](const HttpContextPtr& ctx) {
        return handleGetLocation(ctx);
    });

    // ========== RTC时间管理API (v1.20新增) ==========
    m_service.GET("/api/rtc/time", [this](const HttpContextPtr& ctx) {
        return handleGetRTCTimeApi(ctx);
    });

    m_service.POST("/api/rtc/time", [this](const HttpContextPtr& ctx) {
        return handleSetRTCTimeApi(ctx);
    });

    }

    // ========== 设备能力查询API (v1.20新增) ==========
    m_service.GET("/api/device/capabilities", [this](const HttpContextPtr& ctx) {
        return handleGetDeviceCapabilities(ctx);
    });

    // ========== 空调/地暖有无查询API (v1.4.2新增) ==========
    // 4CP 无空调无地暖(仅新风/调湿/超净), 协议离散能力表亦无此两位,
    // 故为产品级静态值, 不依赖 Modbus 缓存, 上电即可查
    m_service.GET("/api/device/air-conditioner/presence", [this](const HttpContextPtr& ctx) {
        return handleGetAirConditionerPresence(ctx);
    });

    m_service.GET("/api/device/floor-heating/presence", [this](const HttpContextPtr& ctx) {
        return handleGetFloorHeatingPresence(ctx);
    });

    // ========== 故障检测API (v1.20新增) ==========
    m_service.GET("/api/device/faults", [this](const HttpContextPtr& ctx) {
        return handleGetDeviceFaults(ctx);
    });

    m_service.POST("/api/device/faults/clear", [this](const HttpContextPtr& ctx) {
        return handleClearDeviceFaults(ctx);
    });

    // ========== 关机下空气质量检测API (v1.20新增) ==========
    m_service.GET("/api/device/off-mode/air-quality", [this](const HttpContextPtr& ctx) {
        return handleGetOffModeAirQuality(ctx);
    });

    m_service.POST("/api/device/off-mode/air-quality", [this](const HttpContextPtr& ctx) {
        return handleSetOffModeAirQuality(ctx);
    });

    // ========== 加湿系统精细控制API (v1.20新增) ==========
    m_service.GET("/api/humidification/status", [this](const HttpContextPtr& ctx) {
        return handleGetHumidificationStatus(ctx);
    });

    m_service.POST("/api/humidification/control", [this](const HttpContextPtr& ctx) {
        return handleSetHumidificationControl(ctx);
    });

    // ========== 设备维护API (v1.20新增) ==========
    m_service.POST("/api/maintenance/fan/clear", [this](const HttpContextPtr& ctx) {
        return handleClearFanRuntime(ctx);
    });

    // ========== Modbus寄存器批量写入API (v1.20新增) ==========
    m_service.POST("/api/modbus/write-multiple", [this](const HttpContextPtr& ctx) {
        return handleWriteMultipleRegisters(ctx);
    });

    // ========== Modbus离散输入读取API (v1.20新增) ==========
    m_service.GET("/api/modbus/read-discrete", [this](const HttpContextPtr& ctx) {
        return handleReadDiscreteInputs(ctx);
    });

    if (m_mode == HttpServerMode::Full) {
        // ========== 传感器数据API ==========
        m_service.GET("/getSensors", [this](const HttpContextPtr& ctx) {
            return handleGetSensors(ctx);
        });

        m_service.GET("/getAirQuality", [this](const HttpContextPtr& ctx) {
            return handleGetAirQuality(ctx);
        });
    }

    // ========== 环境数据API (待机页面室内/室外数据) ==========
    m_service.GET("/api/idle/environment", [this](const HttpContextPtr& ctx) {
        return handleGetEnvironmentData(ctx);
    });

    // ========== 室内外空气评价提醒API (待机页面显示) ==========
    m_service.GET("/api/idle/air-quality-reminder", [this](const HttpContextPtr& ctx) {
        return handleGetAirQualityReminder(ctx);
    });

    // ========== 协议信息API (v1.20新增) ==========
    m_service.GET("/api/protocol/info", [this](const HttpContextPtr& ctx) {
        return handleGetProtocolInfo(ctx);
    });

    // 允许 CORS
    m_service.AllowCORS();

    // 输出所有注册的路由（调试用）
    auto paths = m_service.Paths();
    for (const auto& path : paths) {
        LOG_DEBUG("[HttpServer] Registered route: {}", path.c_str());
    }
    LOG_INFO("[HttpServer] Routes registered successfully ({} routes)", paths.size());
}

// API处理器实现
int HttpServerBasedOnLibhv::handleGetDeviceStatus(const HttpContextPtr& ctx)
{
    try {
        HomePage homePage(m_dataManager);
        std::string result = homePage.getHomeData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取设备状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleQuickPowerOn(const HttpContextPtr& ctx)
{
    try {
        const bool powerOn = ctx->json().value("power", true);
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        // 1000H 不是独立控制项：一键开启单写 1001H=1，互斥联动由设备端处理；
        // 关闭时用 10H 一次写入 1001H/1002H/1003H 全 0。
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitModuleState(
                powerOn, false, false, "set-device-power");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json data = {{"accepted", true}, {"power", powerOn}};
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制电源失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleQuickSetMode(const HttpContextPtr& ctx)
{
    try {
        const int mode = ctx->json().value("mode", 1);
        // v1.22新风运行模式0-5：0内循环 1内循环/混风 2全热新风/节能新风 3自动 4旁通/换气 5睡眠
        if (mode < 0 || mode > 5) {
            sendError(ctx, 400, "运行模式必须在0-5之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFreshControl(
                BeiAng4CPRegisters::FRESH_AIR_RUN_MODE,
                static_cast<uint16_t>(mode),
                "set-device-mode");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json data = {{"accepted", true}, {"mode", mode}};
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetLeaveHomeSwitch(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 一键离家开关参数：on（布尔）。开启=1、关闭=0，写入保持寄存器1006H
        if (!request.contains("on") || !request["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool on = request["on"].get<bool>();
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::LEAVE_HOME_SWITCH,
                on ? 1 : 0,
                "set-leave-home-switch")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const json data = {
            {"accepted", true},
            {"on", on}
        };
        LOG_INFO("[HttpServer] /api/device/leave-home -> on={}", on);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置一键离家开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetLeaveHomeStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& controlStatus = m_dataManager->getGatewayData().getControlStatus();

        json data;
        data["leaveHomeOn"] = controlStatus.leaveHomeOn;  // 1006H 一键离家开关

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取一键离家状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetWholeUnitRunMode(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 整机运行模式参数：mode（整数，0-5），写入保持寄存器100AH
        // 0:无(对应8寸：手动) 1:标准 2:会客 3:干爽 4:温润 5:旅行
        if (!request.contains("mode") || !request["mode"].is_number_integer()) {
            sendError(ctx, 400, "参数 mode（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int mode = request["mode"].get<int>();
        if (mode < 0 || mode > 5) {
            sendError(ctx, 400, "整机运行模式必须在0-5之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::WHOLE_UNIT_RUN_MODE,
                static_cast<uint16_t>(mode),
                "set-whole-unit-run-mode")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const json data = {
            {"accepted", true},
            {"mode", mode}
        };
        LOG_INFO("[HttpServer] /api/device/unit-run-mode -> mode={}", mode);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置整机运行模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetWholeUnitRunModeStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& controlStatus = m_dataManager->getGatewayData().getControlStatus();

        json data;
        data["wholeUnitRunMode"] = controlStatus.wholeUnitRunMode;  // 100AH 整机运行模式(0-5)

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取整机运行模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFreshAirSwitch(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 新风开关参数：on（布尔）。开启/关闭单写保持寄存器1001H，互斥由设备端处理
        if (!req.contains("on") || !req["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        bool on = req["on"].get<bool>();

        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitModuleSwitch(
                BeiAng4CPRegisters::FRESH_AIR_MODULE_SWITCH,
                on,
                "set-fresh-air-switch");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["on"] = on;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/freshair/switch -> on={}", on);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制新风开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetFreshAirStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& controlStatus = m_dataManager->getGatewayData().getControlStatus();

        json data;
        // v1.3.3 起按规格返回 6 个寄存器字段(移除原 1006H/201DH 两项)
        data["freshAirModuleOn"] = controlStatus.freshAirModuleOn;             // 1001H 新风模块开关
        data["runMode"] = static_cast<int>(controlStatus.runMode);             // 1007H 新风运行模式
        data["fanGear"] = controlStatus.fanGear;                               // 1008H 风量档位
        data["freshFanDutyCycle"] = controlStatus.freshFanDutyCycle;           // 100CH 新风风量占空比(0-100%)
        data["fanMaxGear"] = controlStatus.fanMaxGear;                         // 2003H 新风模式风量最大档位
        data["fanMaxGearRecirc"] = controlStatus.fanMaxGearRecirc;             // 2004H 内循环/混风模式风量最大档位

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取新风状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetHumidityModuleSwitch(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 调湿模块开关参数：on（布尔）。开启/关闭单写保持寄存器1003H，互斥由设备端处理
        if (!req.contains("on") || !req["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        bool on = req["on"].get<bool>();

        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitModuleSwitch(
                BeiAng4CPRegisters::HUMIDITY_MODULE_SWITCH,
                on,
                "set-humidity-module-switch");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["on"] = on;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/humidity-module/switch -> on={}", on);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制调湿模块开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetHumidityModuleStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& controlStatus = m_dataManager->getGatewayData().getControlStatus();
        auto& envSettings = m_dataManager->getGatewayData().getEnvironmentSettings();

        json data;
        data["humidityModuleOn"] = controlStatus.humidityModuleOn;  // 1003H 调湿模块开关
        data["humidificationOn"] = controlStatus.humidificationOn;  // 1004H 加湿开关
        data["dehumidificationOn"] = controlStatus.dehumidificationOn; // 1005H 除湿开关
        data["targetHumidity"] = envSettings.targetHumidity;        // 100FH 目标湿度设定（30-70）

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取调湿模块状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSuperPureSwitch(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 超净模式开关参数：on（布尔）。开启/关闭单写保持寄存器1002H，互斥由设备端处理
        if (!req.contains("on") || !req["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        bool on = req["on"].get<bool>();

        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitModuleSwitch(
                BeiAng4CPRegisters::SUPER_PURE_MODE_SWITCH,
                on,
                "set-super-pure-switch");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["on"] = on;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/super-pure/switch -> on={}", on);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制超净模式开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetSuperPureStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& controlStatus = m_dataManager->getGatewayData().getControlStatus();

        json data;
        data["superPureOn"] = controlStatus.superPureOn;  // 1002H 超净模式开关

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取超净模式状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFreshAirSpeed(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 风量档位参数：speed（整数，0-6），写入保持寄存器1008H
        if (!req.contains("speed") || !req["speed"].is_number_integer()) {
            sendError(ctx, 400, "参数 speed（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        int speed = req["speed"].get<int>();
        if (speed < 0 || speed > 6) {
            sendError(ctx, 400, "风量档位必须在0-6之间");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFreshControl(
                BeiAng4CPRegisters::FAN_GEAR,
                static_cast<uint16_t>(speed),
                "set-fresh-air-speed");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["speed"] = speed;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/freshair/speed -> speed={}", speed);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设定新风风速失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFreshAirRunMode(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 运行模式参数：mode（整数，0-5），写入保持寄存器1007H
        // v1.22：0内循环 1内循环/混风 2全热新风/节能新风 3自动 4旁通/换气 5睡眠
        if (!req.contains("mode") || !req["mode"].is_number_integer()) {
            sendError(ctx, 400, "参数 mode（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        int mode = req["mode"].get<int>();
        if (mode < 0 || mode > 5) {
            sendError(ctx, 400, "运行模式必须在0-5之间");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFreshControl(
                BeiAng4CPRegisters::FRESH_AIR_RUN_MODE,
                static_cast<uint16_t>(mode),
                "set-fresh-air-run-mode");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["mode"] = mode;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/freshair/runmode -> mode={}", mode);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置新风运行模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetHumidifySwitch(const HttpContextPtr& ctx)
{
    return submitHumiditySwitchRequest(
        ctx, BeiAng4CPRegisters::HUMIDIFICATION_SWITCH, "set-humidify-switch");
}

int HttpServerBasedOnLibhv::handleSetDehumidifySwitch(const HttpContextPtr& ctx)
{
    return submitHumiditySwitchRequest(
        ctx, BeiAng4CPRegisters::DEHUMIDIFICATION_SWITCH, "set-dehumidify-switch");
}

int HttpServerBasedOnLibhv::submitHumiditySwitchRequest(
    const HttpContextPtr& ctx, uint16_t address, const char* name)
{
    try {
        const json request = ctx->json();
        // 加湿/除湿开关参数：on（布尔）。开启=1、关闭=0
        if (!request.contains("on") || !request["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool on = request["on"].get<bool>();
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitHumiditySwitch(address, on, name);
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        const json data = {
            {"accepted", true},
            {"on", on}
        };
        LOG_INFO("[HttpServer] humidity switch {:#06x} -> on={}", address, on);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置加湿/除湿开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetExhaustFanSpeed(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 排风风量档位参数：speed（整数，0-6），写入保持寄存器1009H（协议预留）
        if (!request.contains("speed") || !request["speed"].is_number_integer()) {
            sendError(ctx, 400, "参数 speed（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int speed = request["speed"].get<int>();
        if (speed < 0 || speed > 6) {
            sendError(ctx, 400, "排风风量档位必须在0-6之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::EXHAUST_FAN_GEAR,
                static_cast<uint16_t>(speed),
                "set-exhaust-fan-speed")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const json data = {
            {"accepted", true},
            {"speed", speed}
        };
        LOG_INFO("[HttpServer] /api/freshair/exhaust-speed -> speed={}", speed);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设定排风风量档位失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSteplessFanControl(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 无极风量控制开关参数：on（布尔）。开启=1、关闭=0，写入保持寄存器100BH
        if (!request.contains("on") || !request["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool on = request["on"].get<bool>();
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::STEPLESS_FAN_CONTROL,
                on ? 1 : 0,
                "set-stepless-fan-control")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"on", on}};
        LOG_INFO("[HttpServer] /api/freshair/stepless -> on={}", on);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置无极风量开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFanDutyCycle(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 风量占空比参数：fresh/exhaust/boost（整数0-100，至少提供一个），
        // 分别写 100CH/100DH/100EH；未提供的通道不写。
        struct DutyChannel {
            const char* name;
            uint16_t address;
        };
        const DutyChannel channels[] = {
            {"fresh", BeiAng4CPRegisters::FRESH_FAN_DUTY_CYCLE},
            {"exhaust", BeiAng4CPRegisters::EXHAUST_FAN_DUTY_CYCLE},
            {"boost", BeiAng4CPRegisters::BOOST_FAN_DUTY_CYCLE}
        };
        int submitted = 0;
        for (const DutyChannel& channel : channels) {
            if (!request.contains(channel.name)) {
                continue;
            }
            if (!request[channel.name].is_number_integer()) {
                sendError(ctx, 400, std::string("参数 ") + channel.name + "（整数0-100）非法");
                return HTTP_STATUS_BAD_REQUEST;
            }
            const int duty = request[channel.name].get<int>();
            if (duty < 0 || duty > 100) {
                sendError(ctx, 400, std::string("参数 ") + channel.name + " 必须在0-100之间");
                return HTTP_STATUS_BAD_REQUEST;
            }
            if (!m_modbusCommandModule
                || !m_modbusCommandModule->submitSingleWrite(
                    channel.address,
                    static_cast<uint16_t>(duty),
                    "set-fan-duty-cycle")) {
                sendError(ctx, 503, "Modbus命令队列不可用或已满");
                return HTTP_STATUS_SERVICE_UNAVAILABLE;
            }
            submitted++;
        }
        if (submitted == 0) {
            sendError(ctx, 400, "至少提供 fresh/exhaust/boost 中的一个参数（0-100）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const json data = {{"accepted", true}, {"count", submitted}};
        LOG_INFO("[HttpServer] /api/freshair/duty -> {} channel(s)", submitted);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置风量占空比失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetTargetTemperature(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 目标温度参数：temperature（数值，16.0-31.0℃），寄存器1010H存实际温度×10（160-310）
        if (!request.contains("temperature")
            || !request["temperature"].is_number()) {
            sendError(ctx, 400, "参数 temperature（数值，16.0-31.0）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const double temperature = request["temperature"].get<double>();
        const int raw = static_cast<int>(temperature * 10);
        if (raw < 160 || raw > 310) {
            sendError(ctx, 400, "目标温度必须在16.0-31.0之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::TARGET_TEMPERATURE,
                static_cast<uint16_t>(raw),
                "set-target-temperature")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {
            {"accepted", true},
            {"temperature", temperature},
            {"raw", raw}
        };
        LOG_INFO("[HttpServer] /api/device/target-temperature -> {}C (raw {})", temperature, raw);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设定目标温度失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetPlasmaDisinfect(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 等离子消毒开关参数：enabled（布尔），写保持寄存器1011H
        if (!request.contains("enabled") || !request["enabled"].is_boolean()) {
            sendError(ctx, 400, "参数 enabled（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool enabled = request["enabled"].get<bool>();
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::PLASMA_DISINFECT_SWITCH,
                enabled ? 1 : 0,
                "set-plasma-disinfect")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"enabled", enabled}};
        LOG_INFO("[HttpServer] /api/device/plasma-disinfect -> enabled={}", enabled);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置等离子消毒失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetAuxHeat(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 电辅热选择参数：mode（整数0-3），写保持寄存器1013H
        if (!request.contains("mode") || !request["mode"].is_number_integer()) {
            sendError(ctx, 400, "参数 mode（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int mode = request["mode"].get<int>();
        if (mode < 0 || mode > 3) {
            sendError(ctx, 400, "电辅热模式必须在0-3之间（0关/1辅热1/2辅热2/3辅热1+2）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::AUX_HEAT,
                static_cast<uint16_t>(mode),
                "set-aux-heat")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"mode", mode}};
        LOG_INFO("[HttpServer] /api/device/aux-heat -> mode={}", mode);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置电辅热失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetHumidityIntensity(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 加湿/除湿强度参数：intensity（整数0-2），写保持寄存器1014H
        if (!request.contains("intensity")
            || !request["intensity"].is_number_integer()) {
            sendError(ctx, 400, "参数 intensity（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int intensity = request["intensity"].get<int>();
        if (intensity < 0 || intensity > 2) {
            sendError(ctx, 400, "加湿/除湿强度必须在0-2之间（0弱/1中/2强）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::HUMIDITY_INTENSITY,
                static_cast<uint16_t>(intensity),
                "set-humidity-intensity")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"intensity", intensity}};
        LOG_INFO("[HttpServer] /api/humidity-module/intensity -> intensity={}", intensity);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置加湿/除湿强度失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSaFanRatio(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // SA风量与增压风机比例参数：ratio（数值，实际值×10写入1015H，例1.8写18）
        if (!request.contains("ratio") || !request["ratio"].is_number()) {
            sendError(ctx, 400, "参数 ratio（数值）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const double ratio = request["ratio"].get<double>();
        const int raw = static_cast<int>(ratio * 10);
        if (ratio < 0 || raw > 65535) {
            sendError(ctx, 400, "SA风量比例超出寄存器范围");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::SA_FAN_RATIO,
                static_cast<uint16_t>(raw),
                "set-sa-fan-ratio")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {
            {"accepted", true},
            {"ratio", ratio},
            {"raw", raw}
        };
        LOG_INFO("[HttpServer] /api/device/sa-fan-ratio -> {} (raw {})", ratio, raw);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置SA风量比例失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFanDelayOff(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 关机后延时关风机时间参数：minutes（整数，0-65535），写保持寄存器1020H
        if (!request.contains("minutes") || !request["minutes"].is_number_integer()) {
            sendError(ctx, 400, "参数 minutes（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int minutes = request["minutes"].get<int>();
        if (minutes < 0 || minutes > 65535) {
            sendError(ctx, 400, "延时时间超出范围（0-65535分钟）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::FAN_DELAY_OFF_TIME,
                static_cast<uint16_t>(minutes),
                "set-fan-delay-off")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"minutes", minutes}};
        LOG_INFO("[HttpServer] /api/device/fan-delay-off -> minutes={}", minutes);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置延时关风机时间失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetCompressorSettings(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 压缩机设定参数（均可选，至少一项）：
        // eevOpening 0-500（1028H）/ frequencySet 0-90Hz（1029H）/ frequencyMax 60-95Hz（102AH）
        struct Item {
            const char* name;
            uint16_t address;
            int minValue;
            int maxValue;
            const char* rangeMessage;
        };
        const Item items[] = {
            {"eevOpening", BeiAng4CPRegisters::COMPRESSOR_EEV_OPENING, 0, 500, "电子膨胀阀开度必须在0-500之间"},
            {"frequencySet", BeiAng4CPRegisters::COMPRESSOR_FREQUENCY_SET, 0, 90, "运行频率设定值必须在0-90Hz之间"},
            {"frequencyMax", BeiAng4CPRegisters::COMPRESSOR_FREQUENCY_MAX, 60, 95, "频率上限设定值必须在60-95Hz之间"}
        };
        int submitted = 0;
        json updated = json::array();
        for (const Item& item : items) {
            if (!request.contains(item.name)) {
                continue;
            }
            if (!request[item.name].is_number_integer()) {
                sendError(ctx, 400, std::string("参数 ") + item.name + "（整数）非法");
                return HTTP_STATUS_BAD_REQUEST;
            }
            const int value = request[item.name].get<int>();
            if (value < item.minValue || value > item.maxValue) {
                sendError(ctx, 400, item.rangeMessage);
                return HTTP_STATUS_BAD_REQUEST;
            }
            if (!m_modbusCommandModule
                || !m_modbusCommandModule->submitSingleWrite(
                    item.address,
                    static_cast<uint16_t>(value),
                    "set-compressor-settings")) {
                sendError(ctx, 503, "Modbus命令队列不可用或已满");
                return HTTP_STATUS_SERVICE_UNAVAILABLE;
            }
            updated.push_back(item.name);
            submitted++;
        }
        if (submitted == 0) {
            sendError(ctx, 400, "至少提供 eevOpening/frequencySet/frequencyMax 中的一个参数");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const json data = {{"accepted", true}, {"updated", updated}};
        LOG_INFO("[HttpServer] /api/device/compressor -> {} item(s)", submitted);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置压缩机参数失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFactoryTestMode(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 厂测模式参数：enabled（布尔，必填）；开启时必须附带 confirm=true，
        // 防止正常业务误入厂测模式（1030H=100 会开放高低压开关/FAN/阀门写权限）。
        if (!request.contains("enabled") || !request["enabled"].is_boolean()) {
            sendError(ctx, 400, "参数 enabled（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool enabled = request["enabled"].get<bool>();
        if (enabled && !request.value("confirm", false)) {
            sendError(ctx, 400, "进入厂测模式需要 confirm=true（仅产线调试使用）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::FACTORY_TEST_MODE,
                enabled ? FACTORY_TEST_MODE_VALUE : 0,
                "set-factory-test-mode")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}, {"enabled", enabled}};
        LOG_INFO("[HttpServer] /api/device/factory-test -> enabled={} (confirm)", enabled);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置厂测模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetFactoryTestStatus(const HttpContextPtr& ctx)
{
    try {
        DataManager::DataLock dataLock(*m_dataManager);
        auto& deviceInfo = m_dataManager->getGatewayData().getDeviceInfo();

        // 1030H 原值 + 100==测试模式判定（厂测锁接口 102BH/1038H-103EH/
        // 1041H-1076H 的可写性由此决定）
        json data;
        data["factoryTestMode"] = deviceInfo.factoryTestMode;
        data["factoryTestActive"] = deviceInfo.factoryTestActive;

        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取厂测模式状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetPressureSwitch(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 高/低压开关参数：switch("high"/"low") + on（布尔）。仅厂测模式（1030H=100）可写。
        if (!request.contains("switch")
            || !request["switch"].is_string()) {
            sendError(ctx, 400, "参数 switch 必填（取值 high 或 low）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("on") || !request["on"].is_boolean()) {
            sendError(ctx, 400, "参数 on（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const std::string which = request["switch"].get<std::string>();
        const uint16_t address = which == "high"
            ? BeiAng4CPRegisters::HIGH_PRESSURE_SWITCH
            : (which == "low" ? BeiAng4CPRegisters::LOW_PRESSURE_SWITCH : 0);
        if (address == 0) {
            sendError(ctx, 400, "参数 switch 只能是 high 或 low");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool on = request["on"].get<bool>();
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFactoryWrite(
                address, on ? 1 : 0, "set-pressure-switch");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }
        const json data = {{"accepted", true}, {"switch", which}, {"on", on}};
        LOG_INFO("[HttpServer] /api/device/pressure-switch -> {} on={}", which, on);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置高/低压开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFactoryFan(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 厂测FAN风量设定参数：fan（1-4）+ value（整数）。仅厂测模式（1030H=100）可写。
        if (!request.contains("fan") || !request["fan"].is_number_integer()) {
            sendError(ctx, 400, "参数 fan（整数1-4）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("value") || !request["value"].is_number_integer()) {
            sendError(ctx, 400, "参数 value（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int fan = request["fan"].get<int>();
        const int value = request["value"].get<int>();
        if (fan < 1 || fan > 4) {
            sendError(ctx, 400, "fan 必须在1-4之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (value < 0 || value > 65535) {
            sendError(ctx, 400, "value 超出16位范围");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const uint16_t address = static_cast<uint16_t>(
            BeiAng4CPRegisters::FAN1_CURRENT_SETTING + (fan - 1));
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFactoryWrite(
                address, static_cast<uint16_t>(value), "set-factory-fan");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }
        const json data = {{"accepted", true}, {"fan", fan}, {"value", value}};
        LOG_INFO("[HttpServer] /api/factory/fan -> fan={} value={}", fan, value);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置厂测FAN风量失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFactoryValve(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 厂测阀门状态设定参数：valve（1-3）+ status（0关/1半开/2全开）。仅厂测模式可写。
        if (!request.contains("valve") || !request["valve"].is_number_integer()) {
            sendError(ctx, 400, "参数 valve（整数1-3）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("status") || !request["status"].is_number_integer()) {
            sendError(ctx, 400, "参数 status（整数0-2）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int valve = request["valve"].get<int>();
        const int status = request["status"].get<int>();
        if (valve < 1 || valve > 3) {
            sendError(ctx, 400, "valve 必须在1-3之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (status < 0 || status > 2) {
            sendError(ctx, 400, "阀门状态必须在0-2之间（0关/1半开/2全开）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const uint16_t address = static_cast<uint16_t>(
            BeiAng4CPRegisters::VALVE1_STATUS_SETTING + (valve - 1));
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFactoryWrite(
                address, static_cast<uint16_t>(status), "set-factory-valve");
        if (!result.accepted()) {
            const int status2 = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status2, result.message);
            return status2;
        }
        const json data = {{"accepted", true}, {"valve", valve}, {"status", status}};
        LOG_INFO("[HttpServer] /api/factory/valve -> valve={} status={}", valve, status);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置厂测阀门失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFilterRemaining(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 滤网/保养剩余时间参数（均可选，至少一项），单位：滤网/加湿/IEF为小时，整机保养为天。
        // 用于复位滤网提醒：写入新的剩余时长。
        struct FilterItem {
            const char* name;
            uint16_t address;
        };
        const FilterItem items[] = {
            {"filter1", BeiAng4CPRegisters::FILTER1_REMAINING_TIME},        // 1031H 初效滤网1(小时)
            {"filter2", BeiAng4CPRegisters::FILTER2_REMAINING_TIME},        // 1032H 中效滤网2(小时)
            {"filter3", BeiAng4CPRegisters::FILTER3_REMAINING_TIME},        // 1033H 高效滤网3(小时)
            {"humidityModule", BeiAng4CPRegisters::HUMIDITY_FILTER_REMAINING_TIME}, // 1034H 加湿模块(小时)
            {"ief", BeiAng4CPRegisters::IEF_CLEAN_REMAINING_TIME},          // 1035H IEF需清洗(小时)
            {"wholeUnit", BeiAng4CPRegisters::WHOLE_UNIT_MAINTENANCE_TIME}  // 1036H 整机保养(天)
        };
        int submitted = 0;
        json updated = json::array();
        for (const FilterItem& item : items) {
            if (!request.contains(item.name)) {
                continue;
            }
            if (!request[item.name].is_number_integer()) {
                sendError(ctx, 400, std::string("参数 ") + item.name + "（整数）非法");
                return HTTP_STATUS_BAD_REQUEST;
            }
            const int value = request[item.name].get<int>();
            if (value < 0 || value > 65535) {
                sendError(ctx, 400, "剩余时间超出范围（0-65535）");
                return HTTP_STATUS_BAD_REQUEST;
            }
            if (!m_modbusCommandModule
                || !m_modbusCommandModule->submitSingleWrite(
                    item.address,
                    static_cast<uint16_t>(value),
                    "set-filter-remaining")) {
                sendError(ctx, 503, "Modbus命令队列不可用或已满");
                return HTTP_STATUS_SERVICE_UNAVAILABLE;
            }
            updated.push_back(item.name);
            submitted++;
        }
        if (submitted == 0) {
            sendError(ctx, 400, "至少提供 filter1/filter2/filter3/humidityModule/ief/wholeUnit 中的一个参数");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const json data = {{"accepted", true}, {"updated", updated}};
        LOG_INFO("[HttpServer] /api/maintenance/filter -> {} item(s)", submitted);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置滤网剩余时间失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleFactoryReset(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 恢复出厂（1040H 只写）：写1触发整机恢复出厂，所有参数重置。
        // 高危操作，必须显式携带 confirm=true，正常业务严禁调用。
        if (!request.value("confirm", false)) {
            sendError(ctx, 400, "恢复出厂需要 confirm=true（高危操作，整机参数将重置）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::RESTORE_FACTORY,
                1,
                "factory-reset")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const json data = {{"accepted", true}};
        LOG_INFO("[HttpServer] /api/device/factory-reset -> confirmed");
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("恢复出厂失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFactoryFanFlow(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // FAN内外循环各档风量标定参数：fan(1-4) + circulation("external"/"internal")
        // + gear(1-6) + value(0-65535)。仅厂测模式（1030H=100）可写，产线标定用。
        if (!request.contains("fan") || !request["fan"].is_number_integer()) {
            sendError(ctx, 400, "参数 fan（整数1-4）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("circulation")
            || !request["circulation"].is_string()) {
            sendError(ctx, 400, "参数 circulation 必填（取值 external 或 internal）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("gear") || !request["gear"].is_number_integer()) {
            sendError(ctx, 400, "参数 gear（整数1-6）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!request.contains("value") || !request["value"].is_number_integer()) {
            sendError(ctx, 400, "参数 value（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int fan = request["fan"].get<int>();
        const std::string circulation = request["circulation"].get<std::string>();
        const int gear = request["gear"].get<int>();
        const int value = request["value"].get<int>();
        if (fan < 1 || fan > 4) {
            sendError(ctx, 400, "fan 必须在1-4之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool external = circulation == "external";
        const bool internal = circulation == "internal";
        if (!external && !internal) {
            sendError(ctx, 400, "参数 circulation 只能是 external 或 internal");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (gear < 1 || gear > 6) {
            sendError(ctx, 400, "gear 必须在1-6之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (value < 0 || value > 65535) {
            sendError(ctx, 400, "value 超出16位范围");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const uint16_t fanBase[4] = {
            BeiAng4CPRegisters::FAN1_EXTERNAL_GEAR_FLOW,
            BeiAng4CPRegisters::FAN2_EXTERNAL_GEAR_FLOW,
            BeiAng4CPRegisters::FAN3_EXTERNAL_GEAR_FLOW,
            BeiAng4CPRegisters::FAN4_EXTERNAL_GEAR_FLOW
        };
        const uint16_t address = static_cast<uint16_t>(
            fanBase[fan - 1] + (external ? 0 : 6) + (gear - 1));
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFactoryWrite(
                address, static_cast<uint16_t>(value), "set-factory-fan-flow");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }
        const json data = {
            {"accepted", true},
            {"fan", fan},
            {"circulation", circulation},
            {"gear", gear},
            {"value", value}
        };
        LOG_INFO("[HttpServer] /api/factory/fan-flow -> fan={} {} gear={} value={}",
            fan, circulation, gear, value);
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置风量标定值失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetFactoryDamper(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // 风阀电机参数：damper(1-3) + direction(0/1，可选) + steps(0-65535，可选)，
        // 至少一项。仅厂测模式（1030H=100）可写，与阀门状态设定（103CH-103EH）配套。
        if (!request.contains("damper")
            || !request["damper"].is_number_integer()) {
            sendError(ctx, 400, "参数 damper（整数1-3）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int damper = request["damper"].get<int>();
        if (damper < 1 || damper > 3) {
            sendError(ctx, 400, "damper 必须在1-3之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        bool hasDirection = request.contains("direction");
        bool hasSteps = request.contains("steps");
        if (!hasDirection && !hasSteps) {
            sendError(ctx, 400, "至少提供 direction（0/1）或 steps（整数）中的一个参数");
            return HTTP_STATUS_BAD_REQUEST;
        }
        int direction = -1;
        if (hasDirection) {
            if (!request["direction"].is_number_integer()) {
                sendError(ctx, 400, "参数 direction（整数0/1）非法");
                return HTTP_STATUS_BAD_REQUEST;
            }
            direction = request["direction"].get<int>();
            if (direction != 0 && direction != 1) {
                sendError(ctx, 400, "direction 只能是 0 或 1");
                return HTTP_STATUS_BAD_REQUEST;
            }
        }
        int steps = -1;
        if (hasSteps) {
            if (!request["steps"].is_number_integer()) {
                sendError(ctx, 400, "参数 steps（整数）非法");
                return HTTP_STATUS_BAD_REQUEST;
            }
            steps = request["steps"].get<int>();
            if (steps < 0 || steps > 65535) {
                sendError(ctx, 400, "steps 超出16位范围");
                return HTTP_STATUS_BAD_REQUEST;
            }
        }
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        json updated = json::array();
        if (hasDirection) {
            const uint16_t address = static_cast<uint16_t>(
                BeiAng4CPRegisters::DAMPER1_DIRECTION_SETTING + (damper - 1));
            const ModbusCommandSubmitResult result =
                m_modbusCommandModule->submitFactoryWrite(
                    address, static_cast<uint16_t>(direction),
                    "set-factory-damper-direction");
            if (!result.accepted()) {
                const int status = result.status == ModbusCommandSubmitStatus::Rejected
                    ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
                sendError(ctx, status, result.message);
                return status;
            }
            updated.push_back("direction");
        }
        if (hasSteps) {
            const uint16_t address = static_cast<uint16_t>(
                BeiAng4CPRegisters::DAMPER1_STEPS_SETTING + (damper - 1));
            const ModbusCommandSubmitResult result =
                m_modbusCommandModule->submitFactoryWrite(
                    address, static_cast<uint16_t>(steps),
                    "set-factory-damper-steps");
            if (!result.accepted()) {
                const int status = result.status == ModbusCommandSubmitStatus::Rejected
                    ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
                sendError(ctx, status, result.message);
                return status;
            }
            updated.push_back("steps");
        }
        const json data = {
            {"accepted", true},
            {"damper", damper},
            {"updated", updated}
        };
        LOG_INFO("[HttpServer] /api/factory/damper -> damper={} {}", damper, updated.dump());
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置风阀参数失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetTargetHumidity(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        // 目标湿度参数：humidity（整数，30-70），写入保持寄存器100FH
        if (!req.contains("humidity") || !req["humidity"].is_number_integer()) {
            sendError(ctx, 400, "参数 humidity（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        int humidity = req["humidity"].get<int>();
        if (humidity < 30 || humidity > 70) {
            sendError(ctx, 400, "目标湿度必须在30-70之间");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::TARGET_HUMIDITY,
                static_cast<uint16_t>(humidity),
                "set-target-humidity")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json response = json::object();
        json data = json::object();
        data["accepted"] = true;
        data["humidity"] = humidity;
        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        LOG_INFO("[HttpServer] /api/humidity-module/target -> humidity={}", humidity);
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设定目标湿度失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetManualMode(const HttpContextPtr& ctx)
{
    try {
        ManualModePage manualPage(m_dataManager);
        std::string result = manualPage.getManualModeData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取手动模式数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetManualMode(const HttpContextPtr& ctx)
{
    try {
        std::string body = ctx->body();
        ManualModePage manualPage(m_dataManager);
        std::string result = manualPage.setManualModeParams(body);
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置手动模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetSmartMode(const HttpContextPtr& ctx)
{
    try {
        SmartModePage smartPage(m_dataManager);
        std::string result = smartPage.getSmartModeData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取智能模式数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSmartMode(const HttpContextPtr& ctx)
{
    try {
        std::string body = ctx->body();
        SmartModePage smartPage(m_dataManager);
        std::string result = smartPage.setSmartModeParams(body);
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置智能模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetIdleMode(const HttpContextPtr& ctx)
{
    try {
        IdlePage idlePage(m_dataManager);
        std::string result = idlePage.getIdlePageData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取待机模式数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetIdleMode(const HttpContextPtr& ctx)
{
    try {
        IdlePage idlePage(m_dataManager);
        std::string result = idlePage.wakeUp();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("唤醒设备失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetSystemSettings(const HttpContextPtr& ctx)
{
    try {
        SystemSettingsPage settingsPage(m_dataManager);
        std::string result = settingsPage.getSystemSettings();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取系统设置失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSystemSettings(const HttpContextPtr& ctx)
{
    try {
        std::string body = ctx->body();
        SystemSettingsPage settingsPage(m_dataManager);
        std::string result = settingsPage.setSystemSettings(body);
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置系统参数失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetDeviceMaintenance(const HttpContextPtr& ctx)
{
    try {
        DeviceMaintenancePage maintenancePage(m_dataManager);
        std::string result = maintenancePage.getFilterStatus();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取维护状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleResetFilter(const HttpContextPtr& ctx)
{
    try {
        DeviceMaintenancePage maintenancePage(m_dataManager);
        std::string result = maintenancePage.resetFilterLife();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("重置滤网失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetEngineeringMode(const HttpContextPtr& ctx)
{
    try {
        EngineeringModePage engPage(m_dataManager);
        std::string result = engPage.getEngineeringModeData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取工程模式数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetEngineeringMode(const HttpContextPtr& ctx)
{
    sendError(ctx, 501, "工程模式控制尚未实现");
    return HTTP_STATUS_NOT_IMPLEMENTED;
}

int HttpServerBasedOnLibhv::handleSetFreshAirMode(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        // v1.22：1006H 不再是手动/自动，"自动"是 1007H 的取值 3。
        // 首选参数 mode（0-5）；兼容旧客户端的 automatic（布尔）：
        // automatic=true 映射 mode=3（自动模式），false 时保持当前运行模式不变。
        int mode = -1;
        if (request.contains("mode") && request["mode"].is_number_integer()) {
            mode = request["mode"].get<int>();
        } else if (request.contains("automatic")
            && request["automatic"].is_boolean()) {
            if (request["automatic"].get<bool>()) {
                mode = 3; // 自动模式
            } else {
                DataManager::DataLock dataLock(*m_dataManager);
                mode = static_cast<int>(
                    m_dataManager->getGatewayData()
                        .getControlStatus().runMode);
            }
        }
        if (mode < 0 || mode > 5) {
            sendError(ctx, 400, "参数 mode（整数，0-5）或 automatic（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!m_modbusCommandModule) {
            sendError(ctx, 503, "Modbus命令队列不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const ModbusCommandSubmitResult result =
            m_modbusCommandModule->submitFreshRunMode(
                static_cast<uint16_t>(mode),
                "set-fresh-air-mode");
        if (!result.accepted()) {
            const int status = result.status == ModbusCommandSubmitStatus::Rejected
                ? HTTP_STATUS_BAD_REQUEST : HTTP_STATUS_SERVICE_UNAVAILABLE;
            sendError(ctx, status, result.message);
            return status;
        }

        const json data = {
            {"accepted", true},
            {"mode", mode}
        };
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置新风模式失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetHistoryTrend(const HttpContextPtr& ctx)
{
    try {
        const std::string range = ctx->param("range", "");
        if (range != "day" && range != "week" && range != "month") {
            sendError(ctx, 400, "range 参数必须为 day/week/month");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const std::string date = ctx->param("date", "");
        if (!date.empty() && !isValidDateString(date)) {
            sendError(ctx, 400, "date 参数格式必须为 YYYY-MM-DD");
            return HTTP_STATUS_BAD_REQUEST;
        }

        HistoryTrendPage historyPage(m_dataManager);
        ctx->send(buildSuccessResponse(historyPage.getTrendData(range, date)));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取历史趋势失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetHistoryStatus(const HttpContextPtr& ctx)
{
    try {
        HistoryTrendPage historyPage(m_dataManager);
        ctx->send(buildSuccessResponse(historyPage.getStatusData()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取历史趋势状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetMemWatchStatus(const HttpContextPtr& ctx)
{
    try {
        MemoryWatchModule* memWatch = m_dataManager->getMemoryWatchModule();
        if (!memWatch) {
            sendError(ctx, 500, "内存水位监控模块未初始化");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }
        ctx->send(buildSuccessResponse(memWatch->getStatusJson().dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取内存监控状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// 响应构建方法
std::string HttpServerBasedOnLibhv::buildSuccessResponse(const std::string& data)
{
    std::string response;
    if (!data.empty() && (data[0] == '{' || data[0] == '[')) {
        response = data;
    } else {
        response = "{\"code\":0,\"message\":\"success\",\"data\":" + data + "}";
    }
    // 添加换行符以改善命令行显示
    response += "\n";
    return response;
}

std::string HttpServerBasedOnLibhv::buildErrorResponse(int code, const std::string& message)
{
    std::string response = "{\"code\":" + std::to_string(code) + ",\"message\":\"" + message + "\"}";
    // 添加换行符以改善命令行显示
    response += "\n";
    return response;
}

// 发送错误响应并设置真实 HTTP 状态码（400/500/503）。
// 此前仅返回 HTTP 200 + body.code；为符合 HTTP 语义（前端/网关/探针依赖状态码），
// 统一通过此助手设置 status_code 后再 send。
void HttpServerBasedOnLibhv::sendError(const HttpContextPtr& ctx, int code, const std::string& message)
{
    ctx->setStatus(static_cast<http_status>(code));
    ctx->send(buildErrorResponse(code, message));
}

// ========== 测试接口处理器实现 ==========

int HttpServerBasedOnLibhv::handlePing(const HttpContextPtr& ctx)
{
    // 简单的ping响应，返回pong
    ctx->send(buildSuccessResponse("{\"pong\":true}"));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleHealth(const HttpContextPtr& ctx)
{
    // 健康检查，返回服务器状态信息
    std::ostringstream json;
    json << "{"
         << "\"status\":\"" << (m_isRunning ? "ok" : "error") << "\","
         << "\"server\":\"running\","
         << "\"port\":" << m_port << ","
         << "\"uptime\":\""
         << "unknown"
         << "\""
         << "}";
    ctx->send(buildSuccessResponse(json.str()));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleVersion(const HttpContextPtr& ctx)
{
    // 版本信息
    std::ostringstream json;
    json << "{"
         << "\"version\":\"" << BEIANG_8PANEL_VERSION << "\","
         << "\"name\":\"BeiAng8Panel\","
         << "\"description\":\"BeiAng 4CP Air Purifier Controller Panel Backend Service\""
         << "}";
    ctx->send(buildSuccessResponse(json.str()));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handlePaths(const HttpContextPtr& ctx)
{
    // 获取所有已注册的 API 路径
    auto paths = m_service.Paths();

    // 构建 JSON 数组
    std::ostringstream json;
    json << "[";
    bool first = true;
    for (const auto& path : paths) {
        if (!first) {
            json << ",";
        }
        json << "\"" << path.c_str() << "\"";
        first = false;
    }
    json << "]";

    ctx->send(buildSuccessResponse(json.str()));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleCommunicationStatus(const HttpContextPtr& ctx)
{
    if (!m_communicationChannel) {
        sendError(ctx, 503, "通信通道不可用");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }

    json result = {
        {"running", m_communicationChannel->isRunning()},
        {"transport", m_communicationChannel->getTransportName()},
        {"pendingReads", m_communicationChannel->pendingReadCount()},
        {"pendingWrites", m_communicationChannel->pendingWriteCount()},
        {"lastRead", m_communicationChannel->getLastReadHex()},
        {"error", m_communicationChannel->getLastError()}
    };
    ctx->send(buildSuccessResponse(result.dump()));
    return HTTP_STATUS_OK;
}

static bool parseCommunicationFrame(
    const std::string& body, std::vector<uint8_t>& frame, std::string& error)
{
    try {
        const json request = json::parse(body);
        if (!request.contains("frame") || !request["frame"].is_array()
            || request["frame"].empty()) {
            error = "frame 必须是非空字节数组";
            return false;
        }
        for (const auto& value : request["frame"]) {
            if (!value.is_number_integer() || value.get<int>() < 0
                || value.get<int>() > 255) {
                error = "frame 只能包含 0-255 的整数";
                return false;
            }
            frame.push_back(static_cast<uint8_t>(value.get<int>()));
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("JSON 解析错误: ") + e.what();
        return false;
    }
}

int HttpServerBasedOnLibhv::handleCommunicationRead(const HttpContextPtr& ctx)
{
    if (!m_communicationChannel) {
        sendError(ctx, 503, "通信通道不可用");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }

    std::vector<uint8_t> frame;
    std::string error;
    if (!parseCommunicationFrame(ctx->body(), frame, error)) {
        sendError(ctx, 400, error);
        return HTTP_STATUS_BAD_REQUEST;
    }
    if (!m_communicationChannel->submitRead(std::move(frame))) {
        sendError(ctx, 503, "通信读取队列不可用或已满");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    ctx->send(buildSuccessResponse("{\"accepted\":true}"));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleCommunicationWrite(const HttpContextPtr& ctx)
{
    if (!m_communicationChannel) {
        sendError(ctx, 503, "通信通道不可用");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }

    std::vector<uint8_t> frame;
    std::string error;
    if (!parseCommunicationFrame(ctx->body(), frame, error)) {
        sendError(ctx, 400, error);
        return HTTP_STATUS_BAD_REQUEST;
    }
    if (!m_communicationChannel->submitWrite(std::move(frame))) {
        sendError(ctx, 503, "通信写入队列不可用或已满");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    ctx->send(buildSuccessResponse("{\"accepted\":true}"));
    return HTTP_STATUS_OK;
}

// ========== WiFi接口处理器实现 ==========

int HttpServerBasedOnLibhv::handleGetWifiInfo(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = json::array();
        for (const WifiNetworkData& network : data.wifi.scanResults) {
            result.push_back({
                {"ssid", network.ssid},
                {"rssi", network.rssi},
                {"secured", network.secured}
            });
        }
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取WiFi列表失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetConnectedWifi(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = {
            {"available", data.wifi.available},
            {"enabled", data.wifi.enabled},
            {"connected", data.wifi.connected},
            {"ssid", data.wifi.connectedSsid},
            {"ip", data.wifi.ipAddress},
            {"rssi", data.wifi.rssi},
            {"state", data.wifi.state},
            {"pending", data.wifi.commandPending},
            {"error", data.wifi.lastError},
            {"timestamp", data.wifi.timestamp}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取已连接WiFi失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleWifiOpen(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        bool open = true;
        if (request.contains("enabled") && request["enabled"].is_boolean()) {
            open = request["enabled"].get<bool>();
        } else if (request.contains("open") && request["open"].is_boolean()) {
            open = request["open"].get<bool>();
        }
        WifiCommand command;
        command.type = WifiCommandType::SetEnabled;
        command.enabled = open;
        if (!m_wifiManager || !m_wifiManager->submitCommand(std::move(command))) {
            sendError(ctx, 503, "WiFi系统接口不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {{"enabled", open}, {"open", open}, {"accepted", true}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("开关WiFi失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleDisconnectWifi(const HttpContextPtr& ctx)
{
    try {
        // 无body时ctx->json()为null, value()会抛异常; 断开本就无需参数
        std::string ssid;
        const json body = ctx->json();
        if (body.is_object()) {
            ssid = body.value("ssid", "");
        }
        WifiCommand command;
        command.type = WifiCommandType::Disconnect;
        command.ssid = ssid;
        if (!m_wifiManager || !m_wifiManager->submitCommand(std::move(command))) {
            sendError(ctx, 503, "WiFi系统接口不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {{"ssid", ssid}, {"accepted", true}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("断开WiFi失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleConnectWifi(const HttpContextPtr& ctx)
{
    try {
        std::string ssid = ctx->json().value("ssid", "");
        std::string password = ctx->json().value("password", "");
        if (ssid.empty()) {
            sendError(ctx, 400, "SSID不能为空");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (ssid.size() > 64 || password.size() > 128) {
            sendError(ctx, 400, "SSID或密码长度超出限制");
            return HTTP_STATUS_BAD_REQUEST;
        }

        WifiCommand command;
        command.type = WifiCommandType::Connect;
        command.ssid = ssid;
        command.password = std::move(password);
        if (!m_wifiManager || !m_wifiManager->submitCommand(std::move(command))) {
            sendError(ctx, 503, "WiFi系统接口不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {{"ssid", ssid}, {"accepted", true}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("连接WiFi失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetRuntimeSnapshot(const HttpContextPtr& ctx)
{
    try {
        // DataManager 内一次复制，释放锁后再组装 JSON。
        BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        json protocol = json::parse(snapshot.gatewayData.toJson());
        json environment = json::parse(snapshot.environmentData.toJson());
        protocol["faults"] = confirmedFaultsToJson(snapshot.registerCache);
        protocol["notifications"] =
            confirmedNotificationsToJson(snapshot.registerCache);

        json data;
        data["protocol"] = std::move(protocol);
        data["environment"] = std::move(environment);
        data["localDevice"] = localDeviceSnapshotToJson(snapshot.localDeviceData);
        data["cache"] = registerCacheToJson(snapshot.registerCache);
        data["dataFresh"] = snapshot.dataFresh;
        data["commandQueue"] = {
            {"modbusPending", m_modbusCommandModule
                ? m_modbusCommandModule->pendingCount() : 0}
        };

        json response = {
            {"code", 0},
            {"message", "success"},
            {"data", std::move(data)}
        };
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取运行快照失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetIefPurification(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        if (!request.contains("enabled") || !request["enabled"].is_boolean()) {
            sendError(ctx, 400, "参数 enabled（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }

        const bool enabled = request["enabled"].get<bool>();
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::IEF_SWITCH,
                enabled ? 1 : 0,
                "set-ief-purification")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json data = {
            {"accepted", true},
            {"enabled", enabled}
        };
        ctx->send(buildSuccessResponse(data.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("提交IEF控制失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleScanWifi(const HttpContextPtr& ctx)
{
    WifiCommand command;
    command.type = WifiCommandType::Scan;
    if (!m_wifiManager || !m_wifiManager->submitCommand(std::move(command))) {
        sendError(ctx, 503, "WiFi系统接口不可用");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }

    ctx->send(buildSuccessResponse("{\"accepted\":true}"));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleGetLocalDeviceStatus(const HttpContextPtr& ctx)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    json result = localDeviceSnapshotToJson(data);
    ctx->send(buildSuccessResponse(result.dump()));
    return HTTP_STATUS_OK;
}

void HttpServerBasedOnLibhv::setRs485Control(
    std::function<bool(bool)> setter, std::function<bool()> query)
{
    m_rs485Setter = std::move(setter);
    m_rs485Query = std::move(query);
}

// ========== 网络设置模块处理器实现 ==========

// ========== WiFi/RS485补充接口处理器 (local-device风格) ==========

// 同步聚合扫描: 触发扫描并阻塞等待完成(最长12s), 一次返回当前连接+热点列表。
// 注意: 调用方HTTP客户端超时须设置>=15s; 连接进行中会被WiFi命令队列排队,
// 可能等到超时仍拿不到结果(返回空列表), 前端应避免与连接操作并发调用。
// 字段风格与local-device快照一致: rssi(dBm原始值)/secured
int HttpServerBasedOnLibhv::handleLocalWifiScanSync(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure snap = m_dataManager->getLocalDeviceDataSnapshot();
        if (!snap.wifi.enabled) {
            sendError(ctx, 409, "WiFi已关闭, 无法扫描");
            return HTTP_STATUS_CONFLICT;
        }

        WifiCommand command;
        command.type = WifiCommandType::Scan;
        if (!m_wifiManager || !m_wifiManager->submitCommand(std::move(command))) {
            sendError(ctx, 503, "WiFi系统接口不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const int64_t startMs = snap.wifi.timestamp;
        LocalDeviceDataStructure data = snap;
        for (int waited = 0; waited < 12000; waited += 500) {
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            data = m_dataManager->getLocalDeviceDataSnapshot();
            if (!data.wifi.commandPending
                && (data.wifi.timestamp > startMs || !data.wifi.scanResults.empty())) {
                break;
            }
        }

        json networks = json::array();
        for (const WifiNetworkData& network : data.wifi.scanResults) {
            networks.push_back({
                {"ssid", network.ssid},
                {"rssi", network.rssi},
                {"secured", network.secured}
            });
        }
        json result = {
            {"current", {
                {"ssid", data.wifi.connected ? data.wifi.connectedSsid : ""},
                {"connected", data.wifi.connected}
            }},
            {"networks", networks}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("扫描失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// 连接过程轮询状态
// 注: 模组协议不区分密码错误/热点不存在, 统一归为failed
int HttpServerBasedOnLibhv::handleLocalWifiStatus(const HttpContextPtr& ctx)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    std::string state = data.wifi.state;
    if (state == "disabled") state = "idle";
    json result = {
        {"state", state},
        {"enabled", data.wifi.enabled},
        {"connected", data.wifi.connected},
        {"ssid", data.wifi.connected ? data.wifi.connectedSsid : data.wifi.targetSsid},
        {"ip", data.wifi.ipAddress},
        {"rssi", data.wifi.rssi},
        {"error", data.wifi.lastError}
    };
    ctx->send(buildSuccessResponse(result.dump()));
    return HTTP_STATUS_OK;
}

// RS485开关设置: body {"enabled":true/false}, 全停语义, 持久化
int HttpServerBasedOnLibhv::handleLocalRs485SetEnabled(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        bool enable = false;
        if (request.contains("enabled") && request["enabled"].is_boolean()) {
            enable = request["enabled"].get<bool>();
        } else if (request.contains("enable") && request["enable"].is_boolean()) {
            enable = request["enable"].get<bool>();
        } else {
            sendError(ctx, 400, "缺少布尔字段 enabled");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!m_rs485Setter || !m_rs485Setter(enable)) {
            sendError(ctx, 500, "RS485模块启停失败");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        json result = {{"enabled", enable}, {"accepted", true}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置RS485开关失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// RS485开关状态查询
int HttpServerBasedOnLibhv::handleLocalRs485GetEnabled(const HttpContextPtr& ctx)
{
    json result = {{"enabled", m_rs485Query ? m_rs485Query() : true}};
    ctx->send(buildSuccessResponse(result.dump()));
    return HTTP_STATUS_OK;
}

// ========== OTA升级接口处理器实现 ==========

// 系统信息页/OTA弹窗的唯一数据源。按钮置灰 = !wifi.connected ||
// !updateAvailable；notifyPending 高亮可点击；downloading 带进度条；
// installing 显示“请勿断电”；failed 显示失败弹窗（重试=start，退出=cancel）。
int HttpServerBasedOnLibhv::handleGetOtaStatus(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = {
            {"available", data.ota.available},
            // 置灰判断的便捷字段：网络在线且模组已通知有新版本
            {"canUpdate", data.wifi.connected && data.ota.updateAvailable
                && data.ota.state != "downloading"
                && data.ota.state != "downloadComplete"
                && data.ota.state != "installing"},
            {"updateAvailable", data.ota.updateAvailable},
            {"currentVersion", data.ota.currentVersion},
            {"targetVersion", data.ota.targetVersion},
            {"fwSize", data.ota.fwSize},
            {"fwMd5", data.ota.fwMd5},
            {"state", data.ota.state},
            {"percent", data.ota.percent},
            {"downloadedBytes", data.ota.downloadedBytes},
            {"pending", data.ota.commandPending},
            {"success", data.ota.lastCommandSuccess},
            {"error", data.ota.lastError},
            {"wifiConnected", data.wifi.connected},
            {"timestamp", data.ota.timestamp}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取OTA状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleStartOtaDownload(const HttpContextPtr& ctx)
{
    try {
        // 请求体可选；预留字段便于前端传递语义（当前版本号等），后端忽略
        if (!m_otaManager || !m_otaManager->isRunning()) {
            sendError(ctx, 503, "OTA功能不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        std::string error;
        if (!m_otaManager->startDownload(error)) {
            sendError(ctx, 409, error.empty() ? "当前状态无法开始更新" : error);
            return HTTP_STATUS_CONFLICT;
        }

        json result = {{"accepted", true}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("开始更新失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleCancelOtaDownload(const HttpContextPtr& ctx)
{
    try {
        if (!m_otaManager || !m_otaManager->isRunning()) {
            sendError(ctx, 503, "OTA功能不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        // cleanup=true 用于下载失败弹窗的“退出”：删除已下载的残留文件
        const json request = ctx->json();
        bool cleanupFiles = false;
        if (request.contains("cleanup") && request["cleanup"].is_boolean()) {
            cleanupFiles = request["cleanup"].get<bool>();
        }

        std::string error;
        if (!m_otaManager->cancelDownload(cleanupFiles, error)) {
            sendError(ctx, 409, error.empty() ? "当前状态无法取消" : error);
            return HTTP_STATUS_CONFLICT;
        }

        json result = {{"accepted", true}, {"cleanup", cleanupFiles}};
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("取消更新失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 屏幕控制接口处理器实现 ==========

int HttpServerBasedOnLibhv::handleSetScreenSleep(const HttpContextPtr& ctx)
{
    try {
        int sleep = ctx->json().value("sleep", 1); // 默认休眠
        LocalDeviceCommand command;
        command.type = LocalDeviceCommandType::SetScreenSleep;
        command.boolValue = sleep != 0;
        if (!m_localDeviceModule || !m_localDeviceModule->submitCommand(std::move(command))) {
            sendError(ctx, 503, "本机设备线程不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {
            {"sleep", sleep != 0 ? 1 : 0},
            {"accepted", true}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("屏幕休眠控制失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetScreenBrightness(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = {
            {"min", data.screen.minBrightness},
            {"max", data.screen.maxBrightness},
            {"current", data.screen.currentBrightness},
            {"available", data.screen.brightnessAvailable},
            {"pending", data.screen.commandPending},
            {"success", data.screen.lastCommandSuccess},
            {"error", data.screen.lastError}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取屏幕亮度失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetScreenBrightness(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        if (!request.contains("brightness")
            || !request["brightness"].is_number_integer()) {
            sendError(ctx, 400, "参数 brightness（整数）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const int brightness = request["brightness"].get<int>();
        const LocalDeviceDataStructure data =
            m_dataManager->getLocalDeviceDataSnapshot();
        if (!data.screen.brightnessAvailable) {
            sendError(ctx, 503, "当前平台未提供可写亮度接口");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        if (brightness < data.screen.minBrightness
            || brightness > data.screen.maxBrightness) {
            sendError(ctx, 400, "亮度值超出当前屏幕范围");
            return HTTP_STATUS_BAD_REQUEST;
        }
        LocalDeviceCommand command;
        command.type = LocalDeviceCommandType::SetScreenBrightness;
        command.intValue = brightness;
        if (!m_localDeviceModule || !m_localDeviceModule->submitCommand(std::move(command))) {
            sendError(ctx, 503, "本机设备线程不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {
            {"min", data.screen.minBrightness},
            {"max", data.screen.maxBrightness},
            {"accepted", true}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置屏幕亮度失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 传感器数据接口处理器实现 ==========

int HttpServerBasedOnLibhv::handleGetTemperatureHumidity(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = {
            {"temperature", data.temperatureHumidity.temperature},
            {"humidity", data.temperatureHumidity.humidity},
            {"temperatureAvailable", data.temperatureHumidity.temperatureAvailable},
            {"humidityAvailable", data.temperatureHumidity.humidityAvailable},
            {"timestamp", data.temperatureHumidity.timestamp}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取温湿度数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetSensorSerial(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json result = {
            {"serial", data.temperatureHumidity.serial},
            {"available", data.temperatureHumidity.serialAvailable},
            {"timestamp", data.temperatureHumidity.timestamp}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取传感器序列号失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleReadRegister(const HttpContextPtr& ctx)
{
    // RS485关闭期间快速拒绝, 避免等待Modbus超时
    if (m_rs485Query && !m_rs485Query()) {
        sendError(ctx, 503, "RS485通讯已关闭");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    try {
        // 获取寄存器地址参数
        std::string addrStr = ctx->param("address", "");
        std::string countStr = ctx->param("count", "1");

        if (addrStr.empty()) {
            sendError(ctx, 400, "缺少必需参数: address");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // 解析地址（支持十六进制和十进制格式）
        uint16_t address;
        if (addrStr.length() > 2 && addrStr[0] == '0' && (addrStr[1] == 'x' || addrStr[1] == 'X')) {
            // 十六进制格式 (0x....)
            address = static_cast<uint16_t>(std::stoi(addrStr, nullptr, 16));
        } else {
            // 十进制格式
            address = static_cast<uint16_t>(std::stoi(addrStr));
        }

        // 解析数量
        uint16_t count = static_cast<uint16_t>(std::stoi(countStr));
        if (count == 0 || count > 125) {
            sendError(ctx, 400, "count 参数必须在 1-125 范围内");
            return HTTP_STATUS_BAD_REQUEST;
        }

        LOG_INFO("[HttpServer] Reading Modbus register: address={:#04x} ({}), count={}", address, address, count);

        std::vector<uint16_t> values(count);

        // HTTP 只读周期采集缓存，缓存未准备好或范围未采集时不直读串口。
        if (!m_dataManager->readHoldingFromCache(address, count, values.data())) {
            sendError(ctx, 503, "保持寄存器缓存未准备好或请求范围未采集");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        // 构建JSON响应
        std::ostringstream json;
        json << "{"
             << "\"address\":\"" << std::hex << std::showbase << address << std::dec << "\","
             << "\"addressDec\":" << address << ","
             << "\"count\":" << count << ","
             << "\"values\":[";

        for (size_t i = 0; i < values.size(); ++i) {
            if (i > 0) json << ",";
            json << values[i];
        }

        json << "],"
             << "\"hexValues\":[\"";

        for (size_t i = 0; i < values.size(); ++i) {
            if (i > 0) json << "\",\"";
            json << std::hex << std::showbase << values[i];
        }
        json << std::dec << "\"]"
             << "}";

        ctx->send(buildSuccessResponse(json.str()));
        return HTTP_STATUS_OK;
    } catch (const std::invalid_argument& e) {
        sendError(ctx, 400, "参数格式错误: " + std::string(e.what()));
        return HTTP_STATUS_BAD_REQUEST;
    } catch (const std::out_of_range& e) {
        sendError(ctx, 400, "参数超出范围: " + std::string(e.what()));
        return HTTP_STATUS_BAD_REQUEST;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("读取寄存器失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleWriteRegister(const HttpContextPtr& ctx)
{
    // RS485关闭期间快速拒绝, 避免等待Modbus超时
    if (m_rs485Query && !m_rs485Query()) {
        sendError(ctx, 503, "RS485通讯已关闭");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    try {
        // 解析 JSON 请求体
        auto jsonReq = ctx->json();

        // 获取寄存器地址参数
        if (!jsonReq.contains("address")) {
            sendError(ctx, 400, "缺少必需参数: address");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!jsonReq.contains("value")) {
            sendError(ctx, 400, "缺少必需参数: value");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // 解析地址（支持字符串格式的十六进制和十进制）
        uint16_t address;
        try {
            if (jsonReq["address"].is_string()) {
                std::string addrStr = jsonReq["address"].get<std::string>();
                if (addrStr.length() > 2 && addrStr[0] == '0' && (addrStr[1] == 'x' || addrStr[1] == 'X')) {
                    address = static_cast<uint16_t>(std::stoi(addrStr, nullptr, 16));
                } else {
                    address = static_cast<uint16_t>(std::stoi(addrStr));
                }
            } else {
                address = jsonReq["address"].get<uint16_t>();
            }
        } catch (const std::exception& e) {
            sendError(ctx, 400, "地址参数格式错误");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // 解析值
        uint16_t value;
        try {
            if (jsonReq["value"].is_string()) {
                std::string valStr = jsonReq["value"].get<std::string>();
                if (valStr.length() > 2 && valStr[0] == '0' && (valStr[1] == 'x' || valStr[1] == 'X')) {
                    value = static_cast<uint16_t>(std::stoi(valStr, nullptr, 16));
                } else {
                    value = static_cast<uint16_t>(std::stoi(valStr));
                }
            } else {
                value = jsonReq["value"].get<uint16_t>();
            }
        } catch (const std::exception& e) {
            sendError(ctx, 400, "值参数格式错误");
            return HTTP_STATUS_BAD_REQUEST;
        }

        LOG_INFO("[HttpServer] Writing Modbus register: address={:#04x} ({}), value={:#04x} ({})",
                 address, address, value, value);

        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                address, value, "write-holding-register")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        // 构建JSON响应
        std::ostringstream json;
        json << "{"
             << "\"address\":\"" << std::hex << std::showbase << address << std::dec << "\","
             << "\"addressDec\":" << address << ","
             << "\"value\":" << value << ","
             << "\"hexValue\":\"" << std::hex << std::showbase << value << std::dec << "\","
             << "\"accepted\":true"
             << "}";

        ctx->send(buildSuccessResponse(json.str()));
        return HTTP_STATUS_OK;
    } catch (const json::parse_error& e) {
        sendError(ctx, 400, "JSON 解析错误: " + std::string(e.what()));
        return HTTP_STATUS_BAD_REQUEST;
    } catch (const json::exception& e) {
        sendError(ctx, 400, "JSON 处理失败: " + std::string(e.what()));
        return HTTP_STATUS_BAD_REQUEST;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("写入寄存器失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetHumanPresenceRadar(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        if (!request.contains("enable") || !request["enable"].is_boolean()) {
            sendError(ctx, 400, "参数 enable（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        const bool enable = request["enable"].get<bool>();
        LocalDeviceCommand command;
        command.type = LocalDeviceCommandType::SetRadarEnabled;
        command.boolValue = enable;
        if (!m_localDeviceModule || !m_localDeviceModule->submitCommand(std::move(command))) {
            sendError(ctx, 503, "本机设备线程不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json resp = {
            {"enable", enable},
            {"accepted", true}
        };
        ctx->send(buildSuccessResponse(resp.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制人感雷达失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetHumanPresenceRadar(const HttpContextPtr& ctx)
{
    try {
        LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
        json resp = {
            {"enable", data.radar.enable},
            {"online", data.radar.online},
            {"distance", data.radar.distance},
            {"velocity", data.radar.velocity},
            {"signal", data.radar.signal},
            {"gesture", data.radar.gesture},
            {"approach", data.radar.approach},
            {"depart", data.radar.depart},
            {"direction", data.radar.direction},
            {"timestamp", data.radar.timestamp},
            {"pending", data.radar.commandPending},
            {"success", data.radar.lastCommandSuccess},
            {"error", data.radar.lastError}
        };
        ctx->send(buildSuccessResponse(resp.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取人感雷达状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetAQILed(const HttpContextPtr& ctx)
{
    try {
        const json request = ctx->json();
        int level = 0;
        if (request.contains("pm25") && request["pm25"].is_number_integer()) {
            // PM2.5(ug/m3) 自动分级: <=35 优(绿) 35~75 良(黄绿) 75~150 中度(黄) >150 重度(红)
            level = LocalDeviceModule::pm25ToAqiLevel(request["pm25"].get<int>());
        } else if (request.contains("level") && request["level"].is_number_integer()) {
            level = request["level"].get<int>();
        } else if (request.contains("enabled") && request["enabled"].is_boolean()) {
            // 设置页只控制开关；开启时使用确定的绿色等级1，不在此引入AQI自动分级策略。
            level = request["enabled"].get<bool>() ? 1 : 0;
        } else {
            sendError(ctx, 400, "参数 pm25/level（整数）或 enabled（布尔）必填");
            return HTTP_STATUS_BAD_REQUEST;
        }
        static const char* levelColors[] = {
            "000000", "05DF72", "C2DF05", "F59E0B", "EF4444", "EF4444"
        };
        if (level < 0 || level > 5) {
            sendError(ctx, 400, "AQI等级必须在0-5之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        // 产测扩展：可选 color（6位十六进制 RRGGBB）直接指定9路灯珠颜色，覆盖等级默认色。
        std::string colorOverride;
        if (request.contains("color") && request["color"].is_string()) {
            colorOverride = request["color"].get<std::string>();
            if (colorOverride.size() != 6 ||
                colorOverride.find_first_not_of("0123456789abcdefABCDEF") != std::string::npos) {
                sendError(ctx, 400, "参数 color 必须是6位十六进制 RRGGBB");
                return HTTP_STATUS_BAD_REQUEST;
            }
            for (auto& ch : colorOverride) {
                ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
            }
        }
        LocalDeviceCommand command;
        command.type = LocalDeviceCommandType::SetAqiLedLevel;
        command.intValue = level;
        command.textValue = colorOverride;
        if (!m_localDeviceModule || !m_localDeviceModule->submitCommand(std::move(command))) {
            sendError(ctx, 503, "本机设备线程不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {
            {"enabled", level != 0},
            {"level", level},
            {"color", colorOverride.empty() ? std::string(levelColors[level]) : colorOverride},
            {"accepted", true}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制AQI指示灯失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetSpeaker(const HttpContextPtr& ctx)
{
    try {
        bool enable = ctx->json().value("enable", true);
        LocalDeviceCommand command;
        command.type = LocalDeviceCommandType::SetSpeakerEnabled;
        command.boolValue = enable;
        if (!m_localDeviceModule || !m_localDeviceModule->submitCommand(std::move(command))) {
            sendError(ctx, 503, "本机设备线程不可用");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json result = {
            {"enable", enable},
            {"accepted", true}
        };
        ctx->send(buildSuccessResponse(result.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("控制扬声器失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// 前向声明（定义在文件后部，handleGetLocation 附近）
static std::string gbkToUtf8(const std::string& gbkStr);

// ========== 天气查询：通用 GET 请求（文件内辅助） ==========
// 发起 GET 请求并返回响应体；和风请求传入 apiKey（写入 X-QW-Api-Key 头）。
// 失败（curl 初始化失败、网络错误等）返回空串。
static std::string httpGet(const std::string& url, const std::string& apiKey, long timeoutSec)
{
    CURL* curl = curl_easy_init();
    if (!curl) {
        LOG_ERROR("[HttpServer] httpGet: curl init failed");
        return "";
    }

    std::string response;
    struct curl_slist* headers = nullptr;
    headers = curl_slist_append(headers, "accept: application/json");
    if (!apiKey.empty()) {
        headers = curl_slist_append(headers, ("X-QW-Api-Key: " + apiKey).c_str());
    }

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "gzip"); // 和风默认 gzip，自动解压
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_DEFAULT_PROTOCOL, "https");
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeoutSec);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L); // 嵌入式环境证书校验从宽
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    CURLcode res = curl_easy_perform(curl);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        LOG_ERROR("[HttpServer] httpGet failed [{}]: {}", url, curl_easy_strerror(res));
        return "";
    }
    return response;
}

// 风向 compass（英文缩写，和风返回小写）转中文16方位
static std::string compassToChinese(std::string compass)
{
    // 统一转小写（和风实测返回小写）
    for (auto& c : compass) {
        if (c >= 'A' && c <= 'Z') c = static_cast<char>(c + 32);
    }
    static const std::map<std::string, std::string> kMap = {
        {"n", "北"}, {"nne", "北东北"}, {"ne", "东北"}, {"ene", "东东北"},
        {"e", "东"}, {"ese", "东东南"}, {"se", "东南"}, {"sse", "南东南"},
        {"s", "南"}, {"ssw", "南西南"}, {"sw", "西南"}, {"wsw", "西西南"},
        {"w", "西"}, {"wnw", "西西北"}, {"nw", "西北"}, {"nnw", "北西北"}
    };
    auto it = kMap.find(compass);
    return it != kMap.end() ? it->second : compass;
}

// 取设备出口公网IP（太平洋网 ipJson，返回 GBK 编码，自动转 UTF-8 后解析 ip 字段）
std::string HttpServerBasedOnLibhv::fetchPublicIp()
{
    std::string response = httpGet("https://whois.pconline.com.cn/ipJson.jsp?ip=&json=true", "", 4);
    if (response.empty()) {
        LOG_WARN("[HttpServer] fetchPublicIp: no response from pconline");
        return "";
    }

    std::string utf8 = gbkToUtf8(response);
    try {
        json j = json::parse(utf8);
        std::string ip = j.value("ip", "");
        LOG_DEBUG("[HttpServer] Public IP: {}", ip);
        return ip;
    } catch (const std::exception& e) {
        LOG_ERROR("[HttpServer] fetchPublicIp parse failed: {}", e.what());
        return "";
    }
}

// IP -> 经纬度 + 城市名（和风 GeoAPI city/lookup）
bool HttpServerBasedOnLibhv::queryLocationByIp(const std::string& ip,
                                               std::string& lat, std::string& lon,
                                               std::string& city)
{
    std::string apiKey = m_dataManager ? m_dataManager->getWeatherApiKey() : "";
    std::string apiHost = m_dataManager ? m_dataManager->getWeatherApiHost() : "";
    if (apiKey.empty() || apiHost.empty()) {
        LOG_ERROR("[HttpServer] queryLocationByIp: weather apiKey/apiHost not configured");
        return false;
    }

    std::string url = apiHost + "/geo/v2/city/lookup?location=" + ip;
    std::string response = httpGet(url, apiKey, 6);
    if (response.empty()) return false;

    try {
        json j = json::parse(response);
        // 响应：{"code":"200","location":[{"name":"深圳","lat":"22.54700","lon":"114.08595",...}]}
        if (j.value("code", "") != "200" || !j.contains("location") || j["location"].empty()) {
            LOG_ERROR("[HttpServer] queryLocationByIp bad response: {}", response);
            return false;
        }
        const auto& loc = j["location"][0];
        lat = loc.value("lat", "");
        lon = loc.value("lon", "");
        city = loc.value("name", "");
        LOG_INFO("[HttpServer] IP {} -> {} (lat={}, lon={})", ip, city, lat, lon);
        return !lat.empty() && !lon.empty();
    } catch (const std::exception& e) {
        LOG_ERROR("[HttpServer] queryLocationByIp parse failed: {}", e.what());
        return false;
    }
}

// 经纬度 -> 实时天气原始JSON（和风 weather，路径 /weather/v1/current/{lat}/{lon}，纬度在前）
bool HttpServerBasedOnLibhv::queryWeatherByCoord(const std::string& lat, const std::string& lon,
                                                 std::string& jsonOut)
{
    std::string apiKey = m_dataManager ? m_dataManager->getWeatherApiKey() : "";
    std::string apiHost = m_dataManager ? m_dataManager->getWeatherApiHost() : "";
    if (apiKey.empty() || apiHost.empty()) return false;

    std::string url = apiHost + "/weather/v1/current/" + lat + "/" + lon + "?localTime=false&lang=zh";
    std::string response = httpGet(url, apiKey, 6);
    if (response.empty()) return false;

    try {
        json j = json::parse(response);
        if (!j.contains("condition")) {
            LOG_ERROR("[HttpServer] queryWeatherByCoord bad response: {}", response);
            return false;
        }
    } catch (const std::exception& e) {
        LOG_ERROR("[HttpServer] queryWeatherByCoord parse failed: {}", e.what());
        return false;
    }
    jsonOut = response;
    return true;
}

// 经纬度 -> 当日逐日预报（和风 daily，/weather/v1/daily/{lat}/{lon}，days[0] 为当日）
bool HttpServerBasedOnLibhv::queryDailyForecast(const std::string& lat, const std::string& lon,
                                                std::string& jsonOut)
{
    std::string apiKey = m_dataManager ? m_dataManager->getWeatherApiKey() : "";
    std::string apiHost = m_dataManager ? m_dataManager->getWeatherApiHost() : "";
    if (apiKey.empty() || apiHost.empty()) return false;

    std::string url = apiHost + "/weather/v1/daily/" + lat + "/" + lon + "?days=1&localTime=false&lang=zh";
    std::string response = httpGet(url, apiKey, 6);
    if (response.empty()) return false;

    try {
        json j = json::parse(response);
        if (!j.contains("days") || j["days"].empty()) {
            LOG_ERROR("[HttpServer] queryDailyForecast bad response: {}", response);
            return false;
        }
    } catch (const std::exception& e) {
        LOG_ERROR("[HttpServer] queryDailyForecast parse failed: {}", e.what());
        return false;
    }
    jsonOut = response;
    return true;
}

// 获取实时天气：IP定位(公网IP -> 经纬度) -> 和风实时天气，带 TTL 缓存
int HttpServerBasedOnLibhv::handleGetWeather(const HttpContextPtr& ctx)
{
    try {
        // 检查天气服务配置
        std::string apiKey = m_dataManager ? m_dataManager->getWeatherApiKey() : "";
        std::string apiHost = m_dataManager ? m_dataManager->getWeatherApiHost() : "";
        if (apiKey.empty() || apiHost.empty()) {
            sendError(ctx, 500, "天气服务未配置（缺少 apiKey 或 apiHost）");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // TTL 缓存命中则直接返回（设备位置固定，天气变化慢）
        {
            std::lock_guard<std::mutex> lock(m_weatherCacheMutex);
            if (m_weatherCacheValid && !m_weatherCacheResult.empty()) {
                auto ageSec = std::chrono::duration_cast<std::chrono::seconds>(
                    std::chrono::steady_clock::now() - m_weatherCacheTime).count();
                if (ageSec < WEATHER_CACHE_TTL_SEC) {
                    LOG_DEBUG("[HttpServer] /getWeather cache hit (age={}s)", ageSec);
                    ctx->send(buildSuccessResponse(m_weatherCacheResult));
                    return HTTP_STATUS_OK;
                }
                m_weatherCacheValid = false;
            }
        }

        // 1. 取设备出口公网IP
        std::string ip = fetchPublicIp();
        if (ip.empty()) {
            sendError(ctx, 500, "获取公网IP失败");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 2. IP -> 经纬度 + 城市
        std::string lat, lon, city;
        if (!queryLocationByIp(ip, lat, lon, city)) {
            sendError(ctx, 500, "IP定位失败（获取经纬度失败）");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 3. 经纬度 -> 实时天气
        std::string weatherRaw;
        if (!queryWeatherByCoord(lat, lon, weatherRaw)) {
            sendError(ctx, 500, "获取天气数据失败");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 4. 经纬度 -> 当日预报（最高/最低温）
        std::string dailyRaw;
        if (!queryDailyForecast(lat, lon, dailyRaw)) {
            sendError(ctx, 500, "获取预报数据失败");
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 解析天气字段（和风返回结构见实测）
        json w = json::parse(weatherRaw);
        std::string conditionText = w["condition"].value("text", "");
        // 和风 condition.code 为语言无关的稳定天气代码（如 100=晴、101=多云），
        // 前端据此按语言查本地映射表展示；解析失败默认 0（前端按"查不到"处理）
        int weatherCode = 0;
        if (w.contains("condition") && w["condition"].contains("code")) {
            try { weatherCode = std::stoi(w["condition"]["code"].get<std::string>()); }
            catch (const std::exception&) { weatherCode = 0; }
        }
        double temp = w.value("temperature", json::object()).value("value", 0.0);
        double feels = w.value("feelsLike", json::object()).value("value", 0.0);
        double humidity = w.value("humidity", 0.0); // 0~1
        const json wind = w.value("wind", json::object());
        std::string compass = wind.value("direction", json::object()).value("compass", "");
        int windScale = wind.value("scale", 0);
        double pressure = w.value("pressure", json::object()).value("value", 0.0);
        double visibility = w.value("visibility", json::object()).value("value", 0.0);
        int uvIndex = w.value("uvIndex", 0);
        double cloudCover = w.value("cloudCover", 0.0);

        // 当日最高/最低温（和风 daily 预报的 days[0]，forecastStartTime 为本地当天 00:00）
        json d = json::parse(dailyRaw);
        const auto& day0 = d["days"][0];
        double tempMax = day0.value("temperatureMax", json::object()).value("value", 0.0);
        double tempMin = day0.value("temperatureMin", json::object()).value("value", 0.0);

        // 数值格式化
        int humidityPct = static_cast<int>(humidity * 100.0 + 0.5);
        std::string windDesc = compassToChinese(compass);
        if (windScale > 0) {
            windDesc += std::to_string(windScale) + "级";
        }
        // 温度字段取整（四舍五入）后转为字符串，前端要求温度返回整数
        auto fmtTemp = [](double v) {
            return std::to_string(std::lround(v));
        };

        // updateTime（本地时间，ISO8601 +08:00）
        std::string updateTime;
        {
            std::time_t now = std::time(nullptr);
            std::tm tmNow;
            localtime_r(&now, &tmNow);
            char buf[40];
            std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S+08:00", &tmNow);
            updateTime = buf;
        }

        // 组装响应（temperature/feelsLike/humidity 保持字符串以兼容现有契约，其余为数字）
        json result;
        result["city"] = city;
        result["temperature"] = fmtTemp(temp);
        result["temperatureMax"] = fmtTemp(tempMax);
        result["temperatureMin"] = fmtTemp(tempMin);
        result["feelsLike"] = fmtTemp(feels);
        result["weather"] = conditionText;
        result["weathercode"] = weatherCode;
        result["humidity"] = std::to_string(humidityPct);
        result["wind"] = windDesc;
        result["updateTime"] = updateTime;
        result["pressure"] = pressure;
        result["visibility"] = visibility;
        result["uvIndex"] = uvIndex;
        result["cloudCover"] = cloudCover;
        std::string resultStr = result.dump();

        // 写缓存
        {
            std::lock_guard<std::mutex> lock(m_weatherCacheMutex);
            m_weatherCacheResult = resultStr;
            m_weatherCacheTime = std::chrono::steady_clock::now();
            m_weatherCacheValid = true;
        }

        LOG_INFO("[HttpServer] /getWeather -> city={} {}°{} 湿度{}% {} (当日 {}~{}℃)",
                 city, fmtTemp(temp), conditionText, humidityPct, windDesc, fmtTemp(tempMin), fmtTemp(tempMax));
        ctx->send(buildSuccessResponse(resultStr));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取天气信息失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// GBK转UTF-8辅助函数
static std::string gbkToUtf8(const std::string& gbkStr)
{
    if (gbkStr.empty())
        return "";

    iconv_t cd = iconv_open("UTF-8", "GBK");
    if (cd == (iconv_t)-1) {
        return gbkStr; // 转换失败，返回原字符串
    }

    size_t inLen = gbkStr.length();
    size_t outLen = inLen * 4; // UTF-8最多4字节/字符
    char* outBuf = new char[outLen];
    char* outPtr = outBuf;
    char* inPtr = const_cast<char*>(gbkStr.c_str());

    memset(outBuf, 0, outLen);
    iconv(cd, &inPtr, &inLen, &outPtr, &outLen);
    iconv_close(cd);

    std::string result(outBuf);
    delete[] outBuf;
    return result;
}

int HttpServerBasedOnLibhv::handleGetLocation(const HttpContextPtr& ctx)
{
    try {
        // TTL 缓存命中则直接返回（设备位置固定）
        {
            std::lock_guard<std::mutex> lock(m_locationCacheMutex);
            if (m_locationCacheValid && !m_locationCacheResult.empty()) {
                auto ageSec = std::chrono::duration_cast<std::chrono::seconds>(
                    std::chrono::steady_clock::now() - m_locationCacheTime).count();
                if (ageSec < LOCATION_CACHE_TTL_SEC) {
                    LOG_DEBUG("[HttpServer] /getLocation cache hit (age={}s)", ageSec);
                    ctx->send(buildSuccessResponse(m_locationCacheResult));
                    return HTTP_STATUS_OK;
                }
                m_locationCacheValid = false;
            }
        }

        // IP定位API（太平洋网）
        const std::string API_URL = "https://whois.pconline.com.cn/ipJson.jsp?ip=&json=true";

        // 初始化CURL
        CURL* curl = curl_easy_init();
        if (!curl) {
            LOG_ERROR("[HttpServer] Failed to initialize CURL");
            sendError(ctx, 500, std::string("初始化HTTP客户端失败"));
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 设置CURL选项
        curl_easy_setopt(curl, CURLOPT_URL, API_URL.c_str());
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_DEFAULT_PROTOCOL, "https");
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L); // 10秒超时
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L); // 跳过SSL验证
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);

        // 设置请求头
        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, "accept: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        // 设置响应回调
        std::string responseString;
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseString);

        // 执行请求
        CURLcode res = curl_easy_perform(curl);

        // 清理资源
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);

        if (res != CURLE_OK) {
            LOG_ERROR("[HttpServer] CURL request failed: {}", curl_easy_strerror(res));
            sendError(ctx, 500, std::string("请求IP定位API失败: ") + curl_easy_strerror(res));
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }

        // 解析JSON响应
        try {
            // API返回的是GBK编码，需要转换为UTF-8
            std::string utf8Response = gbkToUtf8(responseString);

            json jsonResponse = json::parse(utf8Response);

            // 提取位置信息
            std::string ip = jsonResponse.value("ip", "");
            std::string pro = jsonResponse.value("pro", ""); // 省
            std::string city = jsonResponse.value("city", ""); // 市
            std::string region = jsonResponse.value("region", ""); // 区
            std::string addr = jsonResponse.value("addr", ""); // 完整地址

            // 如果 addr 为空，则组合生成
            if (addr.empty()) {
                if (!region.empty()) {
                    addr = pro + city + region;
                } else if (!city.empty()) {
                    addr = pro + city;
                } else {
                    addr = pro;
                }
            }

            // 构建响应JSON
            std::ostringstream resultJson;
            resultJson << "{"
                       << "\"ip\":\"" << ip << "\","
                       << "\"province\":\"" << pro << "\","
                       << "\"city\":\"" << city << "\","
                       << "\"district\":\"" << region << "\","
                       << "\"address\":\"" << addr << "\""
                       << "}";

            LOG_DEBUG("[HttpServer] Location retrieved: {}", addr);
            {
                std::lock_guard<std::mutex> lock(m_locationCacheMutex);
                m_locationCacheResult = resultJson.str();
                m_locationCacheTime = std::chrono::steady_clock::now();
                m_locationCacheValid = true;
            }
            ctx->send(buildSuccessResponse(resultJson.str()));
            return HTTP_STATUS_OK;
        } catch (const json::parse_error& e) {
            LOG_ERROR("[HttpServer] Failed to parse location API response: {}", e.what());
            sendError(ctx, 500, std::string("解析位置数据失败: ") + e.what());
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        } catch (const json::exception& e) {
            LOG_ERROR("[HttpServer] JSON exception: {}", e.what());
            sendError(ctx, 500, std::string("JSON处理失败: ") + e.what());
            return HTTP_STATUS_INTERNAL_SERVER_ERROR;
        }
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取区域信息失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

std::string HttpServerBasedOnLibhv::findCityLocation(const std::string& cityName)
{
    // CSV 文件路径（安装在rootfs中）
    const std::string csvFile = "/usr/share/beiang8panel/China-City-List-latest.csv";

    // 尝试打开 CSV 文件
    std::ifstream file(csvFile);
    if (!file.is_open()) {
        LOG_WARN("[HttpServer] Failed to open city list file: {}, using default location", csvFile);
        return "114.0859,22.5470"; // 返回深圳默认位置
    }

    std::string line;
    // 跳过前两行（版本信息和标题行）
    std::getline(file, line); // 版本信息
    std::getline(file, line); // 标题行

    // 查找城市名称
    while (std::getline(file, line)) {
        if (line.empty())
            continue;

        std::istringstream ss(line);
        std::string field;
        std::vector<std::string> fields;

        // 解析CSV行（简单处理，不考虑引号内的逗号）
        while (std::getline(ss, field, ',')) {
            fields.push_back(field);
        }

        // CSV字段格式 (共14个字段):
        // 0:Location_ID, 1:Location_Name_EN, 2:Location_Name_ZH,
        // 3:ISO_3166_1, 4:Country_Region_EN, 5:Country_Region_ZH,
        // 6:Adm1_Name_EN, 7:Adm1_Name_ZH, 8:Adm2_Name_EN, 9:Adm2_Name_ZH,
        // 10:Timezone, 11:Latitude, 12:Longitude, 13:AD_code

        if (fields.size() >= 13) {
            std::string name = fields[2]; // Location_Name_ZH (中文城市名)
            // 移除可能的回车符
            if (!name.empty() && name.back() == '\r') {
                name.pop_back();
            }

            // 精确匹配或包含匹配城市名称
            if (name == cityName || name.find(cityName) != std::string::npos) {
                // 找到匹配，返回经纬度（格式：经度,纬度）
                std::string lat = fields[11]; // Latitude (纬度)
                std::string lon = fields[12]; // Longitude (经度)
                std::string location = lon + "," + lat; // 经度,纬度

                LOG_INFO("[HttpServer] Found city '{}': {} ({}, {})", name, location, lon, lat);
                file.close();
                return location;
            }
        }
    }

    file.close();
    LOG_WARN("[HttpServer] City '{}' not found in CSV, using default location (Shenzhen)", cityName);
    return "114.0859,22.5470"; // 返回深圳默认位置
}

// ========== RTC时间管理API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetRTCTimeApi(const HttpContextPtr& ctx)
{
    try {
        // v1.22：RTC 在 101BH-101FH，10字节结构体打包为5个寄存器。
        uint16_t rtcValues[5] = {0};
        if (!m_dataManager->readHoldingFromCache(
                BeiAng4CPRegisters::RTC_YEAR, 5, rtcValues)) {
            sendError(ctx, 503, "RTC缓存未准备好");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const unsigned int year = rtcValues[0];
        const unsigned int month = (rtcValues[1] >> 8) & 0xFF;
        const unsigned int day = rtcValues[1] & 0xFF;
        const unsigned int minute = rtcValues[2] & 0xFF;
        const unsigned int second = (rtcValues[3] >> 8) & 0xFF;
        const unsigned int week = rtcValues[3] & 0xFF;
        const unsigned int format = (rtcValues[4] >> 8) & 0xFF;

        // 12小时制(format=1)时寄存器 hour 低7位为 1-12、bit7 为 PM 位，
        // 归一为 24 小时制输出，保持消费方语义不变；附 meridiem 便于前端显示。
        const unsigned int hourRaw = (rtcValues[2] >> 8) & 0xFF;
        unsigned int hour;
        const char* meridiem = "";
        if (format == 1) {
            const bool pm = (hourRaw & 0x80) != 0;
            const unsigned int h12 = hourRaw & 0x7F;
            hour = pm ? (h12 == 12 ? 12 : h12 + 12) : (h12 == 12 ? 0 : h12);
            meridiem = pm ? "PM" : "AM";
        } else {
            hour = hourRaw;
        }

        json response = json::object();
        json data = json::object();
        data["year"] = year;
        data["month"] = month;
        data["day"] = day;
        data["hour"] = hour;
        data["minute"] = minute;
        data["second"] = second;
        data["week"] = week;
        data["format"] = format;
        if (format == 1) {
            data["meridiem"] = meridiem;
        }

        char formatted[32];
        snprintf(formatted, sizeof(formatted), "%04u-%02u-%02u %02u:%02u:%02u",
            year, month, day, hour, minute, second);
        data["formatted"] = formatted;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取RTC时间失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetRTCTimeApi(const HttpContextPtr& ctx)
{
    try {
        // 解析请求参数
        auto req = ctx->json();
        json response = json::object();
        json data = json::object();

        int year, month, day, hour, minute, second, week;

        // 优先：前端 POST 时间字符串 "YYYY-M-D H:M:S"（兼容无前导零，如 2026-8-7 15:31:49）
        std::string timeStr = req.value("time", "");
        if (!timeStr.empty()) {
            if (sscanf(timeStr.c_str(), "%d-%d-%d %d:%d:%d",
                       &year, &month, &day, &hour, &minute, &second) != 6) {
                response["code"] = 1;
                response["message"] = "invalid time format, expected 'YYYY-M-D H:M:S' (e.g. 2026-8-7 15:31:49)";
                response["data"] = data;
                ctx->send(buildSuccessResponse(response.dump()));
                return HTTP_STATUS_OK;
            }
        } else if (req.contains("timestamp")) {
            // 备选：时间戳，分解为本地时间各字段
            int64_t timestamp = req.value("timestamp", 0L);
            if (timestamp <= 0) {
                response["code"] = 1;
                response["message"] = "invalid timestamp";
                response["data"] = data;
                ctx->send(buildSuccessResponse(response.dump()));
                return HTTP_STATUS_OK;
            }
            time_t ts = static_cast<time_t>(timestamp);
            struct tm* tm_info = localtime(&ts);
            year = tm_info->tm_year + 1900;
            month = tm_info->tm_mon + 1;
            day = tm_info->tm_mday;
            hour = tm_info->tm_hour;
            minute = tm_info->tm_min;
            second = tm_info->tm_sec;
        } else {
            response["code"] = 1;
            response["message"] = "missing 'time' (YYYY-M-D H:M:S) or 'timestamp'";
            response["data"] = data;
            ctx->send(buildSuccessResponse(response.dump()));
            return HTTP_STATUS_OK;
        }

        // 小时制参数 format：0=24小时制（默认），1=12小时制。
        // 时间值本身仍按 24 小时制传入，12 小时制的 1-12+AM/PM 位打包由后端换算。
        const int format = req.value("format", 0);
        if (format != 0 && format != 1) {
            response["code"] = 1;
            response["message"] = "invalid format, expected 0 (24h) or 1 (12h)";
            response["data"] = data;
            ctx->send(buildSuccessResponse(response.dump()));
            return HTTP_STATUS_OK;
        }

        // 基本参数校验
        if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31 ||
            hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
            response["code"] = 1;
            response["message"] = "invalid time values";
            response["data"] = data;
            ctx->send(buildSuccessResponse(response.dump()));
            return HTTP_STATUS_OK;
        }

        // 由日期推算星期 week（0=Sunday，与协议定义一致），并做严格日历校验：
        // mktime 会把 2-30、9-31、平年 2-29 等非法日期规范化到下月，
        // 规范化后字段与输入不一致即视为非法日期，拒绝写入寄存器。
        struct tm tmbuf = {};
        tmbuf.tm_year = year - 1900;
        tmbuf.tm_mon = month - 1;
        tmbuf.tm_mday = day;
        tmbuf.tm_hour = hour;
        tmbuf.tm_min = minute;
        tmbuf.tm_sec = second;
        tmbuf.tm_isdst = -1;
        const time_t normalized = mktime(&tmbuf);
        if (normalized == -1
            || tmbuf.tm_year != year - 1900 || tmbuf.tm_mon != month - 1
            || tmbuf.tm_mday != day || tmbuf.tm_hour != hour
            || tmbuf.tm_min != minute || tmbuf.tm_sec != second) {
            response["code"] = 1;
            response["message"] = "invalid calendar date (e.g. 2026-2-30), rejected without writing registers";
            response["data"] = data;
            ctx->send(buildSuccessResponse(response.dump()));
            return HTTP_STATUS_OK;
        }
        week = tmbuf.tm_wday;

        // v1.22：RTC 移到 101BH-101FH，10字节结构体打包为5个寄存器（0x10功能码）。
        // 101BH=year，101CH=month<<8|day，101DH=hour<<8|minute，
        // 101EH=second<<8|week，101FH=format<<8|res。
        // 12小时制(format=1)时 hour 低7位为 1-12、bit7 为 PM 位：
        // 24h 的 0 点=12AM、12 点=12PM、13-23 点=(hour-12)PM。
        uint8_t hourByte = static_cast<uint8_t>(hour);
        if (format == 1) {
            const bool pm = hour >= 12;
            const int h12 = (hour % 12 == 0) ? 12 : hour % 12;
            hourByte = static_cast<uint8_t>(h12 | (pm ? 0x80 : 0x00));
        }
        std::vector<uint16_t> rtcValues = {
            static_cast<uint16_t>(year),
            static_cast<uint16_t>((static_cast<uint16_t>(month) << 8) | day),
            static_cast<uint16_t>((static_cast<uint16_t>(hourByte) << 8) | minute),
            static_cast<uint16_t>((static_cast<uint16_t>(second) << 8) | week),
            static_cast<uint16_t>((static_cast<uint16_t>(format) << 8) | 0)
        };
        const bool accepted = m_modbusCommandModule
            && m_modbusCommandModule->submitMultipleWrite(
                BeiAng4CPRegisters::RTC_YEAR,
                rtcValues,
                "set-rtc-time");
        if (!accepted) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        char setTimeBuf[64];
        snprintf(setTimeBuf, sizeof(setTimeBuf), "%04d-%02d-%02d %02d:%02d:%02d",
                 year, month, day, hour, minute, second);
        data["setTime"] = setTimeBuf;
        data["regValues"] = rtcValues;
        data["format"] = format;
        data["accepted"] = true;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置RTC时间失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 设备能力查询API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetDeviceCapabilities(const HttpContextPtr& ctx)
{
    try {
        uint8_t values[8] = {0};
        if (!m_dataManager->readDiscreteFromCache(
                ModbusRegisterCache::DISCRETE_START, 8, values)) {
            sendError(ctx, 503, "设备能力缓存未准备好");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        json response = json::object();
        json data = json::object();
        data["hasHumidificationModule"] = values[0] != 0; // 有无加湿模块
        data["hasDehumidification"] = values[1] != 0;     // 有无除湿模块
        data["hasBypassMode"] = values[2] != 0;           // 有无(旁通/换气)模式
        data["hasIEFPurification"] = values[3] != 0;
        data["hasDisinfectModule"] = values[4] != 0;
        data["hasElectricHeating"] = values[5] != 0;
        data["hasFrostProtection"] = values[6] != 0;
        data["hasFormaldehydeHcho"] = values[7] != 0;     // 有无甲醛HCHO（v1.22新增）
        // 空调/地暖不在协议离散能力表(3000H-3001H)内, 为产品级静态值(v1.4.2补充)
        data["hasAirConditioner"] = BEIANG_PRODUCT_HAS_AIR_CONDITIONER != 0;
        data["hasFloorHeating"] = BEIANG_PRODUCT_HAS_FLOOR_HEATING != 0;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取设备能力失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 空调/地暖有无查询API处理器实现 (v1.4.2新增) ==========

int HttpServerBasedOnLibhv::handleGetAirConditionerPresence(const HttpContextPtr& ctx)
{
    // 4CP 无空调(仅新风/调湿/超净), 产品级静态值, 不依赖寄存器缓存
    const json data = {
        {"hasAirConditioner", BEIANG_PRODUCT_HAS_AIR_CONDITIONER != 0}
    };
    ctx->send(buildSuccessResponse(data.dump()));
    return HTTP_STATUS_OK;
}

int HttpServerBasedOnLibhv::handleGetFloorHeatingPresence(const HttpContextPtr& ctx)
{
    // 4CP 无地暖(仅新风/调湿/超净), 产品级静态值, 不依赖寄存器缓存
    const json data = {
        {"hasFloorHeating", BEIANG_PRODUCT_HAS_FLOOR_HEATING != 0}
    };
    ctx->send(buildSuccessResponse(data.dump()));
    return HTTP_STATUS_OK;
}

// ========== 故障检测API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetDeviceFaults(const HttpContextPtr& ctx)
{
    try {
        const BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        if (!snapshot.registerCache.discreteValid) {
            sendError(ctx, 503, "故障状态缓存尚未就绪");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }
        ctx->send(buildSuccessResponse(
            confirmedFaultsToJson(snapshot.registerCache).dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取故障状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleClearDeviceFaults(const HttpContextPtr& ctx)
{
    sendError(ctx, 501, "v1.22协议未定义故障清除命令");
    return HTTP_STATUS_NOT_IMPLEMENTED;
}

// ========== 关机下空气质量检测API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetOffModeAirQuality(const HttpContextPtr& ctx)
{
    try {
        const BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        if (!snapshot.registerCache.holdingValid) {
            sendError(ctx, 503, "保持寄存器缓存尚未就绪");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const TimingSettingsData& timing = snapshot.gatewayData.getTimingSettings();
        json response = json::object();
        json data = json::object();

        data["enabled"] = timing.offModeAqSwitch != 0;
        data["interval"] = timing.offModeAqInterval;
        data["runtime"] = timing.offModeAqRuntime;
        data["cacheTimestamp"] = snapshot.registerCache.timestamp;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取关机检测设置失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetOffModeAirQuality(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        json response = json::object();
        json data = json::object();

        // 解析参数
        int interval = req.value("interval", 60);
        int runtime = req.value("runtime", 2);

        // 参数验证（协议未定义范围，仅做16位无符号范围校验）
        if (interval < 0 || interval > 65535) {
            sendError(ctx, 400, "检测间隔超出范围（0-65535分钟）");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (runtime < 0 || runtime > 65535) {
            sendError(ctx, 400, "检测运行时间超出范围（0-65535分钟）");
            return HTTP_STATUS_BAD_REQUEST;
        }

        const bool enabled = req.value("enabled", true);
        std::vector<uint16_t> values = {
            static_cast<uint16_t>(enabled ? 1 : 0),
            static_cast<uint16_t>(interval),
            static_cast<uint16_t>(runtime)
        };
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitMultipleWrite(
                BeiAng4CPRegisters::OFF_AIR_QUALITY_DETECT_SWITCH,
                values,
                "set-off-mode-air-quality")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        data["accepted"] = true;
        data["updated"] = json::array({"enabled", "interval", "runtime"});

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置关机检测参数失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 加湿系统精细控制API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetHumidificationStatus(const HttpContextPtr& ctx)
{
    try {
        const BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        if (!snapshot.registerCache.holdingValid || !snapshot.registerCache.inputValid) {
            sendError(ctx, 503, "加湿系统缓存尚未就绪");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        const CirculationPumpData& pump = snapshot.gatewayData.getCirculationPump();
        const DrainageSystemData& drainage = snapshot.gatewayData.getDrainageSystem();
        json response = json::object();
        json data = json::object();

        data["pumpStatus"] = pump.pumpStatus;
        data["drainValve"] = drainage.drainValveStatus;
        data["inletValve"] = drainage.waterInletValve;
        data["inletFloatRaw"] = drainage.inletFloatRaw;
        data["drainFloatRaw"] = drainage.drainFloatRaw;
        data["pumpOnTime"] = pump.pumpOnTime;
        data["pumpOffTime"] = pump.pumpOffTime;
        data["drainOnTime"] = drainage.drainOnTime;
        data["drainCount"] = drainage.drainCount;
        data["cacheTimestamp"] = snapshot.registerCache.timestamp;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取加湿系统状态失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleSetHumidificationControl(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        json response = json::object();
        json data = json::object();

        // 解析参数
        int pumpOnTime = req.value("pumpOnTime", 30);
        int pumpOffTime = req.value("pumpOffTime", 60);
        int drainOnTime = req.value("drainOnTime", 10);

        // 参数验证
        if (pumpOnTime < 10 || pumpOnTime > 120) {
            sendError(ctx, 400, "循环泵开时间必须在10-120秒之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (pumpOffTime < 10 || pumpOffTime > 300) {
            sendError(ctx, 400, "循环泵关时间必须在10-300秒之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (drainOnTime < 5 || drainOnTime > 60) {
            sendError(ctx, 400, "排水开时间必须在5-60秒之间");
            return HTTP_STATUS_BAD_REQUEST;
        }
        std::vector<uint16_t> values = {
            static_cast<uint16_t>(pumpOnTime),
            static_cast<uint16_t>(pumpOffTime),
            static_cast<uint16_t>(drainOnTime)
        };
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitMultipleWrite(
                BeiAng4CPRegisters::HUMIDIFICATION_PUMP_ON_TIME,
                values,
                "set-humidification-timing")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        // v1.22中1024H为设备地址，不接受也不写入排水次数。
        data["accepted"] = true;
        data["updatedParams"] = json::array({"pumpOnTime", "pumpOffTime", "drainOnTime"});

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("设置加湿系统参数失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 清除风机运行时间API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleClearFanRuntime(const HttpContextPtr& ctx)
{
    try {
        auto req = ctx->json();
        json response = json::object();
        json data = json::object();

        std::string fan = req.value("fan", "");

        if (fan.empty()) {
            sendError(ctx, 400, "无效的参数，需要指定 fan");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // v1.22只定义清除全部风机累计运行时间，不伪装支持单台清除。
        if (fan != "all") {
            sendError(ctx, 400, "协议v1.22仅支持 fan=all");
            return HTTP_STATUS_BAD_REQUEST;
        }
        if (!req.value("confirm", false)) {
            sendError(ctx, 400, "清除全部风机累计时间需要 confirm=true");
            return HTTP_STATUS_BAD_REQUEST;
        }

        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitSingleWrite(
                BeiAng4CPRegisters::CLEAR_ALL_FAN_RUNTIME,
                1,
                "clear-all-fan-runtime")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        data["accepted"] = true;
        data["cleared"] = std::vector<std::string>{"fan1", "fan2", "fan3", "fan4"};

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("清除风机运行时间失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== Modbus批量写入API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleWriteMultipleRegisters(const HttpContextPtr& ctx)
{
    // RS485关闭期间快速拒绝, 避免等待Modbus超时
    if (m_rs485Query && !m_rs485Query()) {
        sendError(ctx, 503, "RS485通讯已关闭");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    try {
        auto req = ctx->json();
        json response = json::object();
        json data = json::object();

        // 解析地址和值数组
        std::string addressStr = req.value("address", "");
        std::vector<int> values = req.value("values", std::vector<int>());

        if (addressStr.empty() || values.empty()) {
            sendError(ctx, 400, "无效的参数，需要指定 address 和 values");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // 转换地址（支持十六进制和十进制）
        int address = 0;
        if (addressStr.find("0x") == 0 || addressStr.find("0X") == 0) {
            address = std::stoi(addressStr, nullptr, 16);
        } else {
            address = std::stoi(addressStr);
        }

        // 将 int 值转换为 uint16_t 数组
        std::vector<uint16_t> regValues(values.size());
        for (size_t i = 0; i < values.size(); ++i) {
            regValues[i] = static_cast<uint16_t>(values[i]);
        }

        uint16_t startAddr = static_cast<uint16_t>(address);
        if (!m_modbusCommandModule
            || !m_modbusCommandModule->submitMultipleWrite(
                startAddr, regValues, "write-multiple-holding-registers")) {
            sendError(ctx, 503, "Modbus命令队列不可用或已满");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        data["address"] = address;
        data["count"] = values.size();
        data["accepted"] = true;

        // 获取当前时间
        auto now = std::time(nullptr);
        char timeStr[64];
        std::strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%S", std::localtime(&now));
        data["timestamp"] = timeStr;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("批量写入寄存器失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== Modbus离散输入读取API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleReadDiscreteInputs(const HttpContextPtr& ctx)
{
    // RS485关闭期间快速拒绝, 避免等待Modbus超时
    if (m_rs485Query && !m_rs485Query()) {
        sendError(ctx, 503, "RS485通讯已关闭");
        return HTTP_STATUS_SERVICE_UNAVAILABLE;
    }
    try {
        json response = json::object();
        json data = json::object();

        // 解析参数
        std::string addressStr = ctx->param("address", "0");
        std::string countStr = ctx->param("count", "1");

        int address = std::stoi(addressStr);
        int count = std::stoi(countStr);

        if (count < 1 || count > 77) {
            sendError(ctx, 400, "读取数量必须在1-77之间");
            return HTTP_STATUS_BAD_REQUEST;
        }

        // 地址转换：若传入的是相对偏移（< 0x3000），转为绝对 Modbus 地址
        uint16_t modbusAddr = static_cast<uint16_t>(address);
        if (modbusAddr < 0x3000) {
            modbusAddr = static_cast<uint16_t>(modbusAddr + 0x3000);
        }

        std::vector<uint8_t> values(count);

        // HTTP 只读周期采集缓存，不在缓存未命中时直读串口。
        if (!m_dataManager->readDiscreteFromCache(modbusAddr, count, values.data())) {
            sendError(ctx, 503, "离散输入缓存未准备好或请求范围未采集");
            return HTTP_STATUS_SERVICE_UNAVAILABLE;
        }

        data["address"] = address;
        data["count"] = count;
        std::vector<int> intValues(count);
        for (int i = 0; i < count; ++i) {
            intValues[i] = static_cast<int>(values[i]);
        }
        data["values"] = intValues;

        // 如果读取的是设备能力部分(0-15)，添加解析信息（协议v1.22能力配置表偏移0-7）
        if (address == 0 && count >= 16) {
            json bits = json::object();
            bits["hasHumidificationModule"] = (values[0] != 0); // 有无加湿模块
            bits["hasDehumidification"] = (values[1] != 0);     // 有无除湿模块
            bits["hasBypassMode"] = (values[2] != 0);           // 有无(旁通/换气)模式
            bits["hasIEF"] = (values[3] != 0);
            bits["hasDisinfectModule"] = (values[4] != 0);      // 有无消毒模块
            bits["hasElectricHeating"] = (values[5] != 0);      // 有无电加热控制
            bits["hasFrostProtection"] = (values[6] != 0);      // 有无防冻保护
            bits["hasFormaldehydeHcho"] = (values[7] != 0);     // 有无甲醛HCHO（v1.22新增）
            data["bits"] = bits;
        }

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("读取离散输入失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 传感器数据API处理器实现 ==========

int HttpServerBasedOnLibhv::handleGetSensors(const HttpContextPtr& ctx)
{
    try {
        BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        json data = {
            {"valid", snapshot.registerCache.inputValid},
            {"timestamp", snapshot.registerCache.timestamp}
        };
        if (snapshot.registerCache.inputValid) {
            const GatewayGeneralDataStructure& gateway = snapshot.gatewayData;
            const AirSensorData& ra1 = gateway.getRA1Sensor();
            const AirSensorData& oa = gateway.getOASensor();
            const AirSensorData& sa = gateway.getSASensor();
            const AirQualityData& airQuality = gateway.getAirQuality();
            data["ra1"] = {
                {"temperature", ra1.temperature}, {"humidity", ra1.humidity},
                {"pm25", ra1.pm25}, {"co2", ra1.co2}
            };
            data["oa"] = {
                {"temperature", oa.temperature}, {"humidity", oa.humidity},
                {"pm25", oa.pm25}, {"co2", oa.co2}
            };
            data["sa"] = {
                {"temperature", sa.temperature}, {"humidity", sa.humidity},
                {"pm25", sa.pm25}, {"co2", sa.co2}
            };
            // v1.22：TVOC/甲醛单位mg/m³（寄存器值/100，2019H/201AH）
            data["airQuality"] = {
                {"tvoc", airQuality.tvoc},
                {"formaldehyde", airQuality.formaldehyde}
            };
        }
        json response = {{"code", 0}, {"message", "success"}, {"data", data}};
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取传感器数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

int HttpServerBasedOnLibhv::handleGetAirQuality(const HttpContextPtr& ctx)
{
    try {
        BackendRuntimeSnapshot snapshot = m_dataManager->getBackendRuntimeSnapshot();
        json data = {
            {"valid", snapshot.registerCache.inputValid},
            {"timestamp", snapshot.registerCache.timestamp}
        };
        if (snapshot.registerCache.inputValid) {
            data["pm25"] = snapshot.gatewayData.getRA1Sensor().pm25;
            data["tvoc"] = snapshot.gatewayData.getAirQuality().tvoc;
            data["formaldehyde"] = snapshot.gatewayData.getAirQuality().formaldehyde;
        }
        json response = {{"code", 0}, {"message", "success"}, {"data", data}};
        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取空气质量失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 环境数据API处理器实现 (待机页面室内/室外数据) ==========

int HttpServerBasedOnLibhv::handleGetEnvironmentData(const HttpContextPtr& ctx)
{
    try {
        // 使用IdlePage获取环境数据
        IdlePage idlePage(m_dataManager);
        std::string result = idlePage.getEnvironmentData();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取环境数据失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 室内外空气评价提醒API处理器实现 (待机页面显示) ==========

int HttpServerBasedOnLibhv::handleGetAirQualityReminder(const HttpContextPtr& ctx)
{
    try {
        // 使用IdlePage获取室内外空气评价提醒
        IdlePage idlePage(m_dataManager);
        std::string result = idlePage.getAirQualityReminder();
        ctx->send(buildSuccessResponse(result));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取空气评价提醒失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}

// ========== 协议信息API处理器实现 (v1.20新增) ==========

int HttpServerBasedOnLibhv::handleGetProtocolInfo(const HttpContextPtr& ctx)
{
    try {
        json response = json::object();
        json data = json::object();

        // 返回协议详细信息（协议v1.22）
        data["protocolVersion"] = PROTOCOL_VERSION;
        data["deviceAddress"] = m_dataManager->getDeviceAddress();
        data["deviceModel"] = "4CP";

        // 支持的Modbus功能码
        data["supportedFunctionCodes"] = std::vector<std::string>{"03", "04", "02", "06", "10"};

        // 寄存器地址范围（协议v1.22）
        json registerRanges = json::object();
        registerRanges["holding"] = "1000H-1076H";
        registerRanges["input"] = "2000H-203BH";
        registerRanges["discrete"] = "3000H+0-76";
        data["registerRanges"] = registerRanges;

        response["code"] = 0;
        response["message"] = "success";
        response["data"] = data;

        ctx->send(buildSuccessResponse(response.dump()));
        return HTTP_STATUS_OK;
    } catch (const std::exception& e) {
        sendError(ctx, 500, std::string("获取协议信息失败: ") + e.what());
        return HTTP_STATUS_INTERNAL_SERVER_ERROR;
    }
}
