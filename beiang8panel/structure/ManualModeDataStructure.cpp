/**
 * 手动模式数据结构实现
 */

#include "ManualModeDataStructure.h"
#include <hv/json.hpp>

using json = nlohmann::json;
using namespace std;

ManualModeDataStructure::ManualModeDataStructure() {
    // 初始化默认值
}

string ManualModeDataStructure::toJson() const {
    json doc;
    doc["powerOn"] = m_params.powerOn;
    doc["fanSpeedLevel"] = m_params.fanSpeedLevel;
    doc["uvLightOn"] = m_params.uvLightOn;
    doc["ionizerOn"] = m_params.ionizerOn;
    doc["targetHumidity"] = m_params.targetHumidity;
    doc["humidifierOn"] = m_params.humidifierOn;
    return doc.dump();
}

bool ManualModeDataStructure::fromJson(const string& jsonStr) {
    try {
        json doc = json::parse(jsonStr);

        if (doc.contains("powerOn"))
            m_params.powerOn = doc["powerOn"].get<bool>();

        if (doc.contains("fanSpeedLevel"))
            m_params.fanSpeedLevel = doc["fanSpeedLevel"].get<int>();

        if (doc.contains("uvLightOn"))
            m_params.uvLightOn = doc["uvLightOn"].get<bool>();

        if (doc.contains("ionizerOn"))
            m_params.ionizerOn = doc["ionizerOn"].get<bool>();

        if (doc.contains("targetHumidity"))
            m_params.targetHumidity = doc["targetHumidity"].get<int>();

        if (doc.contains("humidifierOn"))
            m_params.humidifierOn = doc["humidifierOn"].get<bool>();

        return true;
    } catch (const json::exception& e) {
        return false;
    }
}

void ManualModeDataStructure::readFromModbusRegisters(const uint16_t* registers, size_t count) {
    // TODO: 从Modbus寄存器读取手动模式数据
    (void)registers;
    (void)count;
}

void ManualModeDataStructure::writeToModbusRegisters(uint16_t* registers, size_t count) const {
    // TODO: 写入手动模式数据到Modbus寄存器
    (void)registers;
    (void)count;
}
