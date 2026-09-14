/**
 * 4CP 已确认写入规则。
 *
 * 本文件只做前置条件判断，不访问串口、不改运行缓存。
 * 设备读回是实际状态，即使违反写入互斥规则也必须原样发布，不调用本策略纠正。
 * v1.22 起模块互斥联动（开新风→设备关超净；开超净→设备关新风/调湿；
 * 开调湿→设备关超净）由 4CP 设备端自动执行，屏只下发单条开关命令。
 */

#ifndef MODBUSCOMMANDPOLICY_H
#define MODBUSCOMMANDPOLICY_H

#include <cstdint>

namespace ModbusCommandPolicy {

constexpr uint16_t FRESH_SWITCH = 0x1001;
constexpr uint16_t PURE_SWITCH = 0x1002;
constexpr uint16_t HUMIDITY_SWITCH = 0x1003;
constexpr uint16_t HUMIDIFY_SWITCH = 0x1004;
constexpr uint16_t DEHUMIDIFY_SWITCH = 0x1005;
constexpr uint16_t LEAVE_HOME_SWITCH = 0x1006;
constexpr uint16_t FRESH_RUN_MODE = 0x1007;
constexpr uint16_t FAN_GEAR = 0x1008;
// v1.22：1006H 为一键离家开关。
// 风量档位 1008H 的写权限：1001H=1（新风模块开启）且 1007H ∈ {0,1,2,4}
// （内循环/混风/全热新风/旁通换气）；1007H=3（自动）、5（睡眠）时只读。
constexpr uint16_t MAX_RUN_MODE = 5;

struct FreshControlState {
    bool freshOn = false;
    uint16_t runMode = 0;
    uint16_t freshModeMaxGear = 6;
    uint16_t recirculationMaxGear = 6;
};

// 加湿(1004H)/除湿(1005H)开关的写前置状态：调湿模块(1003H)开启时
// 两者由设备内部控制，界面只读。
struct HumidityControlState {
    bool humidityModuleOn = false;
};

// 厂测寄存器（102BH/102CH/1038H-103EH）的写前置状态：
// 仅 1030H=100（厂测模式）时设备开放写权限。
struct FactoryControlState {
    bool factoryTestActive = false;
};

enum class Decision {
    Allow,
    InvalidAddress,
    InvalidValue,
    FreshModuleOff,
    RunModeGearLocked,
    HumidityModuleActive,
    FactoryModeRequired,
    ExceedsDeviceCapability
};

inline Decision validateFreshMode(
    const FreshControlState& state, uint16_t runMode)
{
    if (!state.freshOn) {
        return Decision::FreshModuleOff;
    }
    return runMode <= MAX_RUN_MODE ? Decision::Allow : Decision::InvalidValue;
}

inline Decision validateHumiditySwitch(
    const HumidityControlState& state, uint16_t address)
{
    if (address != HUMIDIFY_SWITCH && address != DEHUMIDIFY_SWITCH) {
        return Decision::InvalidAddress;
    }
    // 1003H 调湿模块开启时，1004H/1005H 由设备内部控制，只读
    if (state.humidityModuleOn) {
        return Decision::HumidityModuleActive;
    }
    return Decision::Allow;
}

// 厂测寄存器范围：102BH/102CH 高低压开关、1038H-103BH FAN1-4 风量设定、
// 103CH-103EH 阀门1-3 状态设定、1041H-1070H FAN1-4 内外循环各档风量标定值、
// 1071H-1076H 风阀1-3 方向/步数设定。仅厂测模式（1030H=100）时可写。
inline bool isFactoryWriteAddress(uint16_t address)
{
    return address == 0x102B || address == 0x102C
        || (address >= 0x1038 && address <= 0x103E)
        || (address >= 0x1041 && address <= 0x1076);
}

inline Decision validateFactoryWrite(
    const FactoryControlState& state, uint16_t address)
{
    if (!isFactoryWriteAddress(address)) {
        return Decision::InvalidAddress;
    }
    if (!state.factoryTestActive) {
        return Decision::FactoryModeRequired;
    }
    return Decision::Allow;
}

inline Decision validateFreshControl(
    const FreshControlState& state, uint16_t address, uint16_t value)
{
    if (address != FRESH_RUN_MODE
        && address != FAN_GEAR) {
        return Decision::InvalidAddress;
    }
    if (!state.freshOn) {
        return Decision::FreshModuleOff;
    }
    if (address == FRESH_RUN_MODE) {
        return value <= MAX_RUN_MODE ? Decision::Allow : Decision::InvalidValue;
    }

    // 1008H 风量档位：仅 1007H ∈ {0,1,2,4} 可写（白名单，与规格原文一致，
    // 防御 1007H 读回越界值时误放行）；3（自动）、5（睡眠）等其余模式只读
    const bool gearWritableMode = state.runMode == 0 || state.runMode == 1
        || state.runMode == 2 || state.runMode == 4;
    if (!gearWritableMode) {
        return Decision::RunModeGearLocked;
    }
    if (value > 6) {
        return Decision::InvalidValue;
    }

    // 内循环/混风（0/1）受内循环最大档约束，其余模式受新风最大档约束
    const bool recirculation = state.runMode == 0 || state.runMode == 1;
    const uint16_t maxGear = recirculation
        ? state.recirculationMaxGear : state.freshModeMaxGear;
    if (maxGear > 0 && value > maxGear) {
        return Decision::ExceedsDeviceCapability;
    }
    return Decision::Allow;
}

inline const char* decisionMessage(Decision decision)
{
    switch (decision) {
    case Decision::Allow:
        return "";
    case Decision::InvalidAddress:
        return "寄存器不属于已确认的新风控制范围";
    case Decision::InvalidValue:
        return "控制值超出协议范围";
    case Decision::FreshModuleOff:
        return "新风模块未开启，该控制项只读";
    case Decision::RunModeGearLocked:
        return "当前运行模式(1007H=3自动/5睡眠)下风量档位只读";
    case Decision::HumidityModuleActive:
        return "调湿模块开启(1003H=1)，加湿/除湿开关只读";
    case Decision::FactoryModeRequired:
        return "厂测模式未开启(1030H≠100)，该寄存器只读";
    case Decision::ExceedsDeviceCapability:
        return "风量档位超过设备当前模式的最大档位";
    }
    return "控制条件不满足";
}

} // namespace ModbusCommandPolicy

#endif // MODBUSCOMMANDPOLICY_H
