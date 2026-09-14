/**
 * 基于libhv的HTTP服务器
 *
 * 为Flutter前端提供REST API接口
 */

#ifndef HTTPSERVERBASEDONLIBHV_H
#define HTTPSERVERBASEDONLIBHV_H

// 先包含libhv头文件
#include <hv/HttpServer.h>
#include <hv/HttpService.h>

#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <chrono>
#include <condition_variable>
#include <string>
#include <functional>

// 使用hv命名空间，参考http_server_test.cpp
using namespace hv;

// 前向声明
class DataManager;
class ModbusCommandModule;
class LocalDeviceModule;
class WifiManager;
class OtaManager;
class CommunicationChannel;

enum class HttpServerMode {
    Full,
    ProtocolOnly,
    CommunicationOnly
};

// HTTP服务器类
class HttpServerBasedOnLibhv {
public:
    HttpServerBasedOnLibhv(DataManager* dataManager,
        ModbusCommandModule* modbusCommandModule,
        LocalDeviceModule* localDeviceModule,
        WifiManager* wifiManager,
        OtaManager* otaManager,
        HttpServerMode mode = HttpServerMode::Full,
        CommunicationChannel* communicationChannel = nullptr);
    ~HttpServerBasedOnLibhv();

    // 启动/停止
    bool start();
    void stop();
    bool isRunning() const { return m_isRunning; }

    // 配置
    void setHost(const std::string& host);
    void setPort(int port);

    // RS485开关控制接线(Application提供, HTTP层只透传)
    void setRs485Control(std::function<bool(bool)> setter, std::function<bool()> query);
    std::function<bool(bool)> m_rs485Setter; // RS485开关执行(Application)
    std::function<bool()> m_rs485Query;      // RS485开关状态查询

private:
    // 注册API路由
    void registerRoutes();

    // ========== API处理器 ==========
    int handleGetDeviceStatus(const HttpContextPtr& ctx);
    int handleGetRuntimeSnapshot(const HttpContextPtr& ctx);
    int handleSetIefPurification(const HttpContextPtr& ctx);
    int handleQuickPowerOn(const HttpContextPtr& ctx);
    int handleQuickSetMode(const HttpContextPtr& ctx);
    int handleSetLeaveHomeSwitch(const HttpContextPtr& ctx); // POST 1006H 一键离家开关
    int handleGetLeaveHomeStatus(const HttpContextPtr& ctx); // GET 1006H 一键离家状态（缓存）
    int handleSetWholeUnitRunMode(const HttpContextPtr& ctx); // POST 100AH 整机运行模式
    int handleGetWholeUnitRunModeStatus(const HttpContextPtr& ctx); // GET 100AH 整机运行模式（缓存）
    int handleSetHumidifySwitch(const HttpContextPtr& ctx); // POST 1004H 加湿开关（1003H开启时只读）
    int handleSetDehumidifySwitch(const HttpContextPtr& ctx); // POST 1005H 除湿开关（1003H开启时只读）
    int handleSetExhaustFanSpeed(const HttpContextPtr& ctx); // POST 1009H 排风风量档位（预留）
    int handleSetSteplessFanControl(const HttpContextPtr& ctx); // POST 100BH 无极风量开关
    int handleSetFanDutyCycle(const HttpContextPtr& ctx); // POST 100CH-100EH 风量占空比
    int handleSetTargetTemperature(const HttpContextPtr& ctx); // POST 1010H 目标温度（×10）
    int handleSetPlasmaDisinfect(const HttpContextPtr& ctx); // POST 1011H 等离子消毒开关
    int handleSetAuxHeat(const HttpContextPtr& ctx); // POST 1013H 电辅热选择
    int handleSetHumidityIntensity(const HttpContextPtr& ctx); // POST 1014H 加湿/除湿强度
    int handleSetSaFanRatio(const HttpContextPtr& ctx); // POST 1015H SA风量与增压风机比例
    int handleSetFanDelayOff(const HttpContextPtr& ctx); // POST 1020H 关机后延时关风机
    int handleSetCompressorSettings(const HttpContextPtr& ctx); // POST 1028H-102AH 压缩机设定
    int handleSetFactoryTestMode(const HttpContextPtr& ctx); // POST 1030H 厂测模式（需confirm）
    int handleGetFactoryTestStatus(const HttpContextPtr& ctx); // GET 1030H 厂测模式状态（缓存）
    int handleSetPressureSwitch(const HttpContextPtr& ctx); // POST 102BH/102CH 高/低压开关（厂测）
    int handleSetFactoryFan(const HttpContextPtr& ctx); // POST 1038H-103BH FAN风量设定（厂测）
    int handleSetFactoryValve(const HttpContextPtr& ctx); // POST 103CH-103EH 阀门状态设定（厂测）
    int handleSetFilterRemaining(const HttpContextPtr& ctx); // POST 1031H-1036H 滤网/保养剩余时间
    int handleFactoryReset(const HttpContextPtr& ctx); // POST 1040H 恢复出厂（需confirm）
    int handleSetFactoryFanFlow(const HttpContextPtr& ctx); // POST 1041H-1070H 风量标定（厂测）
    int handleSetFactoryDamper(const HttpContextPtr& ctx); // POST 1071H-1076H 风阀方向/步数（厂测）
    int submitHumiditySwitchRequest(
        const HttpContextPtr& ctx, uint16_t address, const char* name);
    int handleGetManualMode(const HttpContextPtr& ctx);
    int handleSetManualMode(const HttpContextPtr& ctx);
    int handleGetSmartMode(const HttpContextPtr& ctx);
    int handleSetSmartMode(const HttpContextPtr& ctx);
    int handleGetIdleMode(const HttpContextPtr& ctx);
    int handleSetIdleMode(const HttpContextPtr& ctx);
    int handleGetSystemSettings(const HttpContextPtr& ctx);
    int handleSetSystemSettings(const HttpContextPtr& ctx);
    int handleGetDeviceMaintenance(const HttpContextPtr& ctx);
    int handleResetFilter(const HttpContextPtr& ctx);
    int handleGetEngineeringMode(const HttpContextPtr& ctx);
    int handleSetEngineeringMode(const HttpContextPtr& ctx);
    // ========== 历史趋势接口处理器 ==========
    int handleGetHistoryTrend(const HttpContextPtr& ctx);  // GET /api/history/trend
    int handleGetHistoryStatus(const HttpContextPtr& ctx); // GET /api/history/status

