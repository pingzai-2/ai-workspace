/**
 * 首页API实现
 */

#include "HomePage.h"
#include "common/GlobalFunction.h"
#include "structure/GatewayGeneralDataStructure.h"
#include "common/GlobalDefine.h"
#include <nlohmann/json.hpp>

using json = nlohmann::json;

HomePage::HomePage(DataManager* dataManager)
    : BasePage(dataManager)
{
}

std::string HomePage::getHomeData() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& controlStatus = gatewayData.getControlStatus();
        auto& deviceInfo = gatewayData.getDeviceInfo();

        json data;
        data["device"]["factoryFlag"] = deviceInfo.factoryFlag;
        data["device"]["deviceModel"] = deviceInfo.deviceModel;
        data["device"]["version"] = deviceInfo.version;
        data["device"]["deviceAddress"] = deviceInfo.deviceAddress;

        data["control"]["switchOn"] = controlStatus.switchOn;                // 1000H 总开关
        data["control"]["freshAirModuleOn"] = controlStatus.freshAirModuleOn; // 1001H 新风模块开关
        data["control"]["superPureOn"] = controlStatus.superPureOn;           // 1002H 超净模式开关
        data["control"]["humidityModuleOn"] = controlStatus.humidityModuleOn; // 1003H 调湿模块开关
        data["control"]["runMode"] = static_cast<int>(controlStatus.runMode); // 1007H 新风运行模式(0-5)
        data["control"]["leaveHomeOn"] = controlStatus.leaveHomeOn;           // 1006H 一键离家开关(v1.22)
        data["control"]["wholeUnitRunMode"] = controlStatus.wholeUnitRunMode; // 100AH 整机运行模式(0-5)
        data["control"]["autoCirculationDisplay"] = controlStatus.autoCirculationDisplay; // 201DH 自动模式时内外循环显示
        data["control"]["iefPurification"] = controlStatus.iefPurification;   // 1012H IEF开关
        data["control"]["plasmaDisinfectOn"] = controlStatus.plasmaDisinfectOn; // 1011H 等离子消毒
        data["control"]["steplessFanSwitch"] = controlStatus.steplessFanSwitch; // 100BH 无极风量开关
        data["control"]["fanGear"] = controlStatus.fanGear;                   // 1008H 风量档位
        data["control"]["fanMaxGear"] = controlStatus.fanMaxGear;             // 2003H 新风模式最大档位
        data["control"]["fanMaxGearRecirc"] = controlStatus.fanMaxGearRecirc; // 2004H 内循环/混风模式最大档位
        data["control"]["auxHeat"] = static_cast<int>(controlStatus.auxHeat); // 201CH 电辅热状态
        data["control"]["humidificationOn"] = controlStatus.humidificationOn; // 1004H 加湿开关
        data["control"]["dehumidificationOn"] = controlStatus.dehumidificationOn; // 1005H 除湿开关

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取首页数据失败: ") + e.what());
    }
}

std::string HomePage::getDeviceSummary() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& controlStatus = gatewayData.getControlStatus();
        auto& deviceInfo = gatewayData.getDeviceInfo();
        auto& ra1Sensor = gatewayData.getRA1Sensor();
        auto& saSensor = gatewayData.getSASensor();
        auto& oaSensor = gatewayData.getOASensor();

        json data;
        data["device"]["switchOn"] = controlStatus.switchOn;
        data["device"]["runMode"] = static_cast<int>(controlStatus.runMode);
        data["device"]["fanGear"] = controlStatus.fanGear;
        data["device"]["faultCode1"] = controlStatus.faultCode1;
        data["device"]["faultCode2"] = controlStatus.faultCode2;

        data["environment"]["ra1"]["temperature"] = ra1Sensor.temperature;
        data["environment"]["ra1"]["humidity"] = ra1Sensor.humidity;
        data["environment"]["ra1"]["pm25"] = ra1Sensor.pm25;
        data["environment"]["ra1"]["co2"] = ra1Sensor.co2;

        data["environment"]["sa"]["temperature"] = saSensor.temperature;
        data["environment"]["sa"]["humidity"] = saSensor.humidity;
        data["environment"]["sa"]["pm25"] = saSensor.pm25;
        data["environment"]["sa"]["co2"] = saSensor.co2;

        data["environment"]["oa"]["temperature"] = oaSensor.temperature;
        data["environment"]["oa"]["humidity"] = oaSensor.humidity;
        data["environment"]["oa"]["pm25"] = oaSensor.pm25;
        data["environment"]["oa"]["co2"] = oaSensor.co2;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取设备摘要失败: ") + e.what());
    }
}

