/**
 * DataManager - 数据管理器类
 *
 * 负责管理整个系统的数据，包括：
 * 1. 配置数据
 * 2. 设备状态数据
 * 3. 历史数据
 * 4. UI状态数据
 */

#ifndef DATAMANAGER_H
#define DATAMANAGER_H

#include "structure/GatewayGeneralDataStructure.h"
#include "structure/ManualModeDataStructure.h"
#include "structure/SmartModeDataStructure.h"
#include "structure/SystemSettingsDataStructure.h"
#include "structure/EnvironmentDataStructure.h"
#include "structure/LocalDeviceDataStructure.h"
#include "gateways/BeiAng4CPGateway.h"
#include "common/ModbusFreshnessTracker.h"
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

class HistoryRecorder;
class MemoryWatchModule;

// Modbus 寄存器原始值缓存
// DataAcquisition 采集成功后全量更新，HttpServer 读 API 走缓存避免串口竞争
struct ModbusRegisterCache {
    bool holdingValid = false;
    bool inputValid = false;
    bool discreteValid = false;

    // 缓存范围与采集范围一致（协议v1.22）
    static constexpr uint16_t HOLDING_START  = 0x1000;
    static constexpr uint16_t HOLDING_COUNT  = 119;  // 0x1000–0x1076
    static constexpr uint16_t INPUT_START    = 0x2000;
    static constexpr uint16_t INPUT_COUNT    = 60;   // 0x2000–0x203B
    static constexpr uint16_t DISCRETE_START = 0x3000;
    static constexpr uint16_t DISCRETE_COUNT = 77;   // 位0..76
    static constexpr uint16_t DISCRETE_WORD_COUNT = 5;

    uint16_t holdingRegs[HOLDING_COUNT]   = {0};
    uint16_t inputRegs[INPUT_COUNT]       = {0};
    uint8_t  discreteInputs[DISCRETE_COUNT] = {0};
    uint16_t discreteWords[DISCRETE_WORD_COUNT] = {0};

    int64_t timestamp = 0;  // 最后全量更新时间（毫秒）
};

// HTTP 一次复制得到的运行快照。复制完成后即可释放数据锁，JSON 序列化不占锁。
struct BackendRuntimeSnapshot {
    GatewayGeneralDataStructure gatewayData;
    EnvironmentDataStructure environmentData;
    LocalDeviceDataStructure localDeviceData;
    ModbusRegisterCache registerCache;
    bool dataFresh = false;
};

class DataManager {
public:
    struct ConfigFileInfo {
        bool disabled = false;
        std::string transportType;
        std::string endpoint;
        int httpPort = 0;
    };

    DataManager(const std::string& configPath,
        CommunicationSchedulerType communicationSchedulerType);
    ~DataManager();

    // 初始化
    bool initialize();
    void shutdown();

    // 配置管理
    // 只读取并校验配置，不修改运行态成员；供主进程启动前筛选配置槽位。
    static bool inspectConfigFile(
        const std::string& configPath,
        ConfigFileInfo& info,
        std::string& error);
    bool loadConfig(const std::string& configPath);
    bool saveConfig(const std::string& configPath);
    std::string getConfigPath() const { return m_configPath; }

    // 设备数据访问
    GatewayGeneralDataStructure& getGatewayData() { return m_gatewayData; }
    ManualModeDataStructure& getManualModeData() { return m_manualModeData; }
    SmartModeDataStructure& getSmartModeData() { return m_smartModeData; }
    SystemSettingsDataStructure& getSystemSettings() { return m_systemSettings; }
    EnvironmentDataStructure& getEnvironmentData() { return m_environmentData; }

    // 本机设备线程写入、HTTP线程读取的完整快照
    LocalDeviceDataStructure getLocalDeviceDataSnapshot() const;
    void updateLocalDeviceData(const LocalDeviceDataStructure& data);
    // 非 TTY 能力内部仍分开发布：WiFi 线程与本机硬件线程
    // 不做“先读整体、再覆盖整体”，避免并发更新丢失。
    void updateWifiData(const WifiRuntimeData& data);
    void updateLocalHardwareData(const LocalDeviceDataStructure& data);
    // OTA 状态由 OtaManager(库回调线程)单独发布，同样避免整包覆盖
    void updateOtaData(const OtaRuntimeData& data);

