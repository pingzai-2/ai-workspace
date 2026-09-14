/**
 * 网关通用数据结构类
 *
 * 定义与4CP设备通信的通用数据结构（根据协议文档v1.22）
 */

#ifndef GATEWAYGENERARDATASTRUCTURE_H
#define GATEWAYGENERARDATASTRUCTURE_H

#include "common/FaultCode.h"
#include "common/GlobalDefine.h"
#include <array>
#include <string>
#include <vector>

// ========== 设备基本信息 ==========
struct DeviceInfo {
    std::string factoryFlag; // 工厂标志（输入寄存器2000H，"BA"）
    std::string deviceModel; // 兼容显示名称
    std::string version; // 版本显示文本（2002H原始值÷100，如0101=1.01）
    uint16_t deviceModelRaw; // 输入寄存器2001H：0=4CP，1=全热新风
    uint16_t versionRaw; // 输入寄存器2002H原始值（÷100得到版本号）
    std::string controllerVersionTime; // 输入寄存器2030H-203BH：主控板版本时间字符串Char[24]
    uint16_t capabilityConfig; // 能力配置表（保留字段，v1.22经离散输入读取）
    uint16_t capabilityReserved; // 能力配置表预留（保留字段）
    int deviceAddress; // 设备地址（保持寄存器1024H，4CP默认209/0xD1，全热新风193/0xC1，范围0-254）
    uint16_t factoryTestMode; // 厂测模式原值（保持寄存器1030H）
    bool factoryTestActive; // 1030H==100 时为厂测模式（v1.22定义）

    DeviceInfo()
        : deviceModelRaw(0)
        , versionRaw(0)
        , capabilityConfig(0)
        , capabilityReserved(0)
        , deviceAddress(209)
        , factoryTestMode(0)
        , factoryTestActive(false)
    {
    }
};

// ========== 控制状态数据 ==========
struct ControlStatus {
    bool switchOn; // 总开关（保持寄存器1000H）
    bool freshAirModuleOn; // 新风模块开关（保持寄存器1001H）
    bool superPureOn; // 超净模式开关（保持寄存器1002H）
    bool humidityModuleOn; // 调湿模块开关（保持寄存器1003H）
    bool humidificationOn; // 加湿开关（保持寄存器1004H）
    bool dehumidificationOn; // 除湿开关（保持寄存器1005H）
    bool leaveHomeOn; // 一键离家开关（保持寄存器1006H，v1.22由手动/自动改为一键离家）
    AirCirculationMode runMode; // 新风运行模式（保持寄存器1007H，v1.22扩展为0-5）
    int fanGear; // 风量档位（保持寄存器1008H，0-6）
    int wholeUnitRunMode; // 整机运行模式（保持寄存器100AH，v1.22新增：0无/手动 1标准 2会客 3干爽 4温润 5旅行）
    bool steplessFanSwitch; // 无极风量控制开关（保持寄存器100BH）
    int freshFanDutyCycle; // 新风风量占空比（保持寄存器100CH，0-100%，寄存器值即百分比）
    bool plasmaDisinfectOn; // 等离子消毒开关（保持寄存器1011H）
    bool iefPurification; // IEF开关（保持寄存器1012H）
    AuxHeatMode auxHeat; // 电辅热状态（输入寄存器201CH）
    int autoCirculationDisplay; // 1007H自动模式时内外循环显示（输入寄存器201DH，0:内循环 1:内循环/混风 2:全热新风/节能新风）
    int fanMaxGear; // 新风模式风量最大档位（输入寄存器2003H）
    int fanMaxGearRecirc; // 内循环/混风模式风量最大档位（输入寄存器2004H）
    uint16_t faultCode1; // 保留字段（故障码经离散输入64-76发布，恒为0）
    uint16_t faultCode2; // 保留字段（故障码经离散输入64-76发布，恒为0）

    ControlStatus()
        : switchOn(false)
        , freshAirModuleOn(false)
        , superPureOn(false)
        , humidityModuleOn(false)
        , humidificationOn(false)
        , dehumidificationOn(false)
        , leaveHomeOn(false)
        , runMode(AirCirculationMode::Internal)
        , fanGear(0)
        , wholeUnitRunMode(0)
        , steplessFanSwitch(false)
        , freshFanDutyCycle(0)
        , plasmaDisinfectOn(false)
        , iefPurification(false)
        , auxHeat(AuxHeatMode::Off)
        , autoCirculationDisplay(0)
        , fanMaxGear(6)
        , fanMaxGearRecirc(6)
        , faultCode1(0)
        , faultCode2(0)
    {
    }
};

