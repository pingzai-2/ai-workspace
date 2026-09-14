/**
 * 网关通用数据结构实现（根据协议文档v1.22）
 */

#include "GatewayGeneralDataStructure.h"
#include "common/GlobalFunction.h"
#include "gateways/BeiAng4CPGateway.h"
#include <hv/json.hpp>
#include <sstream>
#include <cmath>

using json = nlohmann::json;
using namespace std;
using namespace BeiAng4CPRegisters;

GatewayGeneralDataStructure::GatewayGeneralDataStructure() {
    // 初始化默认值
}

// ========== 温度转换方法 ==========
float GatewayGeneralDataStructure::convertTemperature(uint16_t rawValue) {
    // 协议格式：实际温度*10+2730
    return (static_cast<float>(rawValue) - 2730.0f) / 10.0f;
}

uint16_t GatewayGeneralDataStructure::encodeTemperature(float temperature) {
    // 协议格式：实际温度*10+2730
    return static_cast<uint16_t>(round(temperature * 10.0f) + 2730.0f);
}

// ========== JSON序列化 ==========
string GatewayGeneralDataStructure::toJson() const {
    json doc;

    // 设备信息
    doc["deviceInfo"]["factoryFlag"] = m_deviceInfo.factoryFlag;
    doc["deviceInfo"]["deviceModel"] = m_deviceInfo.deviceModel;
    doc["deviceInfo"]["deviceModelRaw"] = m_deviceInfo.deviceModelRaw;
    doc["deviceInfo"]["versionRaw"] = m_deviceInfo.versionRaw;
    doc["deviceInfo"]["version"] = m_deviceInfo.version;
    doc["deviceInfo"]["capabilityConfig"] = m_deviceInfo.capabilityConfig;
    doc["deviceInfo"]["deviceAddress"] = m_deviceInfo.deviceAddress;

    // 控制状态
    doc["controlStatus"]["switchOn"] = m_controlStatus.switchOn;
    doc["controlStatus"]["freshAirModuleOn"] = m_controlStatus.freshAirModuleOn;
    doc["controlStatus"]["superPureOn"] = m_controlStatus.superPureOn;
    doc["controlStatus"]["humidityModuleOn"] = m_controlStatus.humidityModuleOn;
    doc["controlStatus"]["faultCode1"] = m_controlStatus.faultCode1;
    doc["controlStatus"]["faultCode2"] = m_controlStatus.faultCode2;
    doc["controlStatus"]["runModeRaw"] = static_cast<int>(m_controlStatus.runMode);
    doc["controlStatus"]["leaveHomeOn"] = m_controlStatus.leaveHomeOn;
    doc["controlStatus"]["wholeUnitRunModeRaw"] = m_controlStatus.wholeUnitRunMode;
    doc["controlStatus"]["iefPurification"] = m_controlStatus.iefPurification;
    doc["controlStatus"]["humidificationOn"] = m_controlStatus.humidificationOn;
    doc["controlStatus"]["dehumidificationOn"] = m_controlStatus.dehumidificationOn;
    doc["controlStatus"]["auxHeat"] = static_cast<int>(m_controlStatus.auxHeat);
    doc["controlStatus"]["fanGear"] = m_controlStatus.fanGear;
    doc["controlStatus"]["steplessFanSwitch"] = m_controlStatus.steplessFanSwitch;
    doc["controlStatus"]["plasmaDisinfectOn"] = m_controlStatus.plasmaDisinfectOn;
    doc["controlStatus"]["fanMaxGear"] = m_controlStatus.fanMaxGear;
    doc["controlStatus"]["fanMaxGearRecirc"] = m_controlStatus.fanMaxGearRecirc;
    doc["controlStatus"]["autoCirculationDisplay"] = m_controlStatus.autoCirculationDisplay;

    // 压缩机状态
    doc["compressorStatus"]["status"] = m_compressorStatus.compressorStatus;
    doc["compressorStatus"]["defrosting"] = m_compressorStatus.defrosting;
    doc["compressorStatus"]["frequency"] = m_compressorStatus.operationFrequency;
    doc["compressorStatus"]["expansionValve"] = m_compressorStatus.expansionValve;
    doc["compressorStatus"]["dischargeTemperature"] = m_compressorStatus.dischargeTemperature;
    doc["compressorStatus"]["suctionTemperature"] = m_compressorStatus.suctionTemperature;
    doc["compressorStatus"]["evaporatorTemperature"] = m_compressorStatus.evaporatorTemperature;
    doc["compressorStatus"]["reservedTemperatureRaw"] = m_compressorStatus.reservedTemperatureRaw;
    doc["compressorStatus"]["highPressure"] = m_compressorStatus.highPressure;
    doc["compressorStatus"]["lowPressure"] = m_compressorStatus.lowPressure;
    doc["compressorStatus"]["acVoltageRaw"] = m_compressorStatus.acVoltageRaw;

    // 环境设定
    doc["environmentSettings"]["targetHumidity"] = m_environmentSettings.targetHumidity;
    doc["environmentSettings"]["targetTemperatureRaw"] = m_environmentSettings.targetTemperature;
    doc["environmentSettings"]["targetTemperature"] =
        static_cast<float>(static_cast<int16_t>(m_environmentSettings.targetTemperature)) / 10.0f;
    doc["environmentSettings"]["humidityIntensity"] = static_cast<int>(m_environmentSettings.humidityIntensity);
    doc["environmentSettings"]["saFanRatio"] = m_environmentSettings.saFanRatio;

    // 风机档位
    doc["fanGears"]["fan1"] = m_fanGears.fan1Gear;
    doc["fanGears"]["fan2"] = m_fanGears.fan2Gear;
    doc["fanGears"]["fan3"] = m_fanGears.fan3Gear;
    doc["fanGears"]["fan4"] = m_fanGears.fan4Gear;

    // 阀门状态
    doc["valveStatus"]["valve1"] = static_cast<int>(m_valveStatus.valve1);
    doc["valveStatus"]["valve2"] = static_cast<int>(m_valveStatus.valve2);
    doc["valveStatus"]["valve3"] = static_cast<int>(m_valveStatus.valve3);

    // 风机转速
    doc["fanRPM"]["fan1"] = m_fanRPM.fan1RPM;
    doc["fanRPM"]["fan2"] = m_fanRPM.fan2RPM;
    doc["fanRPM"]["fan3"] = m_fanRPM.fan3RPM;
    doc["fanRPM"]["fan4"] = m_fanRPM.fan4RPM;

    // RA1传感器
    doc["ra1Sensor"]["temperature"] = m_ra1Sensor.temperature;
    doc["ra1Sensor"]["humidity"] = m_ra1Sensor.humidity;
    doc["ra1Sensor"]["pm25"] = m_ra1Sensor.pm25;
    doc["ra1Sensor"]["co2"] = m_ra1Sensor.co2;

    // OA传感器
    doc["oaSensor"]["temperature"] = m_oaSensor.temperature;
    doc["oaSensor"]["humidity"] = m_oaSensor.humidity;
    doc["oaSensor"]["pm25"] = m_oaSensor.pm25;
    doc["oaSensor"]["co2"] = m_oaSensor.co2;

    // SA传感器
    doc["saSensor"]["temperature"] = m_saSensor.temperature;
    doc["saSensor"]["humidity"] = m_saSensor.humidity;
    doc["saSensor"]["pm25"] = m_saSensor.pm25;
    doc["saSensor"]["co2"] = m_saSensor.co2;

    // 进风口/出风口传感器（v1.22新增，出风口为预留）
    doc["inletSensor"]["temperature"] = m_inletAirSensor.temperature;
    doc["inletSensor"]["humidity"] = m_inletAirSensor.humidity;
    doc["outletSensor"]["temperature"] = m_outletAirSensor.temperature;
    doc["outletSensor"]["humidity"] = m_outletAirSensor.humidity;

    // 空气质量
    doc["airQuality"]["tvoc"] = m_airQuality.tvoc;
    doc["airQuality"]["formaldehyde"] = m_airQuality.formaldehyde;

    // 运行统计
    doc["runtimeStatistics"]["fanDelayOffTime"] = m_runtimeStatistics.fanDelayOffTime;
    doc["runtimeStatistics"]["filterRuntime"] = m_runtimeStatistics.filterRuntime;
    doc["runtimeStatistics"]["iefRuntime"] = m_runtimeStatistics.iefRuntime;
    doc["runtimeStatistics"]["fan1Runtime"] = m_runtimeStatistics.fan1Runtime;
    doc["runtimeStatistics"]["fan2Runtime"] = m_runtimeStatistics.fan2Runtime;
    doc["runtimeStatistics"]["fan3Runtime"] = m_runtimeStatistics.fan3Runtime;
    doc["runtimeStatistics"]["fan4Runtime"] = m_runtimeStatistics.fan4Runtime;
    doc["runtimeStatistics"]["systemRuntimeDays"] = m_runtimeStatistics.systemRuntimeDays;
    doc["runtimeStatistics"]["powerOnRuntime"] = m_runtimeStatistics.powerOnRuntime;

    // 循环泵
    doc["circulationPump"]["status"] = m_circulationPump.pumpStatus;
    doc["circulationPump"]["onTime"] = m_circulationPump.pumpOnTime;
    doc["circulationPump"]["offTime"] = m_circulationPump.pumpOffTime;

    // 排水系统
    doc["drainageSystem"]["drainValveStatus"] = m_drainageSystem.drainValveStatus;
    doc["drainageSystem"]["drainOnTime"] = m_drainageSystem.drainOnTime;
    doc["drainageSystem"]["drainCount"] = m_drainageSystem.drainCount;
    doc["drainageSystem"]["waterInletValve"] = m_drainageSystem.waterInletValve;
    doc["drainageSystem"]["inletFloatRaw"] = m_drainageSystem.inletFloatRaw;
    doc["drainageSystem"]["drainFloatRaw"] = m_drainageSystem.drainFloatRaw;

    doc["rtc"] = {
        {"year", m_rtcTime.year}, {"month", m_rtcTime.month},
        {"day", m_rtcTime.day}, {"hour", m_rtcTime.hour},
        {"minute", m_rtcTime.minute}, {"second", m_rtcTime.second},
        {"week", m_rtcTime.week}, {"format", m_rtcTime.format}
    };
    doc["deviceControlParams"] = {
        {"exhaustFanGearRaw", m_deviceControlParams.exhaustFanGear},
        {"freshAirDutyCycle", m_deviceControlParams.freshAirDutyCycle},
        {"exhaustAirDutyCycle", m_deviceControlParams.exhaustAirDutyCycle},
        {"boostFanDutyCycle", m_deviceControlParams.boostFanDutyCycle},
        {"auxHeatSettingRaw", m_deviceControlParams.auxHeatSetting},
        {"compressorEevRaw", m_deviceControlParams.compressorEEVOpening},
        {"compressorFrequencySetRaw", m_deviceControlParams.compressorFrequencySet},
        {"compressorFrequencyMaxRaw", m_deviceControlParams.compressorFrequencyMax}
    };
    doc["timingSettings"] = {
        {"fanDelayOffMinutes", m_timingSettings.fanDelayOffTime},
        {"circulationPumpOnSeconds", m_timingSettings.circPumpOnTime},
        {"circulationPumpOffSeconds", m_timingSettings.circPumpOffTime},
        {"drainOnSeconds", m_timingSettings.drainOnTime},
        {"offModeAirQualityEnabled", m_timingSettings.offModeAqSwitch != 0},
        {"offModeAirQualityIntervalMinutes", m_timingSettings.offModeAqInterval},
        {"offModeAirQualityRuntimeMinutes", m_timingSettings.offModeAqRuntime}
    };
    doc["filterMaintenance"] = {
        {"filter1RemainingHours", m_filterMaintenance.filter1Remaining},
        {"filter2RemainingHours", m_filterMaintenance.filter2Remaining},
        {"filter3RemainingHours", m_filterMaintenance.filter3Remaining},
        {"humidityFilterRemainingHours", m_filterMaintenance.humidityFilterRemaining},
        {"iefCleanRemainingHours", m_filterMaintenance.iefCleanRemaining},
        {"wholeUnitMaintenanceRemainingDays", m_filterMaintenance.wholeUnitMaintenance}
    };
    doc["capabilities"] = {
        {"humidificationModule", m_capabilityFlags.hasHumidificationModule},
        {"dehumidification", m_capabilityFlags.hasDehumidification},
        {"bypassMode", m_capabilityFlags.hasBypassMode},
        {"iefPurification", m_capabilityFlags.hasIefPurification},
        {"disinfectModule", m_capabilityFlags.hasDisinfectModule},
        {"electricHeating", m_capabilityFlags.hasElectricHeating},
        {"frostProtection", m_capabilityFlags.hasFrostProtection},
        {"formaldehydeHcho", m_capabilityFlags.hasFormaldehydeHcho}
    };

    doc["fanFlow"]["fan1External"] = m_fanFlow.fan1ExternalFlow;
    doc["fanFlow"]["fan1Internal"] = m_fanFlow.fan1InternalFlow;
    doc["fanFlow"]["fan2External"] = m_fanFlow.fan2ExternalFlow;
    doc["fanFlow"]["fan2Internal"] = m_fanFlow.fan2InternalFlow;
    doc["fanFlow"]["fan3External"] = m_fanFlow.fan3ExternalFlow;
    doc["fanFlow"]["fan3Internal"] = m_fanFlow.fan3InternalFlow;
    doc["fanFlow"]["fan4External"] = m_fanFlow.fan4ExternalFlow;
    doc["fanFlow"]["fan4Internal"] = m_fanFlow.fan4InternalFlow;
    doc["damperControl"] = {
        {"damper1DirectionRaw", m_damperControl.damper1Direction ? 1 : 0},
        {"damper2DirectionRaw", m_damperControl.damper2Direction ? 1 : 0},
        {"damper3DirectionRaw", m_damperControl.damper3Direction ? 1 : 0},
        {"damper1Steps", m_damperControl.damper1Steps},
        {"damper2Steps", m_damperControl.damper2Steps},
        {"damper3Steps", m_damperControl.damper3Steps}
    };
    doc["factoryTestSettings"] = {
        {"factoryTestModeRaw", m_deviceInfo.factoryTestMode},
        {"factoryTestActive", m_deviceInfo.factoryTestActive},
        {"highPressureSwitchOn", m_factoryTestSettings.highPressureSwitchOn},
        {"lowPressureSwitchOn", m_factoryTestSettings.lowPressureSwitchOn},
        {"fan1CurrentSetting", m_factoryTestSettings.fan1CurrentSetting},
        {"fan2CurrentSetting", m_factoryTestSettings.fan2CurrentSetting},
        {"fan3CurrentSetting", m_factoryTestSettings.fan3CurrentSetting},
        {"fan4CurrentSetting", m_factoryTestSettings.fan4CurrentSetting},
        {"valve1SettingRaw", static_cast<int>(m_factoryTestSettings.valve1Setting)},
        {"valve2SettingRaw", static_cast<int>(m_factoryTestSettings.valve2Setting)},
        {"valve3SettingRaw", static_cast<int>(m_factoryTestSettings.valve3Setting)}
    };
    doc["controllerVersionTime"] = m_deviceInfo.controllerVersionTime;
    doc["drainageSystem"]["offAirQualityDetecting"] =
        m_drainageSystem.offAirQualityDetecting;

    return doc.dump();
}

