#include "DeviceSimulator.h"
#include "Logger.h"
#include <algorithm>
#include <random>
#include <ctime>
#include <iostream>
#include <cmath>

namespace _4CP {

ModbusRegisterDevice::ModbusRegisterDevice(
    uint8_t deviceAddress,
    uint32_t randomSeed)
    : deviceAddress_(deviceAddress)
    , rng_(randomSeed == 0
            ? static_cast<std::mt19937::result_type>(std::time(nullptr))
            : static_cast<std::mt19937::result_type>(randomSeed))
    , tempDist_(15.0f, 35.0f)        // 温度 15-35°C
    , humidityDist_(30.0f, 80.0f)    // 湿度 30-80%
    , pm25Dist_(10.0f, 150.0f)       // PM2.5 10-150
    , co2Dist_(400.0f, 1200.0f)     // CO2 400-1200ppm
{
    InitializeRegisters();
}

void ModbusRegisterDevice::InitializeRegisters() {
    std::lock_guard<std::mutex> lock(registerMutex_);

    registers_.clear();
    discreteWords_.fill(0);

    // 模拟器默认配置与旧版本保持一致：具备加湿、除湿、旁通/换气模式和IEF。
    // 其它已定义能力位同样保留在统一镜像中，可由测试或后续数据调度器设置。
    bit_word_set(discreteWords_.data(), DI_BIT_HAS_HUMIDIFY_MODULE, 1);
    bit_word_set(discreteWords_.data(), DI_BIT_HAS_DEHUMIDIFY, 1);
    bit_word_set(discreteWords_.data(), DI_BIT_HAS_BYPASS_MODE, 1);
    bit_word_set(discreteWords_.data(), DI_BIT_HAS_IEF, 1);

    // ========== 保持寄存器 (1000H-1076H) - 03/06/10H功能码 ==========

    // 总开关和模块开关 (1000H-1003H)
    registers_[HR_TOTAL_SWITCH] = 0x0000;           // 总开关：默认关闭
    registers_[HR_FRESH_MODULE_SWITCH] = 0x0000;    // 新风模块开关：默认关闭
    registers_[HR_CLEAN_MODE_SWITCH] = 0x0000;      // 超净模式开关：默认关闭
    registers_[HR_HUMIDITY_MODULE_SWITCH] = 0x0000; // 调湿模块开关：默认关闭

    // 加湿除湿开关 (1004H-1005H)
    registers_[HR_HUMIDIFY_SWITCH] = 0x0000;        // 加湿开关：默认关闭
    registers_[HR_DEHUMIDIFY_SWITCH] = 0x0000;      // 除湿开关：默认关闭

    // 新风模块控制 (1006H-1008H)
    registers_[HR_AWAY_HOME_SWITCH] = 0x0000;       // 一键离家开关：默认关闭
    registers_[HR_FRESH_RUN_MODE] = 0x0002;         // 新风运行模式：默认全热新风/节能新风
    registers_[HR_FAN_GEAR] = 0x0000;               // 风量档位：默认0

    // 预留风量档位与整机运行模式 (1009H-100AH)
    registers_[HR_EXHAUST_FAN_GEAR] = 0x0000;        // 排风风量档位：默认0
    registers_[HR_UNIT_RUN_MODE] = 0x0000;           // 整机运行模式：默认无

    // 无极风量控制 (100BH-100EH)
    registers_[HR_STEPLESS_FAN_CTRL] = 0x0000;       // 无极风量控制：关闭
    registers_[HR_FRESH_AIR_DUTY] = 0x0000;          // 新风风量占空比：0%
    registers_[HR_EXHAUST_AIR_DUTY] = 0x0000;        // 排风风量占空比：0%
    registers_[HR_BOOST_AIR_DUTY] = 0x0000;          // 增压风量占空比：0%

    // 温湿度和目标设定 (100FH-1010H)
    registers_[HR_TARGET_HUMIDITY] = 0x0032;        // 目标湿度：50 (30-70范围)
    registers_[HR_TARGET_TEMP] = 0x00F0;             // 目标温度：240 (24°C×10，范围160-310)

    // 等离子和IEF (1011H-1012H)
    registers_[HR_PLASMA_STERILIZE] = 0x0000;        // 等离子消毒开关：关闭
    registers_[HR_IEF_SWITCH] = 0x0000;              // IEF开关：关闭

    // 电辅热和加湿强度 (1013H-1014H)
    registers_[HR_ELECTRIC_HEATER] = 0x0000;         // 电辅热选择：关闭
    registers_[HR_HUMIDIFY_INTENSITY] = 0x0001;      // 加湿/除湿强度：中

    // SA风机比例设定 (1015H)
    registers_[HR_SA_FAN_RATIO] = 0x0012;             // SA风量比例：1.8×10=18

    // 预留 (1016H-101AH)
    registers_[HR_RESERVED_1016] = 0x0000;
    registers_[HR_RESERVED_1017] = 0x0000;
    registers_[HR_RESERVED_1018] = 0x0000;
    registers_[HR_RESERVED_1019] = 0x0000;
    registers_[HR_RESERVED_101A] = 0x0000;

    // RTC 时间设置 (101BH-101FH) - 10字节 Set RTC 结构体
    registers_[HR_RTC_YEAR] = 2026;                              // 年
    registers_[HR_RTC_MONTH_DAY] = (8 << 8) | 31;                // 月(高)|日(低)
    registers_[HR_RTC_HOUR_MINUTE] = (12 << 8) | 0;              // 时(高)|分(低)，24小时制
    registers_[HR_RTC_SECOND_WEEK] = (0 << 8) | 1;               // 秒(高)|周(低)，2026-08-31为周一
    registers_[HR_RTC_FORMAT_RES] = (0 << 8) | 0;                // format(高):0=24小时制

    // 关机延时和加湿控制 (1020H-1024H)
    registers_[HR_OFF_DELAY_FAN] = 0x0000;            // 关机后延时关风机时间：0分钟
    registers_[HR_HUMIDIFY_PUMP_ON] = 0x000A;         // 加湿循环泵开时间：10秒
    registers_[HR_HUMIDIFY_PUMP_OFF] = 0x0014;        // 加湿循环泵关时间：20秒
    registers_[HR_HUMIDIFY_DRAIN_ON] = 0x0005;        // 加湿排水开时间：5秒
    registers_[HR_DEVICE_ADDR] = deviceAddress_;     // 与当前模拟进程的从站地址一致

    // 关机状态下空气品质检测 (1025H-1027H)
    registers_[HR_OFF_AQ_DETECT_SWITCH] = 0x0001;    // 关机状态下空气品质检测开关：开启
    registers_[HR_OFF_AQ_DETECT_INTERVAL] = 0x003C;   // 空气品质检测间隔：60分钟
    registers_[HR_OFF_AQ_DETECT_RUNTIME] = 0x0002;    // 空气品质检测运行：2分钟

    // 压缩机控制 (1028H-102AH)
    registers_[HR_COMPRESSOR_EEV] = 0x0000;           // 压缩机电子膨胀阀开度：0
    registers_[HR_COMPRESSOR_FREQ_SET] = 0x0000;      // 压缩机运行频率设定值：0
    registers_[HR_COMPRESSOR_FREQ_MAX] = 0x0000;      // 压缩机频率上限设定值：0

    // 高低压开关 (102BH-102CH) - 仅厂测模式可写
    registers_[HR_HIGH_PRESSURE_SWITCH] = 0x0000;    // 高压开关：关
    registers_[HR_LOW_PRESSURE_SWITCH] = 0x0000;     // 低压开关：关

    // 预留 (102DH-102FH)
    registers_[HR_RESERVED_102D] = 0x0000;
    registers_[HR_RESERVED_102E] = 0x0000;
    registers_[HR_RESERVED_102F] = 0x0000;

    // 厂测模式 (1030H)
    registers_[HR_FACTORY_TEST_MODE] = 0x0000;        // 厂测模式：正常运行模式

    // 滤网和保养剩余时间 (1031H-1036H)
    registers_[HR_FILTER1_REMAINING] = 0x0DD0;       // 初效滤网1剩余时间：3528小时
    registers_[HR_FILTER2_REMAINING] = 0x0DD0;       // 中效滤网2剩余时间：3528小时
    registers_[HR_FILTER3_REMAINING] = 0x0DD0;       // 高效滤网3剩余时间：3528小时
    registers_[HR_HUMIDIFY_MODULE_REMAINING] = 0x0DD0; // 加湿模块剩余时间：3528小时
    registers_[HR_IEF_CLEAN_REMAINING] = 0x0DD0;      // IEF需清洗剩余时间：3528小时
    registers_[HR_MAINTENANCE_REMAINING] = 0x00B4;    // 整机保养剩余时间：180天

    // 预留 (1037H)
    registers_[HR_RESERVED_1037] = 0x0000;

    // 当前风机风量设定值 (1038H-103BH) - 仅厂测模式可设定
    registers_[HR_FAN1_FLOW_SET] = 0x0000;
    registers_[HR_FAN2_FLOW_SET] = 0x0000;
    registers_[HR_FAN3_FLOW_SET] = 0x0000;
    registers_[HR_FAN4_FLOW_SET] = 0x0000;

    // 阀门状态设定 (103CH-103EH) - 仅厂测模式可设定
    registers_[HR_VALVE1_STATUS_SET] = 0x0000;       // 阀门1状态：关闭
    registers_[HR_VALVE2_STATUS_SET] = 0x0000;       // 阀门2状态：关闭
    registers_[HR_VALVE3_STATUS_SET] = 0x0000;       // 阀门3状态：关闭

    // 风机累计运转时间清除 (103FH)
    registers_[HR_CLEAR_ALL_FAN_TIME] = 0x0000;       // 清除所有风机累计运转时间

    // 恢复出厂 (1040H)
    registers_[HR_FACTORY_RESET] = 0x0000;           // 恢复出厂：默认不执行

    // FAN1-4 外循环/内循环 1-6档风量设定值 (1041H-1070H)
    // 每风机12个槽位：0-5为外循环1-6档，6-11为内循环1-6档；
    // 每档默认风量沿用 v1.21 输入区只读值：1-6档对应 300/600/900/1200/1500/1800。
    for (uint16_t slot = 0;
         slot < HR_FAN_FLOW_SET_LAST - HR_FAN_FLOW_SET_FIRST + 1u;
         ++slot) {
        registers_[static_cast<uint16_t>(HR_FAN_FLOW_SET_FIRST + slot)] =
            static_cast<uint16_t>(300u * (slot % 6u + 1u));
    }

    // 风阀方向和步数设定 (1071H-1076H)
    registers_[HR_DAMPER1_DIR_SET] = 0x0000;         // 风阀1方向：0
    registers_[HR_DAMPER2_DIR_SET] = 0x0000;
    registers_[HR_DAMPER3_DIR_SET] = 0x0000;
    registers_[HR_DAMPER1_STEPS_SET] = 0x0000;       // 风阀1运行步数：0
    registers_[HR_DAMPER2_STEPS_SET] = 0x0000;
    registers_[HR_DAMPER3_STEPS_SET] = 0x0000;

    // ========== 输入寄存器 (2000H-203BH) - 04H功能码 (只读) ==========

    // 设备基本信息 (2000H-2004H)
    registers_[IR_FACTORY_ID] = 0x4241;            // 工厂标志：'BA'
    registers_[IR_MODEL] = 0x0000;                 // 机型：4CP (0)
    registers_[IR_VERSION] = 0x0122;                // 版本：1.22 (0122，除以100代表1.22)
    registers_[IR_FRESH_MODE_MAX_GEAR] = 0x0003;   // 新风模式风量最大档位：3
    registers_[IR_MIX_MODE_MAX_GEAR] = 0x0005;      // 内循环/混风模式风量最大档位：5

    // 风机档位 (2005H-2008H)
    registers_[IR_FAN1_GEAR] = 0x0000;             // FAN1档位：0
    registers_[IR_FAN2_GEAR] = 0x0000;             // FAN2档位：0
    registers_[IR_FAN3_GEAR] = 0x0000;             // FAN3档位：0
    registers_[IR_FAN4_GEAR] = 0x0000;             // FAN4档位：0

    // 风机实时转速 (2009H-200CH)
    registers_[IR_FAN1_RPM] = 0x0000;               // FAN1实时rpm：0 (风机关闭)
    registers_[IR_FAN2_RPM] = 0x0000;
    registers_[IR_FAN3_RPM] = 0x0000;
    registers_[IR_FAN4_RPM] = 0x0000;

    // RA1 传感器数据 (200DH-2010H)
    float temp = 25.0f;  // 默认25°C
    registers_[IR_RA1_TEMP] = static_cast<uint16_t>(temp * 10);    // RA1温度：实际温度*10 = 250
    registers_[IR_RA1_HUMIDITY] = 50;                             // RA1湿度：50%
    registers_[IR_RA1_PM25] = 50;                                 // RA1 PM2.5
    registers_[IR_RA1_CO2] = 600;                                 // RA1 CO2

    // OA 传感器数据 (2011H-2014H)
    registers_[IR_OA_TEMP] = static_cast<uint16_t>(temp * 10);     // OA温度：250
    registers_[IR_OA_HUMIDITY] = 50;                               // OA湿度
    registers_[IR_OA_PM25] = 50;                                   // OA PM2.5
    registers_[IR_OA_CO2] = 600;                                   // OA CO2

    // SA 传感器数据 (2015H-201AH)
    registers_[IR_SA_TEMP] = static_cast<uint16_t>(temp * 10);     // SA温度：250
    registers_[IR_SA_HUMIDITY] = 50;                               // SA湿度
    registers_[IR_SA_PM25] = 50;                                   // SA PM2.5
    registers_[IR_SA_CO2] = 600;                                   // SA CO2
    registers_[IR_TVOC] = 100;                                     // TVOC
    registers_[IR_FORMALDEHYDE] = 20;                             // 甲醛

    // 压缩机和电辅热状态 (201BH-201CH)
    registers_[IR_COMPRESSOR_FREQ] = 0x0000;        // 压缩机运行频率：0Hz
    registers_[IR_HEATER_STATUS] = 0x0000;         // 电辅热状态：关闭

    // 自动模式内外循环显示与进/出风口、压力数据 (201DH-2023H)
    registers_[IR_AUTO_CIRCULATION_DISPLAY] = 0x0000; // 自动模式内外循环显示：内循环
    registers_[IR_INTAKE_TEMP] = static_cast<uint16_t>(temp * 10);  // 进风口温度：250
    registers_[IR_INTAKE_HUMIDITY] = 50;                // 进风口湿度
    registers_[IR_OUTLET_TEMP] = static_cast<uint16_t>(temp * 10);  // 出风口温度(预留)：250
    registers_[IR_OUTLET_HUMIDITY] = 50;                // 出风口湿度(预留)
    registers_[IR_HIGH_PRESSURE] = 0x0000;              // 高压压力值：0 bar
    registers_[IR_LOW_PRESSURE] = 0x0000;               // 低压压力值：0 bar

    // 加湿水位浮子状态 (2024H-2025H)
    registers_[IR_HUMIDIFY_WATER_FLOAT] = 0x0000;      // 加湿进水水位浮子状态
    registers_[IR_HUMIDIFY_DRAIN_FLOAT] = 0x0000;      // 加湿排水水位浮子状态

    // 系统和风机累计运行时间 (2026H-202AH)
    registers_[IR_SYSTEM_RUNTIME_DAYS] = 0x0000;    // 系统运行时间：0天
    registers_[IR_FAN1_RUNTIME] = 0x0000;             // FAN1累计运转时间：0小时
    registers_[IR_FAN2_RUNTIME] = 0x0000;
    registers_[IR_FAN3_RUNTIME] = 0x0000;
    registers_[IR_FAN4_RUNTIME] = 0x0000;

    // 压缩机温度和电压检测 (202BH-202FH)
    registers_[IR_COMP_DISCHARGE_TEMP] = 0x0000;    // 压缩机排气温度：0
    registers_[IR_COMP_SUCTION_TEMP] = 0x0000;      // 压缩机吸气温度：0
    registers_[IR_EVAPORATOR_TEMP] = 0x0000;        // 蒸发器盘管温度：0
    registers_[IR_RESERVED_TEMP] = 0x0000;          // 预留温度：0
    registers_[IR_AC_VOLTAGE] = 0x0000;             // 交流电压检测值：待定，保持0

    // 主控板版本时间字符串 (2030H-203BH) - Char[24], 不满填0x00
    {
        const char versionString[] = "SIM v1.22 20260831";
        uint16_t stringRegister = IR_MAINBOARD_STRING_FIRST;
        for (size_t index = 0; index < sizeof(versionString) - 1u;
             index += 2u, ++stringRegister) {
            const uint16_t highByte =
                static_cast<uint8_t>(versionString[index]);
            const uint16_t lowByte =
                (index + 1u < sizeof(versionString) - 1u)
                    ? static_cast<uint8_t>(versionString[index + 1u])
                    : 0x00u;
            registers_[stringRegister] =
                static_cast<uint16_t>((highByte << 8) | lowByte);
        }
        for (; stringRegister <= IR_MAINBOARD_STRING_LAST; ++stringRegister) {
            registers_[stringRegister] = 0x0000;
        }
    }

    LOG("[DEVICE] Registers initialized according to v1.22 protocol");
}

std::vector<uint8_t> ModbusRegisterDevice::ProcessFrame(const ModbusFrame& frame) {
    // 检查设备地址
    if (frame.deviceAddress != deviceAddress_ &&
        frame.deviceAddress != ADDR_BROADCAST) {
        // 不是发给这个设备的，忽略
        return {};
    }

    LOG("[DEVICE] Processing frame for FC=0x"
              << std::hex << static_cast<int>(frame.functionCode)
              << std::dec);

    // 根据功能码分发
    switch (frame.functionCode) {
        case static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS):
            return HandleReadHoldingRegisters(frame);

        case static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS):
            // 04H功能码 - 读输入寄存器
            return HandleReadInputRegisters(frame);