    // HTTP GET 的统一数据入口，只复制内存状态，不访问任何设备或外部服务。
    BackendRuntimeSnapshot getBackendRuntimeSnapshot() const;

    // 数据处理线程一次发布同一轮 Modbus 的语义数据和原始镜像。
    // HTTP 侧因此不会读到“新语义 + 旧原始值”或相反的混合快照。
    void publishModbusSnapshot(
        const GatewayGeneralDataStructure& gatewayData,
        const BeiAng4CPGateway::RawRegisterCache& rawCache,
        int64_t timestamp);

    // 写后确认读一次发布完整连续寄存器组：原始镜像和由其派生的业务字段
    // 在同一把锁内一起更新，HTTP 不会看到半组新值、半组旧值。
    bool publishHoldingReadback(
        uint16_t startAddress,
        const uint16_t* values,
        uint16_t count);

    // 任一有效 Modbus RTU 读写成功都重新开始 30 秒新鲜度计时。
    // 只更新进程内单调时钟，不修改最后一次有效业务数据。
    void markModbusCommunicationSuccess();

    // 最近一次成功 Modbus 通信是否仍在 30s 新鲜窗口内
    //（历史采样等旁路消费者用,不触发任何设备访问）
    bool isModbusDataFresh() const;

    // 线程安全的数据访问
    void lockData();
    void unlockData();

    // RAII 数据锁：构造加锁、析构解锁，供读侧 GET 在 try/多return 下安全持有
    class DataLock {
    public:
        explicit DataLock(DataManager& dm) : m_dm(dm) { m_dm.lockData(); }
        ~DataLock() { m_dm.unlockData(); }
        DataLock(const DataLock&) = delete;
        DataLock& operator=(const DataLock&) = delete;
    private:
        DataManager& m_dm;
    };

    // Modbus Gateway 管理（共享单例，避免串口冲突）
    BeiAng4CPGateway* getGateway();
    void lockGateway();
    void unlockGateway();

    // ========== Modbus 寄存器缓存 ==========
    // 采集线程在 performAcquisition() 成功后调用全量更新
    void updateHoldingCache(const uint16_t* regs);
    void updateInputCache(const uint16_t* regs);
    void updateDiscreteCache(const uint8_t* bits);
    // HTTP 读 API 只走缓存；返回 true 表示缓存命中并已拷贝数据
    bool readHoldingFromCache(uint16_t address, uint16_t count, uint16_t* out) const;
    bool readInputFromCache(uint16_t address, uint16_t count, uint16_t* out) const;
    bool readDiscreteFromCache(uint16_t address, uint16_t count, uint8_t* out) const;

    // 缓存有效性查询
    bool isHoldingCacheValid() const;
    const ModbusRegisterCache& getRegisterCache() const { return m_registerCache; }
    ModbusRegisterCache& getRegisterCache() { return m_registerCache; }

    // HTTP配置
    int getHttpPort() const { return m_httpPort; }
    std::string getHttpHost() const { return m_httpHost; }

    // 串口配置
    std::string getSerialPort() const { return m_serialPort; }
    std::string getTransportType() const { return m_transportType; }
    int getSerialBaudRate() const { return m_serialBaudRate; }
    int getSerialDataBits() const { return m_serialDataBits; }
    int getSerialStopBits() const { return m_serialStopBits; }
    char getSerialParity() const { return m_serialParity; }
    int getSerialTimeout() const { return m_serialTimeout; }

    // 设备地址
    int getDeviceAddress() const { return m_deviceAddress; }

    // 数据采集配置
    int getDataAcquisitionInterval() const { return m_dataAcquisitionInterval; }