    // ========== 内存水位监控接口处理器 ==========
    int handleGetMemWatchStatus(const HttpContextPtr& ctx); // GET /api/memwatch/status

    // ========== 测试接口处理器 ==========
    int handlePing(const HttpContextPtr& ctx);
    int handleHealth(const HttpContextPtr& ctx);
    int handleVersion(const HttpContextPtr& ctx);
    int handlePaths(const HttpContextPtr& ctx);

    // ========== 通用通信接口处理器 ==========
    int handleCommunicationStatus(const HttpContextPtr& ctx);
    int handleCommunicationRead(const HttpContextPtr& ctx);
    int handleCommunicationWrite(const HttpContextPtr& ctx);

    // ========== WiFi接口处理器 ==========
    int handleGetWifiInfo(const HttpContextPtr& ctx);
    int handleGetConnectedWifi(const HttpContextPtr& ctx);
    int handleWifiOpen(const HttpContextPtr& ctx);
    int handleDisconnectWifi(const HttpContextPtr& ctx);
    int handleConnectWifi(const HttpContextPtr& ctx);
    int handleScanWifi(const HttpContextPtr& ctx);

    // ========== WiFi/RS485补充接口 (local-device风格) ==========
    int handleLocalWifiScanSync(const HttpContextPtr& ctx);
    int handleLocalWifiStatus(const HttpContextPtr& ctx);
    int handleLocalRs485SetEnabled(const HttpContextPtr& ctx);
    int handleLocalRs485GetEnabled(const HttpContextPtr& ctx);
    int handleGetLocalDeviceStatus(const HttpContextPtr& ctx);

    // ========== OTA升级接口处理器 ==========
    int handleGetOtaStatus(const HttpContextPtr& ctx);
    int handleStartOtaDownload(const HttpContextPtr& ctx);
    int handleCancelOtaDownload(const HttpContextPtr& ctx);