// ========== 压缩机状态数据 ==========
struct CompressorStatus {
    uint16_t compressorStatus; // 压缩机状态（离散输入偏移35）
    bool defrosting; // 除霜中（离散输入偏移36，0未除霜 1正在除霜）
    uint16_t operationFrequency; // 运行频率（输入寄存器201BH，0-90Hz）
    uint16_t expansionValve; // 电子膨胀阀开度设定（保持寄存器1028H）
    float dischargeTemperature; // 压缩机排气温度（输入寄存器202BH，实际温度×10）
    float suctionTemperature; // 压缩机吸气温度（输入寄存器202CH，实际温度×10）
    float evaporatorTemperature; // 蒸发器盘管温度（输入寄存器202DH，实际温度×10）
    uint16_t reservedTemperatureRaw; // 预留温度原值（输入寄存器202EH）
    float highPressure; // 高压压力值bar（输入寄存器2022H，实际值/100）
    float lowPressure; // 低压压力值bar（输入寄存器2023H，实际值/100）
    uint16_t acVoltageRaw; // 交流电压检测值原值（输入寄存器202FH，待定）

    CompressorStatus()
        : compressorStatus(0)
        , defrosting(false)
        , operationFrequency(0)
        , expansionValve(0)
        , dischargeTemperature(0.0f)
        , suctionTemperature(0.0f)
        , evaporatorTemperature(0.0f)
        , reservedTemperatureRaw(0)
        , highPressure(0.0f)
        , lowPressure(0.0f)
        , acVoltageRaw(0)
    {
    }
};

// ========== 环境设定数据 ==========
struct EnvironmentSettings {
    int targetHumidity; // 目标湿度设定（保持寄存器100FH，30-70）
    int targetTemperature; // 目标温度设定（保持寄存器1010H，160-310，实际设定温度×10）
    HumidityIntensity humidityIntensity; // 加湿/除湿强度（保持寄存器1014H）
    float saFanRatio; // SA风量与增压风机比例（保持寄存器1015H，实际值×10）

    EnvironmentSettings()
        : targetHumidity(50)
        , targetTemperature(250)
        , humidityIntensity(HumidityIntensity::Medium)
        , saFanRatio(1.8f)
    {
    }
};

// ========== 风机档位数据 ==========
struct FanGears {
    int fan1Gear; // FAN1档位（输入寄存器2005H）
    int fan2Gear; // FAN2档位（输入寄存器2006H）
    int fan3Gear; // FAN3档位（输入寄存器2007H）
    int fan4Gear; // FAN4档位（输入寄存器2008H）

    FanGears()
        : fan1Gear(0)
        , fan2Gear(0)
        , fan3Gear(0)
        , fan4Gear(0)
    {
    }
};

// ========== 阀门状态数据 ==========
struct ValveStatusData {
    ValveStatus valve1; // 阀门1状态设定（保持寄存器103CH，厂测）
    ValveStatus valve2; // 阀门2状态设定（保持寄存器103DH，厂测）
    ValveStatus valve3; // 阀门3状态设定（保持寄存器103EH，厂测）

    ValveStatusData()
        : valve1(ValveStatus::Closed)
        , valve2(ValveStatus::Closed)
        , valve3(ValveStatus::Closed)
    {
    }
};

// ========== 风机转速数据 ==========
struct FanRPM {
    uint16_t fan1RPM; // FAN1实时RPM（输入寄存器2009H）
    uint16_t fan2RPM; // FAN2实时RPM（输入寄存器200AH）
    uint16_t fan3RPM; // FAN3实时RPM（输入寄存器200BH）
    uint16_t fan4RPM; // FAN4实时RPM（输入寄存器200CH）

    FanRPM()
        : fan1RPM(0)
        , fan2RPM(0)
        , fan3RPM(0)
        , fan4RPM(0)
    {
    }
};

// ========== 传感器数据（RA1/OA/SA）==========
struct AirSensorData {
    float temperature; // 温度（实际值*10+2730，需转换）
    float humidity; // 湿度（0-100%）
    float pm25; // PM2.5
    float co2; // CO2

    AirSensorData()
        : temperature(0.0f)
        , humidity(0.0f)
        , pm25(0.0f)
        , co2(0.0f)
    {
    }
};