        case static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS):
            // 02H功能码 - 读离散输入
            return HandleReadDiscreteInputs(frame);

        case static_cast<uint8_t>(ModbusFunctionCode::WRITE_SINGLE_REGISTER):
            return HandleWriteSingleRegister(frame);

        case static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS):
            return HandleWriteMultipleRegisters(frame);

        default:
            // 不支持的功能码
            LOG("[DEVICE] Unsupported FC: 0x"
                      << std::hex << static_cast<int>(frame.functionCode)
                      << std::dec);
            return ModbusProtocol::BuildExceptionResponse(
                deviceAddress_,
                frame.functionCode,
                ModbusExceptionCode::ILLEGAL_FUNCTION
            );
    }
}

std::vector<uint8_t> ModbusRegisterDevice::HandleReadHoldingRegisters(const ModbusFrame& frame) {
    // 解析请求: [起始地址高][起始地址低][数量高][数量低]
    if (frame.data.size() < 4) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    uint16_t startAddress = ReadBigEndianUint16(&frame.data[0]);
    uint16_t registerCount = ReadBigEndianUint16(&frame.data[2]);

    LOG("[DEVICE] ReadHoldingRegisters: Start=0x" << std::hex << startAddress
              << ", Count=" << std::dec << registerCount);

    // 验证寄存器数量
    if (registerCount == 0 || registerCount > 50) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress) + registerCount - 1u;
    if (startAddress < HR_TOTAL_SWITCH || endAddress > HR_LAST_REGISTER) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }

    // 读取寄存器值
    std::vector<uint16_t> values;
    std::lock_guard<std::mutex> lock(registerMutex_);

    for (uint16_t i = 0; i < registerCount; i++) {
        uint16_t regAddr = startAddress + i;
        auto it = registers_.find(regAddr);

        if (it != registers_.end()) {
            values.push_back(it->second);
            LOG("[DEVICE]   Reg[0x" << std::hex << regAddr
                      << "] = 0x" << it->second << std::dec);
        } else {
            // 寄存器不存在
            LOG("[DEVICE]   Reg[0x" << std::hex << regAddr
                      << "] not found" << std::dec);
            return ModbusProtocol::BuildExceptionResponse(
                deviceAddress_,
                frame.functionCode,
                ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
            );
        }
    }

    return ModbusProtocol::BuildReadHoldingRegistersResponse(deviceAddress_, values);
}