    // ========== 屏幕控制接口处理器 ==========
    int handleSetScreenSleep(const HttpContextPtr& ctx);
    int handleGetScreenBrightness(const HttpContextPtr& ctx);
    int handleSetScreenBrightness(const HttpContextPtr& ctx);

    // ========== 传感器数据接口处理器 ==========
    int handleGetTemperatureHumidity(const HttpContextPtr& ctx);
    int handleGetSensorSerial(const HttpContextPtr& ctx);  // 获取传感器序列号

    // ========== Modbus寄存器读取接口处理器 ==========
    int handleReadRegister(const HttpContextPtr& ctx);

    // ========== Modbus寄存器写入接口处理器 ==========
    int handleWriteRegister(const HttpContextPtr& ctx);

    // ========== 人感雷达控制接口处理器 ==========
    int handleSetHumanPresenceRadar(const HttpContextPtr& ctx);
    int handleGetHumanPresenceRadar(const HttpContextPtr& ctx);

    // ========== AQI指示灯控制接口处理器 ==========
    int handleSetAQILed(const HttpContextPtr& ctx);

    // ========== 扬声器控制接口处理器 ==========
    int handleSetSpeaker(const HttpContextPtr& ctx);

    // ========== 天气接口处理器 ==========
    int handleGetWeather(const HttpContextPtr& ctx);
    int handleGetLocation(const HttpContextPtr& ctx);

    // ========== RTC时间管理API处理器 (v1.20新增) ==========
    int handleGetRTCTimeApi(const HttpContextPtr& ctx);
    int handleSetRTCTimeApi(const HttpContextPtr& ctx);

    // ========== 设备能力查询API处理器 (v1.20新增) ==========
    int handleGetDeviceCapabilities(const HttpContextPtr& ctx);

    // ========== 空调/地暖有无查询API处理器 (v1.4.2新增) ==========
    int handleGetAirConditionerPresence(const HttpContextPtr& ctx); // GET 空调有无(产品级静态值)
    int handleGetFloorHeatingPresence(const HttpContextPtr& ctx);   // GET 地暖有无(产品级静态值)

    // ========== 故障检测API处理器 (v1.20新增) ==========
    int handleGetDeviceFaults(const HttpContextPtr& ctx);
    int handleClearDeviceFaults(const HttpContextPtr& ctx);

    // ========== 关机下空气质量检测API处理器 (v1.20新增) ==========
    int handleGetOffModeAirQuality(const HttpContextPtr& ctx);
    int handleSetOffModeAirQuality(const HttpContextPtr& ctx);

    // ========== 加湿系统精细控制API处理器 (v1.20新增) ==========
    int handleGetHumidificationStatus(const HttpContextPtr& ctx);
    int handleSetHumidificationControl(const HttpContextPtr& ctx);

    // ========== 设备维护API处理器 (v1.20新增) ==========
    int handleClearFanRuntime(const HttpContextPtr& ctx);

    // ========== Modbus寄存器批量写入API处理器 (v1.20新增) ==========
    int handleWriteMultipleRegisters(const HttpContextPtr& ctx);

    // ========== Modbus离散输入读取API处理器 (v1.20新增) ==========
    int handleReadDiscreteInputs(const HttpContextPtr& ctx);

    // ========== 新风模块API处理器 ==========
    int handleSetFreshAirSwitch(const HttpContextPtr& ctx); // POST 新风开关，写 1001H
    int handleGetFreshAirStatus(const HttpContextPtr& ctx); // GET 新风状态，读 1001H/1006H/1007H/1008H/2003H/2004H

    // ========== 调湿模块API处理器 ==========
    int handleSetHumidityModuleSwitch(const HttpContextPtr& ctx); // POST 调湿开关，写 1003H
    int handleGetHumidityModuleStatus(const HttpContextPtr& ctx); // GET 调湿状态，读 1003H/100FH

    // ========== 超净模式API处理器 ==========
    int handleSetSuperPureSwitch(const HttpContextPtr& ctx); // POST 超净开关，写 1002H
    int handleGetSuperPureStatus(const HttpContextPtr& ctx); // GET 超净状态，读 1002H

    // ========== 新风风速设定API处理器 ==========
    int handleSetFreshAirSpeed(const HttpContextPtr& ctx); // POST 新风风速设定，写 1008H（需 1001H=1 且 1006H=0）