std::string HomePage::getEnvironmentData() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& ra1Sensor = gatewayData.getRA1Sensor();
        auto& saSensor = gatewayData.getSASensor();
        auto& oaSensor = gatewayData.getOASensor();
        auto& airQuality = gatewayData.getAirQuality();

        json data;
        data["ra1"]["temperature"] = ra1Sensor.temperature;
        data["ra1"]["humidity"] = ra1Sensor.humidity;
        data["ra1"]["pm25"] = ra1Sensor.pm25;
        data["ra1"]["co2"] = ra1Sensor.co2;

        data["sa"]["temperature"] = saSensor.temperature;
        data["sa"]["humidity"] = saSensor.humidity;
        data["sa"]["pm25"] = saSensor.pm25;
        data["sa"]["co2"] = saSensor.co2;

        data["oa"]["temperature"] = oaSensor.temperature;
        data["oa"]["humidity"] = oaSensor.humidity;
        data["oa"]["pm25"] = oaSensor.pm25;
        data["oa"]["co2"] = oaSensor.co2;

        data["airQuality"]["tvoc"] = airQuality.tvoc;
        data["airQuality"]["formaldehyde"] = airQuality.formaldehyde;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取环境数据失败: ") + e.what());
    }
}

std::string HomePage::getAirQualityData() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& airQuality = gatewayData.getAirQuality();

        json data;
        data["tvoc"] = airQuality.tvoc;
        data["formaldehyde"] = airQuality.formaldehyde;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取空气质量数据失败: ") + e.what());
    }
}

std::string HomePage::getCompressorStatus() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& compressorStatus = gatewayData.getCompressorStatus();

        json data;
        data["compressorStatus"] = compressorStatus.compressorStatus;
        data["operationFrequency"] = compressorStatus.operationFrequency;
        data["expansionValve"] = compressorStatus.expansionValve;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取压缩机状态失败: ") + e.what());
    }
}

std::string HomePage::getValveStatus() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& valveStatus = gatewayData.getValveStatus();

        json data;
        data["valve1"] = static_cast<int>(valveStatus.valve1);
        data["valve2"] = static_cast<int>(valveStatus.valve2);
        data["valve3"] = static_cast<int>(valveStatus.valve3);

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取阀门状态失败: ") + e.what());
    }
}

std::string HomePage::getDamperControlStatus() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& damperControl = gatewayData.getDamperControl();

        json data;
        data["damper1"]["direction"] = damperControl.damper1Direction;
        data["damper1"]["steps"] = damperControl.damper1Steps;
        data["damper2"]["direction"] = damperControl.damper2Direction;
        data["damper2"]["steps"] = damperControl.damper2Steps;
        data["damper3"]["direction"] = damperControl.damper3Direction;
        data["damper3"]["steps"] = damperControl.damper3Steps;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取风阀状态失败: ") + e.what());
    }
}

std::string HomePage::getFanRPMData() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& fanRPM = gatewayData.getFanRPM();

        json data;
        data["fan1RPM"] = fanRPM.fan1RPM;
        data["fan2RPM"] = fanRPM.fan2RPM;
        data["fan3RPM"] = fanRPM.fan3RPM;
        data["fan4RPM"] = fanRPM.fan4RPM;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取风机转速失败: ") + e.what());
    }
}

std::string HomePage::getFanFlowData() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& fanFlow = gatewayData.getFanFlow();

        // v1.22：1041H-1070H，每台风机分外循环/内循环各6档
        json data;
        data["fan1ExternalFlow"] = fanFlow.fan1ExternalFlow;
        data["fan1InternalFlow"] = fanFlow.fan1InternalFlow;
        data["fan2ExternalFlow"] = fanFlow.fan2ExternalFlow;
        data["fan2InternalFlow"] = fanFlow.fan2InternalFlow;
        data["fan3ExternalFlow"] = fanFlow.fan3ExternalFlow;
        data["fan3InternalFlow"] = fanFlow.fan3InternalFlow;
        data["fan4ExternalFlow"] = fanFlow.fan4ExternalFlow;
        data["fan4InternalFlow"] = fanFlow.fan4InternalFlow;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取风机风量失败: ") + e.what());
    }
}