    // 天气服务配置
    std::string getWeatherApiKey() const { return m_weatherApiKey; }
    std::string getWeatherApiHost() const { return m_weatherApiHost; }

    // 人感雷达（TRMK222 UART）配置
    std::string getRadarStatusFile() const { return m_radarStatusFile; }
    std::string getRadarCommandFile() const { return m_radarCommandFile; }

    // OTA（经 emc6069 模组的整机固件升级）配置
    bool isOtaEnabled() const { return m_otaEnabled; }
    std::string getOtaSerialPort() const { return m_otaSerialPort; }
    int getOtaSerialBaudRate() const { return m_otaSerialBaudRate; }
    std::string getOtaWorkDir() const { return m_otaWorkDir; }

    // 历史趋势采样（只读寄存器缓存，落盘 UDISK 日文件；线程由 Application 启停）
    HistoryRecorder* getHistoryRecorder() { return m_historyRecorder.get(); }

    // 内存水位监控（MemAvailable 分级处置；线程由 Application 启停）
    MemoryWatchModule* getMemoryWatchModule() { return m_memoryWatch.get(); }

private:
    // 配置文件路径
    std::string m_configPath;
    CommunicationSchedulerType m_communicationSchedulerType;

    // 数据结构
    GatewayGeneralDataStructure m_gatewayData;
    ManualModeDataStructure m_manualModeData;
    SmartModeDataStructure m_smartModeData;
    SystemSettingsDataStructure m_systemSettings;
    EnvironmentDataStructure m_environmentData;
    LocalDeviceDataStructure m_localDeviceData;

    // 互斥锁
    mutable std::mutex m_dataMutex;
    std::mutex m_gatewayMutex; // 保护 Gateway 访问

    // Modbus Gateway（共享单例）
    std::unique_ptr<BeiAng4CPGateway> m_gateway;
    bool m_gatewayInitialized = false;

    // Modbus 寄存器原始值缓存
    ModbusRegisterCache m_registerCache;
    ModbusFreshnessTracker m_modbusFreshness;

    // 配置参数
    int m_httpPort;
    std::string m_httpHost;
    std::string m_serialPort;
    std::string m_transportType;
    int m_serialBaudRate;
    int m_serialDataBits;
    int m_serialStopBits;
    char m_serialParity;
    int m_serialTimeout;
    int m_deviceAddress;
    int m_dataAcquisitionInterval;

    // 天气服务配置
    std::string m_weatherApiKey;
    std::string m_weatherApiHost;

    // 人感雷达（TRMK222 UART）配置
    std::string m_radarStatusFile;  // daemon 写入的状态文件路径
    std::string m_radarCommandFile; // 命令文件路径（写 on/off，daemon 执行）

    // OTA 配置
    bool m_otaEnabled = true;
    std::string m_otaSerialPort;
    int m_otaSerialBaudRate = 115200;
    std::string m_otaWorkDir;

    // 历史趋势采样配置(loadConfig 解析,initialize 构建 Recorder 用)
    bool m_historyEnabled = true;
    std::string m_historyDataDir = "/mnt/UDISK/beiang8panel/history";
    int m_historySampleIntervalSec = 600;
    int m_historyRetentionDays = 370;

    // 内存水位监控配置(loadConfig 解析,initialize 构建模块用)
    bool m_memWatchEnabled = true;
    int m_memWatchCheckIntervalSec = 10;
    int m_memWatchWarnThresholdMB = 64;
    int m_memWatchRestartAppThresholdMB = 32;
    int m_memWatchRebootThresholdMB = 16;
    int m_memWatchSustainedChecks = 3;
    int m_memWatchActionCooldownSec = 300;

    // 历史趋势采样器。声明在成员末尾：先于其它成员析构(线程依赖 DataManager)。
    std::unique_ptr<HistoryRecorder> m_historyRecorder;

    // 内存水位监控模块。同样依赖 DataManager,晚于 Recorder 声明(先析构)。
    std::unique_ptr<MemoryWatchModule> m_memoryWatch;
};

#endif // DATAMANAGER_H