// v1.22: 处理04H - 读输入寄存器
std::vector<uint8_t> ModbusRegisterDevice::HandleReadInputRegisters(const ModbusFrame& frame) {
    // 解析请求: [起始地址高][起始地址低][数量高][数量低]
    if (frame.data.size() < 4) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    uint16_t startAddress = ReadBigEndianUint16(&frame.data[0]);
    uint16_t registerCount = ReadBigEndianUint16(&frame.data[2]);

    LOG("[DEVICE] ReadInputRegisters: Start=0x" << std::hex << startAddress
              << ", Count=" << std::dec << registerCount);

    // 验证寄存器数量
    if (registerCount == 0 || registerCount > 50) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress) + registerCount - 1u;
    if (startAddress < IR_FACTORY_ID || endAddress > IR_LAST_REGISTER) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }

    // 读取输入寄存器值 (2000H-205BH区域)
    std::vector<uint16_t> values;
    std::lock_guard<std::mutex> lock(registerMutex_);

    for (uint16_t i = 0; i < registerCount; i++) {
        uint16_t regAddr = startAddress + i;
        auto it = registers_.find(regAddr);

        if (it != registers_.end()) {
            values.push_back(it->second);
            LOG("[DEVICE]   InputReg[0x" << std::hex << regAddr
                      << "] = 0x" << it->second << std::dec);
        } else {
            // 寄存器不存在
            LOG("[DEVICE]   InputReg[0x" << std::hex << regAddr
                      << "] not found" << std::dec);
            return ModbusProtocol::BuildExceptionResponse(
                deviceAddress_,
                frame.functionCode,
                ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
            );
        }
    }

    return ModbusProtocol::BuildReadInputRegistersResponse(deviceAddress_, values);
}