// ========== JSON反序列化 ==========
bool GatewayGeneralDataStructure::fromJson(const string& jsonStr) {
    try {
        json doc = json::parse(jsonStr);

        // 解析设备信息
        if (doc.contains("deviceInfo") && doc["deviceInfo"].is_object()) {
            const auto& deviceInfo = doc["deviceInfo"];
            if (deviceInfo.contains("factoryFlag"))
                m_deviceInfo.factoryFlag = deviceInfo["factoryFlag"].get<string>();
            if (deviceInfo.contains("deviceModel"))
                m_deviceInfo.deviceModel = deviceInfo["deviceModel"].get<string>();
            if (deviceInfo.contains("version"))
                m_deviceInfo.version = deviceInfo["version"].get<string>();
            if (deviceInfo.contains("deviceModelRaw"))
                m_deviceInfo.deviceModelRaw = deviceInfo["deviceModelRaw"].get<uint16_t>();
            if (deviceInfo.contains("versionRaw"))
                m_deviceInfo.versionRaw = deviceInfo["versionRaw"].get<uint16_t>();
            if (deviceInfo.contains("capabilityConfig"))
                m_deviceInfo.capabilityConfig = deviceInfo["capabilityConfig"].get<unsigned int>();
            if (deviceInfo.contains("deviceAddress"))
                m_deviceInfo.deviceAddress = deviceInfo["deviceAddress"].get<int>();
        }

        // 解析控制状态
        if (doc.contains("controlStatus") && doc["controlStatus"].is_object()) {
            const auto& controlStatus = doc["controlStatus"];
            if (controlStatus.contains("switchOn"))
                m_controlStatus.switchOn = controlStatus["switchOn"].get<bool>();
            if (controlStatus.contains("faultCode1"))
                m_controlStatus.faultCode1 = controlStatus["faultCode1"].get<unsigned int>();
            if (controlStatus.contains("faultCode2"))
                m_controlStatus.faultCode2 = controlStatus["faultCode2"].get<unsigned int>();
            if (controlStatus.contains("runMode"))
                m_controlStatus.runMode = static_cast<AirCirculationMode>(controlStatus["runMode"].get<int>());
            if (controlStatus.contains("leaveHomeOn"))
                m_controlStatus.leaveHomeOn = controlStatus["leaveHomeOn"].get<bool>();
            if (controlStatus.contains("iefPurification"))
                m_controlStatus.iefPurification = controlStatus["iefPurification"].get<bool>();
            if (controlStatus.contains("humidificationOn"))
                m_controlStatus.humidificationOn = controlStatus["humidificationOn"].get<bool>();
            if (controlStatus.contains("dehumidificationOn"))
                m_controlStatus.dehumidificationOn = controlStatus["dehumidificationOn"].get<bool>();
            if (controlStatus.contains("auxHeat"))
                m_controlStatus.auxHeat = static_cast<AuxHeatMode>(controlStatus["auxHeat"].get<int>());
            if (controlStatus.contains("fanGear"))
                m_controlStatus.fanGear = controlStatus["fanGear"].get<int>();
        }

        // 解析环境设定
        if (doc.contains("environmentSettings") && doc["environmentSettings"].is_object()) {
            const auto& envSettings = doc["environmentSettings"];
            if (envSettings.contains("targetHumidity"))
                m_environmentSettings.targetHumidity = envSettings["targetHumidity"].get<int>();
            if (envSettings.contains("humidityIntensity"))
                m_environmentSettings.humidityIntensity = static_cast<HumidityIntensity>(envSettings["humidityIntensity"].get<int>());
            if (envSettings.contains("saFanRatio"))
                m_environmentSettings.saFanRatio = envSettings["saFanRatio"].get<float>();
        }

        return true;
    } catch (const json::exception& e) {
        return false;
    }
}

