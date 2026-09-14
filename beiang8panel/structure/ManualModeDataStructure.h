/**
 * 手动模式数据结构类
 */

#ifndef MANUALMODEDATASTRUCTURE_H
#define MANUALMODEDATASTRUCTURE_H

#include <string>
#include "common/GlobalDefine.h"

// 手动模式控制参数
struct ManualModeParams {
    bool powerOn;              // 电源开关
    int fanSpeedLevel;         // 风机档位 (1-5)
    bool uvLightOn;            // UV灯开关
    bool ionizerOn;            // 负离子开关
    int targetHumidity;        // 目标湿度 (%)
    bool humidifierOn;         // 加湿器开关

    ManualModeParams()
        : powerOn(false)
        , fanSpeedLevel(1)
        , uvLightOn(false)
        , ionizerOn(false)
        , targetHumidity(50)
        , humidifierOn(false)
    {}
};

// 手动模式数据结构类
class ManualModeDataStructure {
public:
    ManualModeDataStructure();
    ~ManualModeDataStructure() = default;

    // 控制参数
    ManualModeParams& getParams() { return m_params; }
    const ManualModeParams& getParams() const { return m_params; }

    // 数据序列化
    std::string toJson() const;
    bool fromJson(const std::string& json);

    // Modbus寄存器映射
    void readFromModbusRegisters(const uint16_t* registers, size_t count);
    void writeToModbusRegisters(uint16_t* registers, size_t count) const;

private:
    ManualModeParams m_params;
};

#endif // MANUALMODEDATASTRUCTURE_H