std::string HomePage::getHumidifierSystemStatus() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& circulationPump = gatewayData.getCirculationPump();
        auto& drainageSystem = gatewayData.getDrainageSystem();

        json data;
        data["circulationPump"]["status"] = circulationPump.pumpStatus;
        data["circulationPump"]["onTime"] = circulationPump.pumpOnTime;
        data["circulationPump"]["offTime"] = circulationPump.pumpOffTime;

        data["drainage"]["drainValveStatus"] = drainageSystem.drainValveStatus;
        data["drainage"]["drainOnTime"] = drainageSystem.drainOnTime;
        data["drainage"]["drainCount"] = drainageSystem.drainCount;
        data["drainage"]["waterInletValve"] = drainageSystem.waterInletValve;
        data["drainage"]["inletFloatRaw"] = drainageSystem.inletFloatRaw;
        data["drainage"]["drainFloatRaw"] = drainageSystem.drainFloatRaw;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取加湿系统状态失败: ") + e.what());
    }
}

std::string HomePage::getDrainageSystemStatus() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& drainageSystem = gatewayData.getDrainageSystem();

        json data;
        data["drainValveStatus"] = drainageSystem.drainValveStatus;
        data["drainOnTime"] = drainageSystem.drainOnTime;
        data["drainCount"] = drainageSystem.drainCount;
        data["waterInletValve"] = drainageSystem.waterInletValve;
        data["inletFloatRaw"] = drainageSystem.inletFloatRaw;
        data["drainFloatRaw"] = drainageSystem.drainFloatRaw;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取排水系统状态失败: ") + e.what());
    }
}

std::string HomePage::quickPowerOn(bool on) {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& controlStatus = gatewayData.getControlStatus();

        // 这里需要通过modbus实际控制设备（v1.22总开关寄存器1000H）
        // 注意：目前仅修改内存缓存，未下发Modbus；设备侧写入见
        // BeiAng4CPGateway::setSwitchControl()
        controlStatus.switchOn = on;

        json data;
        data["switchOn"] = on;
        data["success"] = true;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("快捷电源控制失败: ") + e.what());
    }
}

std::string HomePage::quickSetMode(int mode) {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& controlStatus = gatewayData.getControlStatus();

        // v1.22新风运行模式0-5：0内循环 1内循环/混风 2全热新风/节能新风 3自动 4旁通/换气 5睡眠
        if (mode < 0 || mode > 5) {
            return buildInvalidParameter("mode", "运行模式必须在0-5范围内");
        }

        controlStatus.runMode = static_cast<AirCirculationMode>(mode);

        json data;
        data["runMode"] = mode;
        data["success"] = true;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("快捷模式切换失败: ") + e.what());
    }
}

std::string HomePage::getRealtimeSummary() {
    try {
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& controlStatus = gatewayData.getControlStatus();
        auto& ra1Sensor = gatewayData.getRA1Sensor();
        auto& airQuality = gatewayData.getAirQuality();
        auto& compressorStatus = gatewayData.getCompressorStatus();
        auto& fanRPM = gatewayData.getFanRPM();

        json data;
        data["device"]["switchOn"] = controlStatus.switchOn;
        data["device"]["runMode"] = static_cast<int>(controlStatus.runMode);
        data["device"]["fanGear"] = controlStatus.fanGear;

        data["environment"]["temperature"] = ra1Sensor.temperature;
        data["environment"]["humidity"] = ra1Sensor.humidity;
        data["environment"]["pm25"] = ra1Sensor.pm25;
        data["environment"]["co2"] = ra1Sensor.co2;
        data["environment"]["tvoc"] = airQuality.tvoc;
        data["environment"]["formaldehyde"] = airQuality.formaldehyde;

        data["system"]["compressorStatus"] = compressorStatus.compressorStatus;
        data["system"]["fan1RPM"] = fanRPM.fan1RPM;
        data["system"]["iefPurification"] = controlStatus.iefPurification;

        return buildSuccessWithData(data);
    } catch (const std::exception& e) {
        return buildError(std::string("获取实时摘要失败: ") + e.what());
    }
}