// ========== 空气质量数据 ==========
struct AirQualityData {
    float tvoc; // TVOC（寄存器1033H）
    float formaldehyde; // 甲醛（寄存器1034H）

    AirQualityData()
        : tvoc(0.0f)
        , formaldehyde(0.0f)
    {
    }
};

// ========== 运行时间统计数据 ==========
struct RuntimeStatistics {
    int fanDelayOffTime; // 关机后延时关风机时间（分钟）
    uint16_t filterRuntime; // 滤网累计运转时间（小时，保留字段）
    uint16_t iefRuntime; // IEF累计运转时间（小时，保留字段）
    uint16_t systemRuntimeDays; // 系统运行（开机）时间（输入寄存器2026H，单位：天）
    uint16_t fan1Runtime; // FAN1累计运转时间（输入寄存器2027H，小时）
    uint16_t fan2Runtime; // FAN2累计运转时间（输入寄存器2028H，小时）
    uint16_t fan3Runtime; // FAN3累计运转时间（输入寄存器2029H，小时）
    uint16_t fan4Runtime; // FAN4累计运转时间（输入寄存器202AH，小时）
    uint16_t powerOnRuntime; // 上电运行时间（保留字段，v1.21起已移除）

    RuntimeStatistics()
        : fanDelayOffTime(0)
        , filterRuntime(0)
        , iefRuntime(0)
        , systemRuntimeDays(0)
        , fan1Runtime(0)
        , fan2Runtime(0)
        , fan3Runtime(0)
        , fan4Runtime(0)
        , powerOnRuntime(0)
    {
    }
};

// ========== 循环泵数据 ==========
struct CirculationPumpData {
    bool pumpStatus; // 循环泵状态（寄存器1040H）
    int pumpOnTime; // 循环泵开时间（秒）
    int pumpOffTime; // 循环泵关时间（秒）

    CirculationPumpData()
        : pumpStatus(false)
        , pumpOnTime(0)
        , pumpOffTime(0)
    {
    }
};

// ========== 排水系统数据 ==========
struct DrainageSystemData {
    bool drainValveStatus; // 排水泵状态（离散输入偏移34）
    int drainOnTime; // 排水开时间（秒）
    int drainCount; // 排水次数（保留字段，协议未定义）
    bool waterInletValve; // 进水阀状态（离散输入偏移33）
    bool offAirQualityDetecting; // 关机状态下空气质量检测中（离散输入偏移37，v1.22新增）
    uint16_t inletFloatRaw; // 2024H 原值；Bit0/1/2 的分别含义待确认
    uint16_t drainFloatRaw; // 2025H 原值；Bit0/1/2 的分别含义待确认

    DrainageSystemData()
        : drainValveStatus(false)
        , drainOnTime(0)
        , drainCount(0)
        , waterInletValve(false)
        , offAirQualityDetecting(false)
        , inletFloatRaw(0)
        , drainFloatRaw(0)
    {
    }
};

// ========== 风机风量数据（保持寄存器1041H-1070H，v1.22移到保持寄存器且分内外循环） ==========
struct FanFlowData {
    std::array<uint16_t, 6> fan1ExternalFlow; // FAN1外循环1-6档（1041H-1046H）
    std::array<uint16_t, 6> fan1InternalFlow; // FAN1内循环1-6档（1047H-104CH）
    std::array<uint16_t, 6> fan2ExternalFlow; // FAN2外循环（104DH-1052H）
    std::array<uint16_t, 6> fan2InternalFlow; // FAN2内循环（1053H-1058H）
    std::array<uint16_t, 6> fan3ExternalFlow; // FAN3外循环（1059H-105EH）
    std::array<uint16_t, 6> fan3InternalFlow; // FAN3内循环（105FH-1064H）
    std::array<uint16_t, 6> fan4ExternalFlow; // FAN4外循环（1065H-106AH）
    std::array<uint16_t, 6> fan4InternalFlow; // FAN4内循环（106BH-1070H）

    FanFlowData()
        : fan1ExternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan1InternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan2ExternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan2InternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan3ExternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan3InternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan4ExternalFlow { 0, 0, 0, 0, 0, 0 }
        , fan4InternalFlow { 0, 0, 0, 0, 0, 0 }
    {
    }
};

// ========== 风阀控制数据（保持寄存器1071H-1076H，v1.22新增可设定） ==========
struct DamperControlData {
    bool damper1Direction; // 风阀1方向（寄存器1071H）
    bool damper2Direction; // 风阀2方向（寄存器1072H）
    bool damper3Direction; // 风阀3方向（寄存器1073H）
    uint16_t damper1Steps; // 风阀1运行步数（寄存器1074H）
    uint16_t damper2Steps; // 风阀2运行步数（寄存器1075H）
    uint16_t damper3Steps; // 风阀3运行步数（寄存器1076H）