// ========== Modbus寄存器读取 ==========
void GatewayGeneralDataStructure::readFromModbusRegisters(const uint16_t* registers, size_t count) {
    // 寄存器映射根据协议文档v1.10
    // 假设从1000H开始读取所有寄存器

    if (count < 23) return;  // 至少需要23个寄存器（1000H-1016H）

    // ========== 基础信息（1000H-1004H）==========
    // 1000H: 工厂标志（两位ASCII字符：BA）
    char flag[3] = {
        static_cast<char>((registers[0] >> 8) & 0xFF),
        static_cast<char>(registers[0] & 0xFF),
        '\0'
    };
    m_deviceInfo.factoryFlag = string(flag);

    // 1001H: 机型（0101）
    m_deviceInfo.deviceModelRaw = registers[1];
    m_deviceInfo.deviceModel = to_string(registers[1]);

    // 1002H: 版本
    m_deviceInfo.versionRaw = registers[2];
    m_deviceInfo.version = to_string(registers[2]);

    // 1003H: 能力配置表
    m_deviceInfo.capabilityConfig = registers[3];

    // 1004H: 能力配置表预留
    m_deviceInfo.capabilityReserved = registers[4];

    // ========== 控制状态（1005H-100FH）==========
    // 1005H: 开关（0:关闭, 1:开启）
    m_controlStatus.switchOn = (registers[5] != 0);

    // 1006H: 故障码1
    m_controlStatus.faultCode1 = registers[6];

    // 1007H: 故障码2
    m_controlStatus.faultCode2 = registers[7];

    // 解析故障码
    m_faultHandler.parseFaultCodes(m_controlStatus.faultCode1, m_controlStatus.faultCode2);

    // 1008H: 运行模式（0:内循环, 1:混风, 2:新风）
    m_controlStatus.runMode = static_cast<AirCirculationMode>(registers[8]);

    // 1009H: IEF净化（0:关闭, 1:开启）
    m_controlStatus.iefPurification = (registers[10] != 0);

    // 100BH: 加湿开关（0:关闭, 1:开启）
    m_controlStatus.humidificationOn = (registers[11] != 0);

    // 100CH: 除湿开关（0:关闭, 1:开启）
    m_controlStatus.dehumidificationOn = (registers[12] != 0);

    // 100DH: 电辅热（0x00:关闭, 0x01:开启1, 0x02:开启2, 0x03:开启1和2）
    m_controlStatus.auxHeat = static_cast<AuxHeatMode>(registers[13]);

    // 100EH: 风量档位（0-6）
    m_controlStatus.fanGear = registers[14];

    // 100FH: 风量最大档位（6）
    m_controlStatus.fanMaxGear = registers[15];

    // ========== 压缩机状态（1016H-1018H）==========
    if (count > 22) {
        // 1016H: 压缩机状态
        m_compressorStatus.compressorStatus = registers[22];

        // 1017H: 运行频率
        m_compressorStatus.operationFrequency = registers[23];

        // 1018H: 电子膨胀阀开度
        m_compressorStatus.expansionValve = registers[24];
    }

    // ========== 环境设定（1019H-101BH）==========
    if (count > 25) {
        // 1019H: 目标湿度设定（30-70）
        m_environmentSettings.targetHumidity = registers[25];

        // 101AH: 加湿/除湿强度设定（0:弱, 1:中, 2:强）
        m_environmentSettings.humidityIntensity = static_cast<HumidityIntensity>(registers[26]);

        // 101BH: SA风量与增压风机比例设定（实际值*10）
        m_environmentSettings.saFanRatio = registers[27] / 10.0f;
    }

    // ========== 风机档位（101CH-101FH）==========
    if (count > 28) {
        m_fanGears.fan1Gear = registers[28];
        m_fanGears.fan2Gear = registers[29];
        m_fanGears.fan3Gear = registers[30];
        m_fanGears.fan4Gear = registers[31];
    }

    // ========== 阀门状态（1020H-1022H）==========
    if (count > 32) {
        m_valveStatus.valve1 = static_cast<ValveStatus>(registers[32]);
        m_valveStatus.valve2 = static_cast<ValveStatus>(registers[33]);
        m_valveStatus.valve3 = static_cast<ValveStatus>(registers[34]);
    }

    // ========== 风机转速（1023H-1026H）==========
    if (count > 35) {
        m_fanRPM.fan1RPM = registers[35];
        m_fanRPM.fan2RPM = registers[36];
        m_fanRPM.fan3RPM = registers[37];
        m_fanRPM.fan4RPM = registers[38];
    }

    // ========== RA1传感器（1027H-102AH）==========
    if (count > 42) {
        // 1027H: RA1温度（实际温度*10+2730）
        m_ra1Sensor.temperature = convertTemperature(registers[39]);

        // 1028H: RA1湿度（0-100, 1%RH）
        m_ra1Sensor.humidity = registers[40];

        // 1029H: RA1 PM2.5
        m_ra1Sensor.pm25 = registers[41];

        // 102AH: RA1 CO2
        m_ra1Sensor.co2 = registers[42];
    }

    // ========== OA传感器（102BH-102EH）==========
    if (count > 46) {
        // 102BH: OA温度
        m_oaSensor.temperature = convertTemperature(registers[43]);

        // 102CH: OA湿度
        m_oaSensor.humidity = registers[44];

        // 102DH: OA PM2.5
        m_oaSensor.pm25 = registers[45];

        // 102EH: OA CO2
        m_oaSensor.co2 = registers[46];
    }

    // ========== SA传感器（102FH-1032H）==========
    if (count > 50) {
        // 102FH: SA温度
        m_saSensor.temperature = convertTemperature(registers[47]);

        // 1030H: SA湿度
        m_saSensor.humidity = registers[48];

        // 1031H: SA PM2.5
        m_saSensor.pm25 = registers[49];

        // 1032H: SA CO2
        m_saSensor.co2 = registers[50];
    }

    // ========== 空气质量（1033H-1034H）==========
    if (count > 52) {
        // 1033H: TVOC
        m_airQuality.tvoc = registers[51];

        // 1034H: 甲醛
        m_airQuality.formaldehyde = registers[52];
    }

    // ========== 延时时间（1035H）==========
    if (count > 53) {
        m_runtimeStatistics.fanDelayOffTime = registers[53];
    }

    // ========== 运行时间统计（1037H-103DH）==========
    if (count > 61) {
        m_runtimeStatistics.filterRuntime = registers[55];      // 1037H
        m_runtimeStatistics.iefRuntime = registers[56];         // 1038H
        m_runtimeStatistics.fan1Runtime = registers[57];         // 1039H
        m_runtimeStatistics.fan2Runtime = registers[58];         // 103AH
        m_runtimeStatistics.fan3Runtime = registers[59];         // 103BH
        m_runtimeStatistics.fan4Runtime = registers[60];         // 103CH
        m_runtimeStatistics.powerOnRuntime = registers[61];      // 103DH
    }

    // ========== 循环泵（1040H-1042H）==========
    if (count > 66) {
        m_circulationPump.pumpStatus = (registers[64] != 0);    // 1040H
        m_circulationPump.pumpOnTime = registers[65];          // 1041H
        m_circulationPump.pumpOffTime = registers[66];         // 1042H
    }

    // ========== 排水系统（1043H-1048H）==========
    if (count > 72) {
        m_drainageSystem.drainValveStatus = (registers[67] != 0);  // 1043H
        m_drainageSystem.drainOnTime = registers[68];              // 1044H
        m_drainageSystem.drainCount = registers[69];                // 1045H
        m_drainageSystem.waterInletValve = (registers[70] != 0);    // 1046H
        m_drainageSystem.inletFloatRaw = registers[71];          // 旧兼容解析，不用于当前协议
        m_drainageSystem.drainFloatRaw = registers[72];          // 旧兼容解析，不用于当前协议
    }
}

