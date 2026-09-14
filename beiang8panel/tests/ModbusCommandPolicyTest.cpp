#include "modbuscommand/ModbusCommandPolicy.h"

#include <iostream>

namespace {

bool testFreshControlConditions()
{
    ModbusCommandPolicy::FreshControlState state;
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 2)
        != ModbusCommandPolicy::Decision::FreshModuleOff) {
        return false;
    }

    // v1.22：1007H=3（自动）/5（睡眠）时，风量档位只读
    state.freshOn = true;
    state.runMode = 3;
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 2)
        != ModbusCommandPolicy::Decision::RunModeGearLocked) {
        return false;
    }
    state.runMode = 5;
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 2)
        != ModbusCommandPolicy::Decision::RunModeGearLocked) {
        return false;
    }
    // 白名单防御：1007H 读回越界值（>5）同样拒写
    state.runMode = 6;
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 2)
        != ModbusCommandPolicy::Decision::RunModeGearLocked) {
        return false;
    }

    // 1007H ∈ {0,1,2,4} 可写（以4旁通/换气验证）
    state.runMode = 4;
    state.freshModeMaxGear = 3;
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 4)
        != ModbusCommandPolicy::Decision::ExceedsDeviceCapability) {
        return false;
    }
    if (ModbusCommandPolicy::validateFreshControl(
            state, ModbusCommandPolicy::FAN_GEAR, 3)
        != ModbusCommandPolicy::Decision::Allow) {
        return false;
    }
    // v1.22：运行模式取值0-5
    return ModbusCommandPolicy::validateFreshControl(
               state, ModbusCommandPolicy::FRESH_RUN_MODE, 5)
        == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFreshControl(
               state, ModbusCommandPolicy::FRESH_RUN_MODE, 6)
            == ModbusCommandPolicy::Decision::InvalidValue;
}

bool testFreshModeConditions()
{
    ModbusCommandPolicy::FreshControlState state;
    if (ModbusCommandPolicy::validateFreshMode(state, 0)
        != ModbusCommandPolicy::Decision::FreshModuleOff) {
        return false;
    }
    state.freshOn = true;
    return ModbusCommandPolicy::validateFreshMode(state, 3)
            == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFreshMode(state, 2)
            == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFreshMode(state, 6)
            == ModbusCommandPolicy::Decision::InvalidValue;
}

bool testHumiditySwitchConditions()
{
    ModbusCommandPolicy::HumidityControlState state;
    // 调湿模块关闭：加湿/除湿开关可写
    if (ModbusCommandPolicy::validateHumiditySwitch(
            state, ModbusCommandPolicy::HUMIDIFY_SWITCH)
        != ModbusCommandPolicy::Decision::Allow
        || ModbusCommandPolicy::validateHumiditySwitch(
            state, ModbusCommandPolicy::DEHUMIDIFY_SWITCH)
        != ModbusCommandPolicy::Decision::Allow) {
        return false;
    }
    // 调湿模块开启：1004H/1005H 只读
    state.humidityModuleOn = true;
    return ModbusCommandPolicy::validateHumiditySwitch(
               state, ModbusCommandPolicy::HUMIDIFY_SWITCH)
            == ModbusCommandPolicy::Decision::HumidityModuleActive
        && ModbusCommandPolicy::validateHumiditySwitch(
               state, ModbusCommandPolicy::DEHUMIDIFY_SWITCH)
            == ModbusCommandPolicy::Decision::HumidityModuleActive
        && ModbusCommandPolicy::validateHumiditySwitch(
               state, ModbusCommandPolicy::FRESH_SWITCH)
            == ModbusCommandPolicy::Decision::InvalidAddress;
}

bool testFactoryWriteConditions()
{
    ModbusCommandPolicy::FactoryControlState state;
    // 非厂测模式：厂测寄存器只读
    if (ModbusCommandPolicy::validateFactoryWrite(state, 0x102B)
        != ModbusCommandPolicy::Decision::FactoryModeRequired
        || ModbusCommandPolicy::validateFactoryWrite(state, 0x1038)
        != ModbusCommandPolicy::Decision::FactoryModeRequired
        || ModbusCommandPolicy::validateFactoryWrite(state, 0x103E)
        != ModbusCommandPolicy::Decision::FactoryModeRequired) {
        return false;
    }
    // 风量标定区（1041H-1070H）与风阀参数（1071H-1076H）同受厂测锁
    if (ModbusCommandPolicy::validateFactoryWrite(state, 0x1041)
        != ModbusCommandPolicy::Decision::FactoryModeRequired
        || ModbusCommandPolicy::validateFactoryWrite(state, 0x1070)
        != ModbusCommandPolicy::Decision::FactoryModeRequired
        || ModbusCommandPolicy::validateFactoryWrite(state, 0x1071)
        != ModbusCommandPolicy::Decision::FactoryModeRequired
        || ModbusCommandPolicy::validateFactoryWrite(state, 0x1076)
        != ModbusCommandPolicy::Decision::FactoryModeRequired) {
        return false;
    }
    // 厂测模式开启：可写
    state.factoryTestActive = true;
    return ModbusCommandPolicy::validateFactoryWrite(state, 0x102B)
            == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFactoryWrite(state, 0x103C)
            == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFactoryWrite(state, 0x1047)
            == ModbusCommandPolicy::Decision::Allow
        && ModbusCommandPolicy::validateFactoryWrite(state, 0x1037)
            == ModbusCommandPolicy::Decision::InvalidAddress;
}

} // namespace

int main()
{
    if (!testFreshControlConditions()
        || !testFreshModeConditions() || !testHumiditySwitchConditions()
        || !testFactoryWriteConditions()) {
        std::cerr << "Modbus command policy tests failed" << std::endl;
        return 1;
    }
    std::cout << "Modbus command policy tests passed" << std::endl;
    return 0;
}
