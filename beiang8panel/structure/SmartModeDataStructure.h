/**
 * 智能模式数据结构类
 */

#ifndef SMARTMODEDATASTRUCTURE_H
#define SMARTMODEDATASTRUCTURE_H

#include <string>
#include "common/GlobalDefine.h"

// 智能模式场景类型
enum class SmartScene {
    Auto = 0,           // 自动模式
    Sleep = 1,          // 睡眠模式
    Away = 2,           // 离家模式
    Home = 3,           // 在家模式
    Custom = 99         // 自定义模式
};

// 智能模式参数
struct SmartModeParams {
    SmartScene scene;             // 当前场景
    bool autoAdjustFan;           // 自动调节风机
    bool autoAdjustHumidity;      // 自动调节湿度
    float targetPM25;             // 目标PM2.5 (μg/m³)
    float targetCO2;              // 目标CO2 (ppm)
    int sleepTimeStart;           // 睡眠开始时间 (分钟，从0:00开始)
    int sleepTimeEnd;             // 睡眠结束时间 (分钟)

    SmartModeParams()
        : scene(SmartScene::Auto)
        , autoAdjustFan(true)
        , autoAdjustHumidity(false)
        , targetPM25(35.0f)
        , targetCO2(1000.0f)
        , sleepTimeStart(1320)    // 22:00
        , sleepTimeEnd(420)       // 07:00
    {}
};

// 智能模式数据结构类
class SmartModeDataStructure {
public:
    SmartModeDataStructure();
    ~SmartModeDataStructure() = default;

    // 控制参数
    SmartModeParams& getParams() { return m_params; }
    const SmartModeParams& getParams() const { return m_params; }

    // 数据序列化
    std::string toJson() const;
    bool fromJson(const std::string& json);

    // Modbus寄存器映射
    void readFromModbusRegisters(const uint16_t* registers, size_t count);
    void writeToModbusRegisters(uint16_t* registers, size_t count) const;

private:
    SmartModeParams m_params;
};

#endif // SMARTMODEDATASTRUCTURE_H