    // ========== 新风运行模式设置API处理器 ==========
    int handleSetFreshAirRunMode(const HttpContextPtr& ctx); // POST 新风运行模式设置，写 1007H（需 1001H=1）
    int handleSetFreshAirMode(const HttpContextPtr& ctx); // POST 语义模式，写 1007H（v1.22：0-5，3=自动）

    // ========== 目标湿度设定API处理器 ==========
    int handleSetTargetHumidity(const HttpContextPtr& ctx); // POST 目标湿度设定，写 100FH（范围 30-70）

    // ========== 传感器数据API处理器 ==========
    int handleGetSensors(const HttpContextPtr& ctx);
    int handleGetAirQuality(const HttpContextPtr& ctx);

    // ========== 环境数据API处理器 ==========
    int handleGetEnvironmentData(const HttpContextPtr& ctx);

    // ========== 室内外空气评价提醒API处理器（待机页面） ==========
    int handleGetAirQualityReminder(const HttpContextPtr& ctx);

    // ========== 协议信息API处理器 (v1.20新增) ==========
    int handleGetProtocolInfo(const HttpContextPtr& ctx);

    // ========== 响应构建 ==========
    std::string buildSuccessResponse(const std::string& data);
    std::string buildErrorResponse(int code, const std::string& message);
    void setJsonResponse(HttpResponse* resp, const std::string& jsonStr);
    // 发送错误响应并设置真实 HTTP 状态码（400/500/503）
    void sendError(const HttpContextPtr& ctx, int code, const std::string& message);

    // ========== 辅助方法 ==========
    std::string extractRequestBody(HttpRequest* req);
    std::string getQueryParam(HttpRequest* req, const std::string& key);

    // ========== 城市查表方法 ==========
    std::string findCityLocation(const std::string& cityName);

    // ========== 天气查询辅助方法 ==========
    // 取设备出口公网IP（pconline）；失败返回空串
    std::string fetchPublicIp();
    // IP -> 经纬度 + 城市名（和风 city/lookup）；成功返回 true
    bool queryLocationByIp(const std::string& ip, std::string& lat, std::string& lon, std::string& city);
    // 经纬度 -> 实时天气原始JSON（和风 weather）；成功返回 true
    bool queryWeatherByCoord(const std::string& lat, const std::string& lon, std::string& jsonOut);
    // 经纬度 -> 当日逐日预报原始JSON（和风 daily，用于最高/最低温）；成功返回 true
    bool queryDailyForecast(const std::string& lat, const std::string& lon, std::string& jsonOut);

    // 数据管理器
    DataManager* m_dataManager;
    ModbusCommandModule* m_modbusCommandModule;
    LocalDeviceModule* m_localDeviceModule;
    WifiManager* m_wifiManager;
    OtaManager* m_otaManager;
    HttpServerMode m_mode;
    CommunicationChannel* m_communicationChannel;

    // libhv服务器和Service
    hv::HttpServer m_server;
    hv::HttpService m_service;

    // 配置
    std::string m_host;
    int m_port;

    // 服务器线程
    std::unique_ptr<std::thread> m_serverThread;
    std::mutex m_mutex;
    std::condition_variable m_cv;

    // 状态
    std::atomic<bool> m_isRunning;
    std::atomic<bool> m_shouldStop;

    // 天气查询结果缓存（设备位置固定，单条 TTL 缓存，降低外部请求频率与阻塞）
    static constexpr int WEATHER_CACHE_TTL_SEC = 300;  // 5 分钟
    bool m_weatherCacheValid = false;
    std::chrono::steady_clock::time_point m_weatherCacheTime;
    std::string m_weatherCacheResult;  // 已组装好的响应 JSON
    std::mutex m_weatherCacheMutex;

    // 定位结果缓存（设备位置固定，单条 TTL 缓存）
    static constexpr int LOCATION_CACHE_TTL_SEC = 300;  // 5 分钟
    bool m_locationCacheValid = false;
    std::chrono::steady_clock::time_point m_locationCacheTime;
    std::string m_locationCacheResult;  // 已组装好的响应 JSON
    std::mutex m_locationCacheMutex;
};

#endif // HTTPSERVERBASEDONLIBHV_H