// v1.22: 处理02H - 读离散输入
std::vector<uint8_t> ModbusRegisterDevice::HandleReadDiscreteInputs(const ModbusFrame& frame) {
    // 解析请求: [起始地址高][起始地址低][数量高][数量低]
    if (frame.data.size() < 4) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    uint16_t startAddress = ReadBigEndianUint16(&frame.data[0]);
    uint16_t inputCount = ReadBigEndianUint16(&frame.data[2]);

    LOG("[DEVICE] ReadDiscreteInputs: Start=0x" << std::hex << startAddress
              << ", Count=" << std::dec << inputCount);

    // 验证输入数量
    if (inputCount == 0 || inputCount > 2000) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    if (startAddress < DI_CAPABILITY_START) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }
    const uint32_t bitOffset =
        static_cast<uint32_t>(startAddress) - DI_CAPABILITY_START;
    if (bitOffset + inputCount > DISCRETE_BIT_COUNT) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }

    // 计算字节数
    uint8_t byteCount = static_cast<uint8_t>((inputCount + 7u) / 8u);

    // 读取离散输入值
    std::vector<uint8_t> values(byteCount, 0);
    std::lock_guard<std::mutex> lock(registerMutex_);

    // Modbus 02H 在线上按字节打包；内部始终只读统一 uint16_t 位镜像。
    for (uint16_t i = 0; i < inputCount; ++i) {
        if (bit_word_get(discreteWords_.data(),
                         static_cast<uint16_t>(bitOffset + i)) != 0) {
            values[i / 8u] = static_cast<uint8_t>(
                values[i / 8u] | static_cast<uint8_t>(1u << (i & 7u)));
        }
    }

    return ModbusProtocol::BuildReadDiscreteInputsResponse(deviceAddress_, values);
}

