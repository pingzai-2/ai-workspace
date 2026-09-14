/**
 * 智能模式数据结构实现
 */

#include "SmartModeDataStructure.h"
#include <hv/json.hpp>

using json = nlohmann::json;
using namespace std;

SmartModeDataStructure::SmartModeDataStructure() {
    // 初始化默认值
}

string SmartModeDataStructure::toJson() const {
    json doc;
    doc["scene"] = static_cast<int>(m_params.scene);
    doc["autoAdjustFan"] = m_params.autoAdjustFan;
    doc["autoAdjustHumidity"] = m_params.autoAdjustHumidity;
    doc["targetPM25"] = m_params.targetPM25;
    doc["targetCO2"] = m_params.targetCO2;
    doc["sleepTimeStart"] = m_params.sleepTimeStart;
    doc["sleepTimeEnd"] = m_params.sleepTimeEnd;
    return doc.dump();
}

bool SmartModeDataStructure::fromJson(const string& jsonStr) {
    try {
        json doc = json::parse(jsonStr);

        if (doc.contains("scene"))
            m_params.scene = static_cast<SmartScene>(doc["scene"].get<int>());

        if (doc.contains("autoAdjustFan"))
            m_params.autoAdjustFan = doc["autoAdjustFan"].get<bool>();

        if (doc.contains("autoAdjustHumidity"))
            m_params.autoAdjustHumidity = doc["autoAdjustHumidity"].get<bool>();

        if (doc.contains("targetPM25"))
            m_params.targetPM25 = doc["targetPM25"].get<double>();

        if (doc.contains("targetCO2"))
            m_params.targetCO2 = doc["targetCO2"].get<double>();

        if (doc.contains("sleepTimeStart"))
            m_params.sleepTimeStart = doc["sleepTimeStart"].get<int>();

        if (doc.contains("sleepTimeEnd"))
            m_params.sleepTimeEnd = doc["sleepTimeEnd"].get<int>();

        return true;
    } catch (const json::exception& e) {
        return false;
    }
}

void SmartModeDataStructure::readFromModbusRegisters(const uint16_t* registers, size_t count) {
    // TODO: 从Modbus寄存器读取智能模式数据
    (void)registers;
    (void)count;
}

void SmartModeDataStructure::writeToModbusRegisters(uint16_t* registers, size_t count) const {
    // TODO: 写入智能模式数据到Modbus寄存器
    (void)registers;
    (void)count;
}