    DamperControlData()
        : damper1Direction(false)
        , damper2Direction(false)
        , damper3Direction(false)
        , damper1Steps(0)
        , damper2Steps(0)
        , damper3Steps(0)
    {
    }
};

// ========== 厂测设定数据（保持寄存器102BH/102CH/1038H-103EH，仅厂测模式可写） ==========
struct FactoryTestSettings {
    bool highPressureSwitchOn; // 高压开关（102BH）
    bool lowPressureSwitchOn; // 低压开关（102CH）
    uint16_t fan1CurrentSetting; // 当前FAN1风量设定值（1038H）
    uint16_t fan2CurrentSetting; // 当前FAN2风量设定值（1039H）
    uint16_t fan3CurrentSetting; // 当前FAN3风量设定值（103AH）
    uint16_t fan4CurrentSetting; // 当前FAN4风量设定值（103BH）
    ValveStatus valve1Setting; // 阀门1状态设定（103CH）
    ValveStatus valve2Setting; // 阀门2状态设定（103DH）
    ValveStatus valve3Setting; // 阀门3状态设定（103EH）

    FactoryTestSettings()
        : highPressureSwitchOn(false)
        , lowPressureSwitchOn(false)
        , fan1CurrentSetting(0)
        , fan2CurrentSetting(0)
        , fan3CurrentSetting(0)
        , fan4CurrentSetting(0)
        , valve1Setting(ValveStatus::Closed)
        , valve2Setting(ValveStatus::Closed)
        , valve3Setting(ValveStatus::Closed)
    {
    }
};

// ========== RTC 时间数据（保持寄存器 101BH-101FH，v1.22共10字节结构体） ==========
struct RtcTimeData {
    uint16_t year;      // 年（2026…）
    uint8_t  month;     // 月 1-12
    uint8_t  day;       // 日 1-31
    uint8_t  hour;      // 时 0-23（12小时制时低7位1-12，bit7=PM）
    uint8_t  minute;    // 分 0-59
    uint8_t  second;    // 秒 0-59
    uint8_t  week;      // 周 0-6（0=Sunday）
    uint8_t  format;    // 0=24小时制
    RtcTimeData()
        : year(0), month(0), day(0), hour(0), minute(0), second(0), week(0), format(0) {}
};

// ========== 设备控制参数补充（保持寄存器 1009H 与 100CH-100EH、1028H-102AH） ==========
struct DeviceControlParams {
    uint16_t exhaustFanGear;         // 1009H 排风风量档位(预留)
    uint16_t freshAirDutyCycle;      // 100CH 新风风量占空比 0-100%
    uint16_t exhaustAirDutyCycle;    // 100DH 排风风量占空比 0-100%
    uint16_t boostFanDutyCycle;      // 100EH 增压风风量占空比 0-100%
    uint16_t auxHeatSetting;         // 1013H 电辅热选择设定(0x00关/0x01辅热1/0x02辅热2/0x03辅热1+2)
    uint16_t compressorEEVOpening;   // 1028H 压缩机电子膨胀阀开度(0-500)
    uint16_t compressorFrequencySet; // 1029H 压缩机运行频率设定值(0-90Hz)
    uint16_t compressorFrequencyMax; // 102AH 压缩机频率上限设定值(60-95Hz)
    DeviceControlParams()
        : exhaustFanGear(0), freshAirDutyCycle(0),
          exhaustAirDutyCycle(0), boostFanDutyCycle(0), auxHeatSetting(0),
          compressorEEVOpening(0), compressorFrequencySet(0),
          compressorFrequencyMax(0) {}
};

// ========== 定时/延时参数（保持寄存器 1020H-1027H） ==========
struct TimingSettingsData {
    uint16_t fanDelayOffTime;     // 1020H 关机后延时关风机时间(分钟)
    uint16_t circPumpOnTime;      // 1021H 加湿循环泵开时间(秒)
    uint16_t circPumpOffTime;     // 1022H 加湿循环泵关时间(秒)
    uint16_t drainOnTime;         // 1023H 加湿排水开时间(秒)
    uint16_t offModeAqSwitch;     // 1025H 关机状态下空气品质检测开关
    uint16_t offModeAqInterval;   // 1026H 关机状态下空气品质检测间隔(分钟)
    uint16_t offModeAqRuntime;    // 1027H 关机状态下空气品质检测运行时间(分钟)
    // 注：1024H为设备地址（见DeviceInfo.deviceAddress），原"加湿排水次数"已移除
    TimingSettingsData()
        : fanDelayOffTime(0), circPumpOnTime(0), circPumpOffTime(0), drainOnTime(0),
          offModeAqSwitch(0), offModeAqInterval(0), offModeAqRuntime(0) {}
};