std::vector<uint8_t> ModbusRegisterDevice::HandleWriteSingleRegister(const ModbusFrame& frame) {
    // 解析请求: [寄存器地址高][寄存器地址低][值高][值低]
    if (frame.data.size() < 4) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    uint16_t registerAddress = ReadBigEndianUint16(&frame.data[0]);
    uint16_t registerValue = ReadBigEndianUint16(&frame.data[2]);

    LOG("[DEVICE] WriteSingle: Reg=0x" << std::hex << registerAddress
              << ", Value=0x" << registerValue << std::dec);

    if (registerAddress < HR_TOTAL_SWITCH || registerAddress > HR_LAST_REGISTER) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }

    std::lock_guard<std::mutex> lock(registerMutex_);

    // 检查寄存器是否存在
    auto it = registers_.find(registerAddress);
    if (it == registers_.end()) {
        LOG("[DEVICE] Register 0x" << std::hex << registerAddress
                  << " not found" << std::dec);
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
        );
    }

    // 检查寄存器是否可写
    if (!RegisterAccessChecker::IsWritable(registerAddress)) {
        LOG("[DEVICE] Register 0x" << std::hex << registerAddress
                  << " is read-only" << std::dec);
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
        );
    }

    if (!ValidateHoldingWriteLocked(registerAddress, 1, &registerValue)) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE);
    }

    // 写入寄存器
    it->second = registerValue;
    ApplyModuleInterlockLocked(registerAddress, 1);

    LOG("[DEVICE] Written: Reg[0x" << std::hex << registerAddress
              << "] = 0x" << registerValue << std::dec);

    // 返回响应 (与请求相同)
    return ModbusProtocol::BuildWriteSingleRegisterResponse(
        deviceAddress_, registerAddress, registerValue);
}

std::vector<uint8_t> ModbusRegisterDevice::HandleWriteMultipleRegisters(const ModbusFrame& frame) {
    // 解析请求: [起始地址高][起始地址低][数量高][数量低][字节数][数据...]
    if (frame.data.size() < 5) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    uint16_t startAddress = ReadBigEndianUint16(&frame.data[0]);
    uint16_t registerCount = ReadBigEndianUint16(&frame.data[2]);
    uint8_t byteCount = frame.data[4];

    LOG("[DEVICE] WriteMultiple: Start=0x" << std::hex << startAddress
              << ", Count=" << std::dec << registerCount
              << ", Bytes=" << static_cast<int>(byteCount));

    // 项目约束：单条 10H 最多写 50 个寄存器。
    if (registerCount == 0 || registerCount > 50 ||
        byteCount != registerCount * 2u) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    // 验证数据长度
    if (frame.data.size() < static_cast<size_t>(5 + byteCount)) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE
        );
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress) + registerCount - 1u;
    if (startAddress < HR_TOTAL_SWITCH || endAddress > HR_LAST_REGISTER) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_, frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
    }

    // 先验证整段，再统一写入，避免非法请求造成部分寄存器已修改。
    std::lock_guard<std::mutex> lock(registerMutex_);

    std::vector<uint16_t> values(registerCount);
    for (uint16_t i = 0; i < registerCount; i++) {
        uint16_t regAddr = startAddress + i;
        auto it = registers_.find(regAddr);
        if (it == registers_.end()) {
            LOG("[DEVICE] Register 0x" << std::hex << regAddr
                      << " not found" << std::dec);
            return ModbusProtocol::BuildExceptionResponse(
                deviceAddress_,
                frame.functionCode,
                ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
            );
        }

        // 检查寄存器是否可写
        if (!RegisterAccessChecker::IsWritable(regAddr)) {
            LOG("[DEVICE] Register 0x" << std::hex << regAddr
                      << " is read-only" << std::dec);
            return ModbusProtocol::BuildExceptionResponse(
                deviceAddress_,
                frame.functionCode,
                ModbusExceptionCode::ILLEGAL_DATA_ADDRESS
            );
        }
        values[i] = ReadBigEndianUint16(&frame.data[5 + i * 2]);
    }

    if (!ValidateHoldingWriteLocked(
            startAddress, registerCount, values.data())) {
        return ModbusProtocol::BuildExceptionResponse(
            deviceAddress_,
            frame.functionCode,
            ModbusExceptionCode::ILLEGAL_DATA_VALUE);
    }

    for (uint16_t i = 0; i < registerCount; i++) {
        const uint16_t regAddr = startAddress + i;
        const uint16_t value = values[i];
        registers_[regAddr] = value;
        LOG("[DEVICE]   Written: Reg[0x" << std::hex << regAddr
                  << "] = 0x" << value << std::dec);
    }
    ApplyModuleInterlockLocked(startAddress, registerCount);

    return ModbusProtocol::BuildWriteMultipleRegistersResponse(
        deviceAddress_, startAddress, registerCount);
}

void ModbusRegisterDevice::UpdateSimulation() {
    std::lock_guard<std::mutex> lock(registerMutex_);

    // 生成新的传感器数据
    GenerateSensorData();

    // 故障/维护数据变化比传感器慢，便于三端联调时观察“出现、保持、消失”。
    if (++alertUpdateCounter_ >= 10) {
        UpdateAlertSimulation();
        alertUpdateCounter_ = 0;
    }
    // 更新运行时间 (每次调用增加1秒)
    // 这里简化为每次增加一点，实际使用中应该计时
    registers_[IR_FAN1_RUNTIME]++;
    registers_[IR_FAN2_RUNTIME]++;
    registers_[IR_FAN3_RUNTIME]++;
    registers_[IR_FAN4_RUNTIME]++;

    // 系统运行时间增加（这里简化为每次调用增加1秒，实际应该转换为天）
    // 3600次调用 = 1小时，86400次调用 = 1天
    if (++runtimeCounter_ >= 86400) {
        registers_[IR_SYSTEM_RUNTIME_DAYS]++;
        runtimeCounter_ = 0;
    }

    // 根据总开关状态更新风机档位
    if (registers_[HR_TOTAL_SWITCH] == 1) {
        // 设备开启，根据风量档位设置
        uint16_t fanGear = registers_[HR_FAN_GEAR];
        if (fanGear > 6) fanGear = 6;
        registers_[IR_FAN1_GEAR] = fanGear;
        registers_[IR_FAN2_GEAR] = fanGear;
        registers_[IR_FAN3_GEAR] = fanGear;
        registers_[IR_FAN4_GEAR] = fanGear;
    } else {
        // 设备关闭
        registers_[IR_FAN1_GEAR] = 0;
        registers_[IR_FAN2_GEAR] = 0;
        registers_[IR_FAN3_GEAR] = 0;
        registers_[IR_FAN4_GEAR] = 0;
    }
}