// ========== Modbus寄存器写入 ==========
void GatewayGeneralDataStructure::writeToModbusRegisters(uint16_t* registers, size_t count) const {
    if (count < 23) return;

    // 写入控制寄存器（1005H-100EH）
    registers[5] = m_controlStatus.switchOn ? 1 : 0;          // 1005H
    registers[8] = static_cast<uint16_t>(m_controlStatus.runMode);         // 1008H
    registers[10] = m_controlStatus.iefPurification ? 1 : 0;  // 100AH
    registers[11] = m_controlStatus.humidificationOn ? 1 : 0;  // 100BH
    registers[12] = m_controlStatus.dehumidificationOn ? 1 : 0; // 100CH
    registers[13] = static_cast<uint16_t>(m_controlStatus.auxHeat);         // 100DH
    registers[14] = m_controlStatus.fanGear;                   // 100EH

    // 写入环境设定（1019H-101BH）
    if (count > 27) {
        registers[25] = m_environmentSettings.targetHumidity;              // 1019H
        registers[26] = static_cast<uint16_t>(m_environmentSettings.humidityIntensity);  // 101AH
        registers[27] = static_cast<uint16_t>(m_environmentSettings.saFanRatio * 10);    // 101BH
    }

    // 写入OA传感器（可写入）
    if (count > 46) {
        registers[43] = encodeTemperature(m_oaSensor.temperature); // 102BH
        registers[44] = static_cast<uint16_t>(m_oaSensor.humidity);      // 102CH
        registers[45] = static_cast<uint16_t>(m_oaSensor.pm25);          // 102DH
        registers[46] = static_cast<uint16_t>(m_oaSensor.co2);           // 102EH
    }

    // 写入运行时间统计
    if (count > 61) {
        registers[55] = m_runtimeStatistics.filterRuntime;      // 1037H
        registers[56] = m_runtimeStatistics.iefRuntime;          // 1038H
        registers[57] = m_runtimeStatistics.fan1Runtime;          // 1039H
        registers[58] = m_runtimeStatistics.fan2Runtime;          // 103AH
        registers[59] = m_runtimeStatistics.fan3Runtime;          // 103BH
        registers[60] = m_runtimeStatistics.fan4Runtime;          // 103CH
        registers[61] = m_runtimeStatistics.powerOnRuntime;      // 103DH
    }
}