// ========== 滤网/保养剩余时间（保持寄存器 1031H-1036H） ==========
struct FilterMaintenanceData {
    uint16_t filter1Remaining;        // 1031H 初效滤网1剩余时间(小时)
    uint16_t filter2Remaining;        // 1032H 中效滤网2(小时)
    uint16_t filter3Remaining;        // 1033H 高效滤网3(小时)
    uint16_t humidityFilterRemaining; // 1034H 加湿模块(小时)
    uint16_t iefCleanRemaining;       // 1035H IEF需清洗(小时)
    uint16_t wholeUnitMaintenance;    // 1036H 整机保养(天)
    FilterMaintenanceData()
        : filter1Remaining(0), filter2Remaining(0), filter3Remaining(0),
          humidityFilterRemaining(0), iefCleanRemaining(0), wholeUnitMaintenance(0) {}
};

// ========== 设备能力标志（离散输入 3000H 位0-7，v1.22语义） ==========
struct CapabilityFlagsData {
    bool hasHumidificationModule; // 位0 有无加湿模块
    bool hasDehumidification;     // 位1 有无除湿模块
    bool hasBypassMode;           // 位2 有无(旁通/换气)模式
    bool hasIefPurification;      // 位3 有无IEF净化
    bool hasDisinfectModule;      // 位4 有无消毒模块
    bool hasElectricHeating;      // 位5 有无电加热控制
    bool hasFrostProtection;      // 位6 有无防冻保护
    bool hasFormaldehydeHcho;     // 位7 有无甲醛HCHO（v1.22新增）
    CapabilityFlagsData()
        : hasHumidificationModule(false), hasDehumidification(false),
          hasBypassMode(false), hasIefPurification(false),
          hasDisinfectModule(false), hasElectricHeating(false),
          hasFrostProtection(false), hasFormaldehydeHcho(false) {}
};

// ========== 网关通用数据结构类 ==========
class GatewayGeneralDataStructure {
public:
    GatewayGeneralDataStructure();
    ~GatewayGeneralDataStructure() = default;

    // 设备信息
    DeviceInfo& getDeviceInfo() { return m_deviceInfo; }
    const DeviceInfo& getDeviceInfo() const { return m_deviceInfo; }

    // 控制状态
    ControlStatus& getControlStatus() { return m_controlStatus; }
    const ControlStatus& getControlStatus() const { return m_controlStatus; }

    // 压缩机状态
    CompressorStatus& getCompressorStatus() { return m_compressorStatus; }
    const CompressorStatus& getCompressorStatus() const { return m_compressorStatus; }

    // 环境设定
    EnvironmentSettings& getEnvironmentSettings() { return m_environmentSettings; }
    const EnvironmentSettings& getEnvironmentSettings() const { return m_environmentSettings; }

    // 风机档位
    FanGears& getFanGears() { return m_fanGears; }
    const FanGears& getFanGears() const { return m_fanGears; }

    // 阀门状态
    ValveStatusData& getValveStatus() { return m_valveStatus; }
    const ValveStatusData& getValveStatus() const { return m_valveStatus; }

    // 风机转速
    FanRPM& getFanRPM() { return m_fanRPM; }
    const FanRPM& getFanRPM() const { return m_fanRPM; }

    // RA1传感器
    AirSensorData& getRA1Sensor() { return m_ra1Sensor; }
    const AirSensorData& getRA1Sensor() const { return m_ra1Sensor; }

    // OA传感器（可写入）
    AirSensorData& getOASensor() { return m_oaSensor; }
    const AirSensorData& getOASensor() const { return m_oaSensor; }

    // SA传感器
    AirSensorData& getSASensor() { return m_saSensor; }
    const AirSensorData& getSASensor() const { return m_saSensor; }

    // 进风口传感器（201EH-201FH）
    AirSensorData& getInletAirSensor() { return m_inletAirSensor; }
    const AirSensorData& getInletAirSensor() const { return m_inletAirSensor; }