uint8_t ModbusRegisterDevice::GetDiscreteInput(uint16_t bit) const {
    std::lock_guard<std::mutex> lock(registerMutex_);
    if (bit >= DISCRETE_BIT_COUNT) {
        return 0;
    }
    return bit_word_get(discreteWords_.data(), bit);
}

bool ModbusRegisterDevice::SetDiscreteInput(uint16_t bit, bool value) {
    std::lock_guard<std::mutex> lock(registerMutex_);
    if (bit >= DISCRETE_BIT_COUNT) {
        return false;
    }
    bit_word_set(discreteWords_.data(), bit, value ? 1 : 0);
    return true;
}

void ModbusRegisterDevice::CopyDataImage(
    uint16_t* holdingRegisters,
    uint16_t* inputRegisters,
    uint8_t* discreteInputs) const {
    if (holdingRegisters == nullptr || inputRegisters == nullptr
        || discreteInputs == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(registerMutex_);

    for (uint16_t address = HR_TOTAL_SWITCH;
         address <= HR_LAST_REGISTER;
         ++address) {
        const auto it = registers_.find(address);
        holdingRegisters[address - HR_TOTAL_SWITCH] =
            (it == registers_.end()) ? 0 : it->second;
    }

    for (uint16_t address = IR_FACTORY_ID;
         address <= IR_LAST_REGISTER;
         ++address) {
        const auto it = registers_.find(address);
        inputRegisters[address - IR_FACTORY_ID] =
            (it == registers_.end()) ? 0 : it->second;
    }

    for (uint16_t bit = 0; bit < DISCRETE_BIT_COUNT; ++bit) {
        discreteInputs[bit] = bit_word_get(discreteWords_.data(), bit);
    }
}

bool ModbusRegisterDevice::ApplyHoldingWrite(
    uint16_t startAddress,
    size_t registerCount,
    const uint16_t* values) {
    if (values == nullptr || registerCount == 0) {
        return false;
    }
    if (registerCount
        > static_cast<size_t>(HR_LAST_REGISTER - HR_TOTAL_SWITCH + 1)) {
        return false;
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress)
        + static_cast<uint32_t>(registerCount) - 1u;
    if (startAddress < HR_TOTAL_SWITCH || endAddress > HR_LAST_REGISTER) {
        return false;
    }

    std::lock_guard<std::mutex> lock(registerMutex_);
    if (!ValidateHoldingWriteLocked(startAddress, registerCount, values)) {
        return false;
    }
    for (size_t index = 0; index < registerCount; ++index) {
        registers_[static_cast<uint16_t>(startAddress + index)] = values[index];
    }
    ApplyModuleInterlockLocked(startAddress, registerCount);
    return true;
}

bool ModbusRegisterDevice::ValidateHoldingWrite(
    uint16_t startAddress,
    size_t registerCount,
    const uint16_t* values) const {
    std::lock_guard<std::mutex> lock(registerMutex_);
    return ValidateHoldingWriteLocked(startAddress, registerCount, values);
}

bool ModbusRegisterDevice::ValidateHoldingWriteLocked(
    uint16_t startAddress,
    size_t registerCount,
    const uint16_t* values) const {
    if (values == nullptr || registerCount == 0) {
        return false;
    }
    const uint32_t endAddress = static_cast<uint32_t>(startAddress)
        + static_cast<uint32_t>(registerCount) - 1u;
    if (startAddress < HR_TOTAL_SWITCH || endAddress > HR_LAST_REGISTER) {
        return false;
    }

    const auto proposed = [this, startAddress, registerCount, values](
                              uint16_t address) {
        if (address >= startAddress
            && address < startAddress + registerCount) {
            return values[address - startAddress];
        }
        const auto it = registers_.find(address);
        return it == registers_.end() ? static_cast<uint16_t>(0) : it->second;
    };

    for (size_t index = 0; index < registerCount; ++index) {
        const uint16_t address = static_cast<uint16_t>(startAddress + index);
        const uint16_t value = values[index];
        // v1.22: 1000H 支持一键开启(1)/整机关机(0)，仅接受0/1。
        if (address == HR_TOTAL_SWITCH && value > 1) {
            return false;
        }
        if (!RegisterAccessChecker::IsWritable(address)) {
            return false;
        }
        // 1001H-1006H 均为 0/1 开关。
        if (address >= HR_FRESH_MODULE_SWITCH
            && address <= HR_AWAY_HOME_SWITCH
            && value > 1) {
            return false;
        }
        // v1.22: 1007H 取值扩展为 0-5（内循环/混风/全热新风/自动/旁通/睡眠）。
        if (address == HR_FRESH_RUN_MODE && value > 5) {
            return false;
        }
        if (address == HR_FAN_GEAR && value > 6) {
            return false;
        }
        // v1.22: 100AH 整机运行模式 0-5。
        if (address == HR_UNIT_RUN_MODE && value > 5) {
            return false;
        }
        // v1.22: 102BH/102CH 高低压开关 0/1。
        if ((address == HR_HIGH_PRESSURE_SWITCH
             || address == HR_LOW_PRESSURE_SWITCH) && value > 1) {
            return false;
        }
        // v1.22: 103CH-103EH 阀门状态设定 0-2。
        if (address >= HR_VALVE1_STATUS_SET
            && address <= HR_VALVE3_STATUS_SET && value > 2) {
            return false;
        }
        // v1.22: 1071H-1073H 风阀方向设定 0/1。
        if (address >= HR_DAMPER1_DIR_SET
            && address <= HR_DAMPER3_DIR_SET && value > 1) {
            return false;
        }
    }

    // v1.22: 102BH-102CH、1038H-103EH 仅在厂测模式(1030H=100)时可写。
    const bool touchesFactoryTestOnly =
        (startAddress <= HR_LOW_PRESSURE_SWITCH && endAddress >= HR_HIGH_PRESSURE_SWITCH)
        || (startAddress <= HR_VALVE3_STATUS_SET && endAddress >= HR_FAN1_FLOW_SET);
    if (touchesFactoryTestOnly
        && proposed(HR_FACTORY_TEST_MODE) != HR_FACTORY_TEST_MODE_ENABLED) {
        return false;
    }

    // v1.22 1001H 注: 1007H、1008H 仅在新风模块开启时可写。
    const bool touchesFreshControl = endAddress >= HR_FRESH_RUN_MODE
        && startAddress <= HR_FAN_GEAR;
    if (touchesFreshControl && proposed(HR_FRESH_MODULE_SWITCH) == 0) {
        return false;
    }
    return true;
}

void ModbusRegisterDevice::ApplyModuleInterlockLocked(
    uint16_t writtenStartAddress,
    size_t writtenRegisterCount) {
    uint16_t& fresh = registers_[HR_FRESH_MODULE_SWITCH];
    uint16_t& pure = registers_[HR_CLEAN_MODE_SWITCH];
    uint16_t& humidity = registers_[HR_HUMIDITY_MODULE_SWITCH];

    fresh = fresh != 0 ? 1 : 0;
    pure = pure != 0 ? 1 : 0;
    humidity = humidity != 0 ? 1 : 0;
    const uint32_t writtenEndAddress =
        static_cast<uint32_t>(writtenStartAddress)
        + static_cast<uint32_t>(writtenRegisterCount) - 1u;
    const bool touchesTotal = writtenStartAddress <= HR_TOTAL_SWITCH
        && writtenEndAddress >= HR_TOTAL_SWITCH;
    const bool wroteFreshOn = writtenStartAddress <= HR_FRESH_MODULE_SWITCH
        && writtenEndAddress >= HR_FRESH_MODULE_SWITCH && fresh != 0;
    const bool wrotePureOn = writtenStartAddress <= HR_CLEAN_MODE_SWITCH
        && writtenEndAddress >= HR_CLEAN_MODE_SWITCH && pure != 0;
    const bool wroteHumidityOn =
        writtenStartAddress <= HR_HUMIDITY_MODULE_SWITCH
        && writtenEndAddress >= HR_HUMIDITY_MODULE_SWITCH && humidity != 0;

    // 单项控制以本次开启项为准；整段写入时超净开启仍具有排他语义。
    if (wrotePureOn) {
        fresh = 0;
        humidity = 0;
    } else if (wroteFreshOn || wroteHumidityOn) {
        pure = 0;
    }

    if (touchesTotal) {
        // v1.22: 1000H 可直接写。1=一键开启（模块状态保持）；
        // 0=整机关机，1001H/1002H/1003H 联动清零。
        if (registers_[HR_TOTAL_SWITCH] == 0) {
            fresh = 0;
            pure = 0;
            humidity = 0;
        }
        return;
    }

    // 任一模块开启 -> 总开关自动开启；模块写导致三者全关 -> 总开关自动关闭。
    if (wroteFreshOn || wrotePureOn || wroteHumidityOn) {
        registers_[HR_TOTAL_SWITCH] =
            (fresh != 0 || pure != 0 || humidity != 0) ? 1 : 0;
    }
}

void ModbusRegisterDevice::UpdateAlertSimulation() {
    static const std::array<uint16_t, 12> faultBits = {
        64, 65, 66, 68, 69, 70, 71, 72, 73, 74, 75, 76
    };
    for (uint16_t bit : faultBits) {
        bit_word_set(discreteWords_.data(), bit, 0);
    }

    // 每一轮重新生成当前故障集合；0 项也是一种正常随机结果，
    // 但不再强制按“有故障/全清空”两种状态交替。
    std::array<uint16_t, faultBits.size()> shuffledFaultBits = faultBits;
    std::shuffle(
        shuffledFaultBits.begin(), shuffledFaultBits.end(), rng_);
    std::uniform_int_distribution<size_t> faultCount(
        0, std::min<size_t>(4, shuffledFaultBits.size()));
    const size_t activeFaultCount = faultCount(rng_);
    for (size_t index = 0; index < activeFaultCount; ++index) {
        bit_word_set(discreteWords_.data(), shuffledFaultBits[index], 1);
    }

    // 每项维护通知独立变化；本轮可能有多项，也可能全部处于正常区间。
    const uint16_t remainingAddresses[] = {
        HR_FILTER1_REMAINING,
        HR_FILTER2_REMAINING,
        HR_FILTER3_REMAINING,
        HR_HUMIDIFY_MODULE_REMAINING,
        HR_IEF_CLEAN_REMAINING
    };
    std::uniform_int_distribution<uint16_t> alertHours(0, 15 * 24);
    std::uniform_int_distribution<uint16_t> normalHours(16 * 24, 180 * 24);
    std::bernoulli_distribution makeAlert(0.45);
    for (uint16_t address : remainingAddresses) {
        registers_[address] = makeAlert(rng_)
            ? alertHours(rng_) : normalHours(rng_);
    }
}

void ModbusRegisterDevice::GenerateSensorData() {
    // 生成随机温度数据 (15-35°C)
    float ra1Temp = tempDist_(rng_);
    float oaTemp = tempDist_(rng_);
    float saTemp = tempDist_(rng_);
    float intakeTemp = tempDist_(rng_);
    float outletTemp = tempDist_(rng_);

    // 更新输入寄存器中的传感器数据 (v1.22 协议)
    // 注意：RA1温度使用实际温度×10，不需要+2730
    registers_[IR_RA1_TEMP] = static_cast<uint16_t>(ra1Temp * 10);
    registers_[IR_RA1_HUMIDITY] = static_cast<uint16_t>(humidityDist_(rng_));
    registers_[IR_RA1_PM25] = static_cast<uint16_t>(pm25Dist_(rng_));
    registers_[IR_RA1_CO2] = static_cast<uint16_t>(co2Dist_(rng_));

    // OA 传感器数据 (2011H-2014H) - 输入寄存器，只读
    registers_[IR_OA_TEMP] = static_cast<uint16_t>(oaTemp * 10);
    registers_[IR_OA_HUMIDITY] = static_cast<uint16_t>(humidityDist_(rng_));
    registers_[IR_OA_PM25] = static_cast<uint16_t>(pm25Dist_(rng_));
    registers_[IR_OA_CO2] = static_cast<uint16_t>(co2Dist_(rng_));

    // SA 传感器数据 (2015H-201AH) - 输入寄存器，只读
    registers_[IR_SA_TEMP] = static_cast<uint16_t>(saTemp * 10);
    registers_[IR_SA_HUMIDITY] = static_cast<uint16_t>(humidityDist_(rng_));
    registers_[IR_SA_PM25] = static_cast<uint16_t>(pm25Dist_(rng_));
    registers_[IR_SA_CO2] = static_cast<uint16_t>(co2Dist_(rng_));

    // TVOC 和甲醛 (2019H-201AH)
    std::uniform_int_distribution<uint16_t> tvocDist(50, 200);
    std::uniform_int_distribution<uint16_t> formalDist(10, 50);
    registers_[IR_TVOC] = tvocDist(rng_);
    registers_[IR_FORMALDEHYDE] = formalDist(rng_);

    // 生成风扇转速 (基于总开关状态)
    const bool unitOn = registers_[HR_TOTAL_SWITCH] == 1;
    if (unitOn) {
        // 风机开启，转速 1000-2000 RPM
        std::uniform_int_distribution<uint16_t> rpmDist(1000, 2000);
        registers_[IR_FAN1_RPM] = rpmDist(rng_);
        registers_[IR_FAN2_RPM] = rpmDist(rng_);
        registers_[IR_FAN3_RPM] = rpmDist(rng_);
        registers_[IR_FAN4_RPM] = rpmDist(rng_);
    } else {
        // 风机关闭
        registers_[IR_FAN1_RPM] = 0;
        registers_[IR_FAN2_RPM] = 0;
        registers_[IR_FAN3_RPM] = 0;
        registers_[IR_FAN4_RPM] = 0;
    }

    // 进/出风口温湿度 (201EH-2021H)
    registers_[IR_INTAKE_TEMP] = static_cast<uint16_t>(intakeTemp * 10);
    registers_[IR_INTAKE_HUMIDITY] =
        static_cast<uint16_t>(humidityDist_(rng_));
    registers_[IR_OUTLET_TEMP] = static_cast<uint16_t>(outletTemp * 10);
    registers_[IR_OUTLET_HUMIDITY] =
        static_cast<uint16_t>(humidityDist_(rng_));

    // 压缩机运行状态：开启时频率跟随设定值，压力和温度同步模拟 (201BH-2023H, 202BH-202EH)
    const uint16_t freqSet = registers_[HR_COMPRESSOR_FREQ_SET];
    const uint16_t compressorOn = unitOn && freqSet > 0 ? 1u : 0u;
    bit_word_set(discreteWords_.data(), DI_BIT_COMPRESSOR_STATUS,
                 static_cast<uint8_t>(compressorOn));
    registers_[IR_COMPRESSOR_FREQ] =
        compressorOn != 0 ? std::min<uint16_t>(freqSet, 90u) : 0u;

    std::uniform_int_distribution<uint16_t> highPressureDist(1500, 4500);
    std::uniform_int_distribution<uint16_t> lowPressureDist(500, 1500);
    std::uniform_int_distribution<int16_t> dischargeTempDist(600, 900);
    std::uniform_int_distribution<int16_t> suctionTempDist(50, 250);
    std::uniform_int_distribution<int16_t> evaporatorTempDist(0, 150);
    if (compressorOn != 0) {
        // 压力单位 bar×100；温度为实际温度×10。
        registers_[IR_HIGH_PRESSURE] = highPressureDist(rng_);
        registers_[IR_LOW_PRESSURE] = lowPressureDist(rng_);
        registers_[IR_COMP_DISCHARGE_TEMP] =
            static_cast<uint16_t>(dischargeTempDist(rng_));
        registers_[IR_COMP_SUCTION_TEMP] =
            static_cast<uint16_t>(suctionTempDist(rng_));
        registers_[IR_EVAPORATOR_TEMP] =
            static_cast<uint16_t>(evaporatorTempDist(rng_));
    } else {
        registers_[IR_HIGH_PRESSURE] = 0;
        registers_[IR_LOW_PRESSURE] = 0;
        registers_[IR_COMP_DISCHARGE_TEMP] = 0;
        registers_[IR_COMP_SUCTION_TEMP] = 0;
        registers_[IR_EVAPORATOR_TEMP] = 0;
    }
    registers_[IR_RESERVED_TEMP] = 0;

    // 201DH: 1007H 自动模式(3)时按室内CO2模拟实际循环状态，非自动时与1007H一致(0-2)。
    const uint16_t runMode = registers_[HR_FRESH_RUN_MODE];
    uint16_t circulationDisplay = 0;
    switch (runMode) {
        case 1: // 内循环/混风
        case 2: // 全热新风/节能新风
            circulationDisplay = runMode;
            break;
        case 3: // 自动模式
            circulationDisplay = registers_[IR_RA1_CO2] > 1000 ? 2 : 1;
            break;
        default: // 内循环/旁通/睡眠等
            circulationDisplay = 0;
            break;
    }
    registers_[IR_AUTO_CIRCULATION_DISPLAY] = circulationDisplay;
}

uint16_t ModbusRegisterDevice::GetRegister(uint16_t address) const {
    std::lock_guard<std::mutex> lock(registerMutex_);
    auto it = registers_.find(address);
    return (it != registers_.end()) ? it->second : 0;
}

void ModbusRegisterDevice::SetRegister(uint16_t address, uint16_t value) {
    std::lock_guard<std::mutex> lock(registerMutex_);
    registers_[address] = value;
    if (address >= HR_TOTAL_SWITCH && address <= HR_HUMIDITY_MODULE_SWITCH) {
        ApplyModuleInterlockLocked(address, 1);
    }
}

// ========== 设备工厂 ==========

std::shared_ptr<ModbusRegisterDevice> DeviceFactory::CreateDefaultDevice() {
    return std::make_shared<ModbusRegisterDevice>(DEVICE_ADDRESS);
}

std::shared_ptr<ModbusRegisterDevice> DeviceFactory::CreateDevice(uint8_t address) {
    return std::make_shared<ModbusRegisterDevice>(address);
}

} // namespace _4CP