    // 出风口传感器（2020H-2021H，预留）
    AirSensorData& getOutletAirSensor() { return m_outletAirSensor; }
    const AirSensorData& getOutletAirSensor() const { return m_outletAirSensor; }

    // 空气质量
    AirQualityData& getAirQuality() { return m_airQuality; }
    const AirQualityData& getAirQuality() const { return m_airQuality; }

    // 运行统计
    RuntimeStatistics& getRuntimeStatistics() { return m_runtimeStatistics; }
    const RuntimeStatistics& getRuntimeStatistics() const { return m_runtimeStatistics; }

    // 循环泵
    CirculationPumpData& getCirculationPump() { return m_circulationPump; }
    const CirculationPumpData& getCirculationPump() const { return m_circulationPump; }

    // 排水系统
    DrainageSystemData& getDrainageSystem() { return m_drainageSystem; }
    const DrainageSystemData& getDrainageSystem() const { return m_drainageSystem; }

    // 风机风量
    FanFlowData& getFanFlow() { return m_fanFlow; }
    const FanFlowData& getFanFlow() const { return m_fanFlow; }

    // 风阀控制
    DamperControlData& getDamperControl() { return m_damperControl; }
    const DamperControlData& getDamperControl() const { return m_damperControl; }

    // 厂测设定（102BH/102CH/1038H-103EH）
    FactoryTestSettings& getFactoryTestSettings() { return m_factoryTestSettings; }
    const FactoryTestSettings& getFactoryTestSettings() const { return m_factoryTestSettings; }

    // RTC时间（101BH-101FH）
    RtcTimeData& getRtcTime() { return m_rtcTime; }
    const RtcTimeData& getRtcTime() const { return m_rtcTime; }

    // 设备控制参数补充（1004H-1011H）
    DeviceControlParams& getDeviceControlParams() { return m_deviceControlParams; }
    const DeviceControlParams& getDeviceControlParams() const { return m_deviceControlParams; }

    // 定时/延时参数（1020H-1027H）
    TimingSettingsData& getTimingSettings() { return m_timingSettings; }
    const TimingSettingsData& getTimingSettings() const { return m_timingSettings; }

    // 滤网/保养剩余时间（1031H-1036H）
    FilterMaintenanceData& getFilterMaintenance() { return m_filterMaintenance; }
    const FilterMaintenanceData& getFilterMaintenance() const { return m_filterMaintenance; }

    // 设备能力标志（离散输入位0-7）
    CapabilityFlagsData& getCapabilityFlags() { return m_capabilityFlags; }
    const CapabilityFlagsData& getCapabilityFlags() const { return m_capabilityFlags; }

    // 故障码处理
    FaultCodeHandler& getFaultHandler() { return m_faultHandler; }
    const FaultCodeHandler& getFaultHandler() const { return m_faultHandler; }

    // 数据序列化/反序列化
    std::string toJson() const;
    bool fromJson(const std::string& json);

    // Modbus寄存器映射
    void readFromModbusRegisters(const uint16_t* registers, size_t count);
    void writeToModbusRegisters(uint16_t* registers, size_t count) const;

    // 辅助方法：温度转换
    static float convertTemperature(uint16_t rawValue);
    static uint16_t encodeTemperature(float temperature);

private:
    DeviceInfo m_deviceInfo;
    ControlStatus m_controlStatus;
    CompressorStatus m_compressorStatus;
    EnvironmentSettings m_environmentSettings;
    FanGears m_fanGears;
    ValveStatusData m_valveStatus;
    FanRPM m_fanRPM;
    AirSensorData m_ra1Sensor;
    AirSensorData m_oaSensor;
    AirSensorData m_saSensor;
    AirSensorData m_inletAirSensor;
    AirSensorData m_outletAirSensor;
    AirQualityData m_airQuality;
    RuntimeStatistics m_runtimeStatistics;
    CirculationPumpData m_circulationPump;
    DrainageSystemData m_drainageSystem;
    FanFlowData m_fanFlow;
    DamperControlData m_damperControl;
    FactoryTestSettings m_factoryTestSettings;
    RtcTimeData m_rtcTime;
    DeviceControlParams m_deviceControlParams;
    TimingSettingsData m_timingSettings;
    FilterMaintenanceData m_filterMaintenance;
    CapabilityFlagsData m_capabilityFlags;
    FaultCodeHandler m_faultHandler;
};

#endif // GATEWAYGENERARDATASTRUCTURE_H
