#pragma once

#include <cstdint>
#include <cstddef>
#include <vector>
#include <string>
#include <map>

// Windows不定义ssize_t，使用ptrdiff_t替代
#ifdef _WIN32
typedef ptrdiff_t ssize_t;
#endif

namespace _4CP {

// ========== Modbus RTU 协议常量 ==========

// 设备地址
constexpr uint8_t DEVICE_ADDRESS_4CP = 0xD1;     // 4CP设备默认地址 (209)
constexpr uint8_t DEVICE_ADDRESS_FRESH = 0xC1;    // 全热新风设备默认地址 (193)
constexpr uint8_t DEVICE_ADDRESS = DEVICE_ADDRESS_4CP;   // 默认使用4CP地址
constexpr uint8_t ADDR_BROADCAST = 0x00;           // 广播地址
constexpr uint32_t DEFAULT_BAUDRATE = 9600;        // 默认波特率

// Modbus 功能码
enum class ModbusFunctionCode : uint8_t {
    READ_COILS = 0x01,                  // 读线圈
    READ_DISCRETE_INPUTS = 0x02,        // 读离散输入 (v1.20)
    READ_HOLDING_REGISTERS = 0x03,      // 读保持寄存器
    READ_INPUT_REGISTERS = 0x04,        // 读输入寄存器 (v1.20)
    WRITE_SINGLE_REGISTER = 0x06,       // 写单个寄存器
    WRITE_MULTIPLE_REGISTERS = 0x10,    // 写多个寄存器
    READ_WRITE_REGISTERS = 0x17         // 读写多个寄存器
};

// Modbus 异常码
enum class ModbusExceptionCode : uint8_t {
    ILLEGAL_FUNCTION = 0x01,          // 非法功能码
    ILLEGAL_DATA_ADDRESS = 0x02,      // 非法数据地址
    ILLEGAL_DATA_VALUE = 0x03,        // 非法数据值
    SERVER_DEVICE_FAILURE = 0x04,     // 服务器设备故障
    ACKNOWLEDGE = 0x05,               // 确认
    SERVER_DEVICE_BUSY = 0x06,        // 服务器设备忙
    MEMORY_PARITY_ERROR = 0x08,      // 内存校验错误
    GATEWAY_PATH_UNAVAILABLE = 0x0A,  // 网关路径不可用
    GATEWAY_TARGET_DEVICE_FAILED = 0x0B // 网关目标设备无响应
};

// ========== 寄存器地址定义 (根据 v1.22 协议规范) ==========

// ==================== 保持寄存器 (1000H-1076H) - 03/06/10H功能码 ====================
// 保持寄存器起始地址：1000H（协议偏移 0）

// 总开关和模块开关 (1000H-1003H)
constexpr uint16_t HR_TOTAL_SWITCH = 0x1000;            // 总开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_FRESH_MODULE_SWITCH = 0x1001;     // 新风模块开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_CLEAN_MODE_SWITCH = 0x1002;       // 超净模式开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_HUMIDITY_MODULE_SWITCH = 0x1003;  // 调湿模块开关 (R/W): 0:关闭, 1:开启

// 加湿除湿开关 (1004H-1005H)
constexpr uint16_t HR_HUMIDIFY_SWITCH = 0x1004;         // 加湿开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_DEHUMIDIFY_SWITCH = 0x1005;       // 除湿开关 (R/W): 0:关闭, 1:开启

// 新风模块控制 (1006H-1008H)
constexpr uint16_t HR_AWAY_HOME_SWITCH = 0x1006;          // 一键离家开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_FRESH_RUN_MODE = 0x1007;           // 新风运行模式 (R/W): 0:内循环, 1:内循环/混风, 2:全热新风/节能新风, 3:自动模式, 4:旁通/换气, 5:睡眠模式
constexpr uint16_t HR_FAN_GEAR = 0x1008;                 // 风量档位 (R/W): 0/1/2/3/4/5/6

// 预留风量档位与整机运行模式 (1009H-100AH)
constexpr uint16_t HR_EXHAUST_FAN_GEAR = 0x1009;         // 排风风量档位(预留) (R/W): 0/1/2/3/4/5/6
constexpr uint16_t HR_UNIT_RUN_MODE = 0x100A;            // 整机运行模式 (R/W): 0:无/(8寸:手动), 1:标准, 2:会客, 3:干爽, 4:温润, 5:旅行

// 无极风量控制 (100BH-100EH)
constexpr uint16_t HR_STEPLESS_FAN_CTRL = 0x100B;       // 无极风量控制开关 (R/W): 0:关闭, 1:打开
constexpr uint16_t HR_FRESH_AIR_DUTY = 0x100C;          // 新风风量占空比 (R/W): 0-100%
constexpr uint16_t HR_EXHAUST_AIR_DUTY = 0x100D;        // 排风风量占空比 (R/W): 0-100%
constexpr uint16_t HR_BOOST_AIR_DUTY = 0x100E;          // 增压风量占空比 (R/W): 0-100%

// 温湿度和目标设定 (100FH-1010H)
constexpr uint16_t HR_TARGET_HUMIDITY = 0x100F;         // 目标湿度设定 (R/W): 范围 30~70
constexpr uint16_t HR_TARGET_TEMP = 0x1010;             // 目标温度设定 (R/W): 范围160~310 (实际温度×10)

// 等离子和IEF (1011H-1012H)
constexpr uint16_t HR_PLASMA_STERILIZE = 0x1011;        // 等离子消毒开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_IEF_SWITCH = 0x1012;              // IEF开关 (R/W): 0:关闭, 1:开启

// 电辅热和加湿强度 (1013H-1014H)
constexpr uint16_t HR_ELECTRIC_HEATER = 0x1013;         // 电辅热选择 (R/W): 0x00关闭, 0x01电辅热1, 0x02电辅热2, 0x03电辅热1+2
constexpr uint16_t HR_HUMIDIFY_INTENSITY = 0x1014;      // 加湿/除湿强度设定 (R/W): 0:弱, 1:中, 2:强

// SA风机比例设定 (1015H)
constexpr uint16_t HR_SA_FAN_RATIO = 0x1015;            // SA风量与增压风机比例设定 (R/W): 实际值×10

// 预留 (1016H-101AH)
constexpr uint16_t HR_RESERVED_1016 = 0x1016;            // 预留
constexpr uint16_t HR_RESERVED_1017 = 0x1017;            // 预留
constexpr uint16_t HR_RESERVED_1018 = 0x1018;            // 预留
constexpr uint16_t HR_RESERVED_1019 = 0x1019;            // 预留
constexpr uint16_t HR_RESERVED_101A = 0x101A;            // 预留

// RTC 时间设置 (101BH-101FH) - 10字节 Set RTC 结构体，建议使用 10H 功能码写入
constexpr uint16_t HR_RTC_YEAR = 0x101B;                 // Set RTC - 年 uint16_t (R/W)
constexpr uint16_t HR_RTC_MONTH_DAY = 0x101C;            // Set RTC - 高字节:月, 低字节:日 (R/W)
constexpr uint16_t HR_RTC_HOUR_MINUTE = 0x101D;          // Set RTC - 高字节:时(12小时制时bit7=PM), 低字节:分 (R/W)
constexpr uint16_t HR_RTC_SECOND_WEEK = 0x101E;          // Set RTC - 高字节:秒, 低字节:周(0=周日) (R/W)
constexpr uint16_t HR_RTC_FORMAT_RES = 0x101F;           // Set RTC - 高字节:format(0:24/1:12), 低字节:字节对齐 (R/W)

// 关机延时和加湿控制 (1020H-1024H)
constexpr uint16_t HR_OFF_DELAY_FAN = 0x1020;           // 关机后延时关风机时间 (R/W): 单位:分钟
constexpr uint16_t HR_HUMIDIFY_PUMP_ON = 0x1021;        // 加湿循环泵开时间 (R/W): 单位:秒
constexpr uint16_t HR_HUMIDIFY_PUMP_OFF = 0x1022;       // 加湿循环泵关时间 (R/W): 单位:秒
constexpr uint16_t HR_HUMIDIFY_DRAIN_ON = 0x1023;       // 加湿排水开时间 (R/W): 单位:秒
constexpr uint16_t HR_DEVICE_ADDR = 0x1024;             // 设备地址 (R/W): 4CP:209(0xD1), 全热:193(0xC1), 范围0-254

// 关机状态下空气品质检测 (1025H-1027H)
constexpr uint16_t HR_OFF_AQ_DETECT_SWITCH = 0x1025;    // 关机状态下空气品质检测开关 (R/W): 0:关闭, 1:开启
constexpr uint16_t HR_OFF_AQ_DETECT_INTERVAL = 0x1026;  // 关机状态下空气品质检测间隔时间 (R/W): 单位:分钟
constexpr uint16_t HR_OFF_AQ_DETECT_RUNTIME = 0x1027;   // 关机状态下空气品质检测运行时间 (R/W): 单位:分钟

// 压缩机控制 (1028H-102AH)
constexpr uint16_t HR_COMPRESSOR_EEV = 0x1028;          // 压缩机电子膨胀阀开度 (R/W): 0-500
constexpr uint16_t HR_COMPRESSOR_FREQ_SET = 0x1029;     // 压缩机运行频率设定值 (R/W): 0-90 Hz
constexpr uint16_t HR_COMPRESSOR_FREQ_MAX = 0x102A;     // 压缩机频率上限设定值 (R/W): 60-95 Hz

// 高低压开关 (102BH-102CH) - 仅在厂测模式时可写
constexpr uint16_t HR_HIGH_PRESSURE_SWITCH = 0x102B;    // 高压开关 (R/W): 0:关, 1:开
constexpr uint16_t HR_LOW_PRESSURE_SWITCH = 0x102C;     // 低压开关 (R/W): 0:关, 1:开

// 预留 (102DH-102FH)
constexpr uint16_t HR_RESERVED_102D = 0x102D;           // 预留
constexpr uint16_t HR_RESERVED_102E = 0x102E;           // 预留
constexpr uint16_t HR_RESERVED_102F = 0x102F;           // 预留

// 厂测模式 (1030H)
constexpr uint16_t HR_FACTORY_TEST_MODE = 0x1030;        // 厂测模式 (R/W): 100:测试模式, 其他:正常运行模式
constexpr uint16_t HR_FACTORY_TEST_MODE_ENABLED = 100;   // 厂测模式进入值

// 滤网和保养剩余时间 (1031H-1036H)
constexpr uint16_t HR_FILTER1_REMAINING = 0x1031;       // (设置)初效滤网1剩余时间 (R/W): 单位:小时
constexpr uint16_t HR_FILTER2_REMAINING = 0x1032;       // (设置)中效滤网2剩余时间 (R/W): 单位:小时
constexpr uint16_t HR_FILTER3_REMAINING = 0x1033;       // (设置)高效滤网3剩余时间 (R/W): 单位:小时
constexpr uint16_t HR_HUMIDIFY_MODULE_REMAINING = 0x1034; // (设置)加湿模块剩余时间 (R/W): 单位:小时
constexpr uint16_t HR_IEF_CLEAN_REMAINING = 0x1035;      // (设置)IEF需清洗剩余时间 (R/W): 单位:小时
constexpr uint16_t HR_MAINTENANCE_REMAINING = 0x1036;   // (设置)整机保养剩余时间 (R/W): 单位:天

// 预留 (1037H)
constexpr uint16_t HR_RESERVED_1037 = 0x1037;           // 预留

// 当前风机风量设定值 (1038H-103BH) - 仅在厂测模式时可设定
constexpr uint16_t HR_FAN1_FLOW_SET = 0x1038;           // 当前FAN1风量设定值 (R/W)
constexpr uint16_t HR_FAN2_FLOW_SET = 0x1039;           // 当前FAN2风量设定值 (R/W)
constexpr uint16_t HR_FAN3_FLOW_SET = 0x103A;           // 当前FAN3风量设定值 (R/W)
constexpr uint16_t HR_FAN4_FLOW_SET = 0x103B;           // 当前FAN4风量设定值 (R/W)

// 阀门状态设定 (103CH-103EH) - 仅在厂测模式时可设定: 0:关闭, 1:半开, 2:全开
constexpr uint16_t HR_VALVE1_STATUS_SET = 0x103C;       // 阀门1状态设定 (R/W)
constexpr uint16_t HR_VALVE2_STATUS_SET = 0x103D;       // 阀门2状态设定 (R/W)
constexpr uint16_t HR_VALVE3_STATUS_SET = 0x103E;       // 阀门3状态设定 (R/W)

// 风机累计运转时间清除 (103FH)
constexpr uint16_t HR_CLEAR_ALL_FAN_TIME = 0x103F;       // 清除所有风机累计运转时间 (W): 写1清除

// 恢复出厂 (1040H)
constexpr uint16_t HR_FACTORY_RESET = 0x1040;            // 恢复出厂 (W): 写1恢复出厂设置

// FAN1-4 外循环/内循环各档风量设定值 (1041H-1070H)，共4风机×2循环×6档=48个寄存器
// 布局: FAN1外(1041H-1046H), FAN1内(1047H-104CH), FAN2外(104DH-1052H), FAN2内(1053H-1058H),
//       FAN3外(1059H-105EH), FAN3内(105FH-1064H), FAN4外(1065H-106AH), FAN4内(106BH-1070H)
constexpr uint16_t HR_FAN_FLOW_SET_FIRST = 0x1041;      // FAN1外循环1档风量设定值
constexpr uint16_t HR_FAN_FLOW_SET_LAST = 0x1070;       // FAN4内循环6档风量设定值

// 风阀方向和步数设定 (1071H-1076H)
constexpr uint16_t HR_DAMPER1_DIR_SET = 0x1071;         // 风阀1方向设定 (R/W): 0/1
constexpr uint16_t HR_DAMPER2_DIR_SET = 0x1072;         // 风阀2方向设定 (R/W): 0/1
constexpr uint16_t HR_DAMPER3_DIR_SET = 0x1073;         // 风阀3方向设定 (R/W): 0/1
constexpr uint16_t HR_DAMPER1_STEPS_SET = 0x1074;       // 风阀1运行步数设定 (R/W)
constexpr uint16_t HR_DAMPER2_STEPS_SET = 0x1075;       // 风阀2运行步数设定 (R/W)
constexpr uint16_t HR_DAMPER3_STEPS_SET = 0x1076;       // 风阀3运行步数设定 (R/W)

// 保持寄存器末地址（区间边界，读写权限和镜像大小按此计算）
constexpr uint16_t HR_LAST_REGISTER = 0x1076;

// ==================== 输入寄存器 (2000H-203BH) - 04H功能码 (只读) ====================
// 输入寄存器起始地址：2000H（协议偏移 0）

// 设备基本信息 (2000H-2004H)
constexpr uint16_t IR_FACTORY_ID = 0x2000;               // 工厂标志 (R): ASCII "BA"
constexpr uint16_t IR_MODEL = 0x2001;                    // 机型 (R): 数值 4CP:0, 全热新风:1
constexpr uint16_t IR_VERSION = 0x2002;                  // 版本 (R): 数值除以100，如0101代表1.01
constexpr uint16_t IR_FRESH_MODE_MAX_GEAR = 0x2003;      // 新风模式风量最大档位 (R): 3/4/5/6...
constexpr uint16_t IR_MIX_MODE_MAX_GEAR = 0x2004;        // 内循环/混风模式风量最大档位 (R): 3/4/5/6...

// 风机档位 (2005H-2008H)
constexpr uint16_t IR_FAN1_GEAR = 0x2005;                 // FAN1档位 (R): 0/1/2/3/4/5/6
constexpr uint16_t IR_FAN2_GEAR = 0x2006;                 // FAN2档位 (R): 0/1/2/3/4/5/6
constexpr uint16_t IR_FAN3_GEAR = 0x2007;                 // FAN3档位 (R): 0/1/2/3/4/5/6
constexpr uint16_t IR_FAN4_GEAR = 0x2008;                 // FAN4档位 (R): 0/1/2/3/4/5/6

// 风机实时转速 (2009H-200CH)
constexpr uint16_t IR_FAN1_RPM = 0x2009;                 // FAN1实时rpm (R)
constexpr uint16_t IR_FAN2_RPM = 0x200A;                 // FAN2实时rpm (R)
constexpr uint16_t IR_FAN3_RPM = 0x200B;                 // FAN3实时rpm (R)
constexpr uint16_t IR_FAN4_RPM = 0x200C;                 // FAN4实时rpm (R)

// RA1 传感器数据 (200DH-2010H)
constexpr uint16_t IR_RA1_TEMP = 0x200D;                 // RA1温度 (R): 实际温度×10
constexpr uint16_t IR_RA1_HUMIDITY = 0x200E;             // RA1湿度 (R): 湿度值0-100, 单位1%RH
constexpr uint16_t IR_RA1_PM25 = 0x200F;                 // RA1 PM2.5 (R)
constexpr uint16_t IR_RA1_CO2 = 0x2010;                  // RA1 CO2 (R)

// OA 传感器数据 (2011H-2014H)
constexpr uint16_t IR_OA_TEMP = 0x2011;                  // OA温度 (R): 实际温度×10
constexpr uint16_t IR_OA_HUMIDITY = 0x2012;              // OA湿度 (R): 湿度值0-100, 单位1%RH
constexpr uint16_t IR_OA_PM25 = 0x2013;                  // OA PM2.5 (R)
constexpr uint16_t IR_OA_CO2 = 0x2014;                   // OA CO2 (R)

// SA 传感器数据 (2015H-201AH)
constexpr uint16_t IR_SA_TEMP = 0x2015;                  // SA温度 (R): 实际温度×10
constexpr uint16_t IR_SA_HUMIDITY = 0x2016;              // SA湿度 (R): 湿度值0-100, 单位1%RH
constexpr uint16_t IR_SA_PM25 = 0x2017;                  // SA PM2.5 (R)
constexpr uint16_t IR_SA_CO2 = 0x2018;                   // SA CO2 (R)
constexpr uint16_t IR_TVOC = 0x2019;                     // TVOC (R)
constexpr uint16_t IR_FORMALDEHYDE = 0x201A;             // 甲醛 (R)

// 压缩机和电辅热状态 (201BH-201CH)
constexpr uint16_t IR_COMPRESSOR_FREQ = 0x201B;          // 压缩机运行频率 (R)
constexpr uint16_t IR_HEATER_STATUS = 0x201C;            // 电辅热状态 (R): 0x00关闭, 0x01电辅热1, 0x02电辅热2, 0x03电辅热1+2

// 自动模式内外循环显示与进/出风口、压力数据 (201DH-2023H)
constexpr uint16_t IR_AUTO_CIRCULATION_DISPLAY = 0x201D; // 1007H自动模式时内外循环显示 (R): 0:内循环, 1:内循环/混风, 2:全热新风/节能新风
constexpr uint16_t IR_INTAKE_TEMP = 0x201E;              // 进风口温度 (R): 实际温度×10
constexpr uint16_t IR_INTAKE_HUMIDITY = 0x201F;          // 进风口湿度 (R): 湿度值0-100, 单位1%RH
constexpr uint16_t IR_OUTLET_TEMP = 0x2020;              // 出风口温度(预留) (R): 实际温度×10
constexpr uint16_t IR_OUTLET_HUMIDITY = 0x2021;          // 出风口湿度(预留) (R): 湿度值0-100, 单位1%RH
constexpr uint16_t IR_HIGH_PRESSURE = 0x2022;            // 高压压力值 (R): bar×100, 范围0-5000
constexpr uint16_t IR_LOW_PRESSURE = 0x2023;             // 低压压力值 (R): bar×100, 范围0-5000

// 加湿水位浮子状态 (2024H-2025H)
constexpr uint16_t IR_HUMIDIFY_WATER_FLOAT = 0x2024;    // 加湿进水水位浮子状态 (R): Bit0/Bit1/Bit2
constexpr uint16_t IR_HUMIDIFY_DRAIN_FLOAT = 0x2025;    // 加湿排水水位浮子状态 (R): Bit0/Bit1/Bit2

// 系统和风机累计运行时间 (2026H-202AH)
constexpr uint16_t IR_SYSTEM_RUNTIME_DAYS = 0x2026;     // 系统运行(开机)时间(累计) (R): 单位:天(恢复出厂清零)
constexpr uint16_t IR_FAN1_RUNTIME = 0x2027;             // FAN1累计运转时间 (R): 单位:小时(恢复出厂清零)
constexpr uint16_t IR_FAN2_RUNTIME = 0x2028;             // FAN2累计运转时间 (R): 单位:小时(恢复出厂清零)
constexpr uint16_t IR_FAN3_RUNTIME = 0x2029;             // FAN3累计运转时间 (R): 单位:小时(恢复出厂清零)
constexpr uint16_t IR_FAN4_RUNTIME = 0x202A;             // FAN4累计运转时间 (R): 单位:小时(恢复出厂清零)

// 压缩机温度和电压检测 (202BH-202FH)
constexpr uint16_t IR_COMP_DISCHARGE_TEMP = 0x202B;      // 压缩机排气温度 (R): 实际温度×10
constexpr uint16_t IR_COMP_SUCTION_TEMP = 0x202C;        // 压缩机吸气温度 (R): 实际温度×10
constexpr uint16_t IR_EVAPORATOR_TEMP = 0x202D;          // 蒸发器盘管温度 (R): 实际温度×10
constexpr uint16_t IR_RESERVED_TEMP = 0x202E;            // 预留温度 (R): 实际温度×10
constexpr uint16_t IR_AC_VOLTAGE = 0x202F;               // 交流电压检测值 (R): 待定

// 主控板版本时间字符串 (2030H-203BH) - Char[24], 不满填0x00
constexpr uint16_t IR_MAINBOARD_STRING_FIRST = 0x2030;   // 主控板版本时间字符串[0-1] (R)
constexpr uint16_t IR_MAINBOARD_STRING_LAST = 0x203B;    // 主控板版本时间字符串[22-23] (R)

// 输入寄存器末地址（区间边界，读写权限和镜像大小按此计算）
constexpr uint16_t IR_LAST_REGISTER = 0x203B;

// ==================== 离散输入寄存器 (3000H-3004H) - 02H功能码 (只读) ====================
// 离散输入起始地址：3000H（协议偏移 0）

// 能力配置表（3000H-3001H，位偏移0-31）
constexpr uint16_t DI_CAPABILITY_START = 0x3000;         // 设备能力配置起始
constexpr uint8_t DI_BIT_HAS_HUMIDIFY_MODULE = 0;        // 位偏移0: 有无加湿模块: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_DEHUMIDIFY = 1;             // 位偏移1: 有无除湿模块: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_BYPASS_MODE = 2;            // 位偏移2: 有无(旁通/换气)模式: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_IEF = 3;                    // 位偏移3: 有无IEF净化: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_STERILIZE = 4;              // 位偏移4: 有无消毒模块: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_HEATER_CTRL = 5;            // 位偏移5: 有无电加热控制: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_ANTIFREEZE = 6;             // 位偏移6: 有无防冻保护: 0:无, 1:有
constexpr uint8_t DI_BIT_HAS_HCHO = 7;                   // 位偏移7: 有无甲醛HCHO: 0:无, 1:有
// 位偏移8-15: 预留
constexpr uint8_t DI_BIT_RESERVED_16 = 16;               // 位偏移16-31: 预留

// 状态表（3002H-3003H，位偏移32-63）
constexpr uint8_t DI_BIT_HUMIDIFY_PUMP_STATUS = 32;      // 位偏移32: 加湿循环泵状态: 0:关闭, 1:开启
constexpr uint8_t DI_BIT_HUMIDIFY_INLET_VALVE = 33;      // 位偏移33: 加湿进水阀状态: 0:关闭, 1:开启
constexpr uint8_t DI_BIT_HUMIDIFY_DRAIN_PUMP = 34;       // 位偏移34: 加湿排水泵状态: 0:关闭, 1:开启
constexpr uint8_t DI_BIT_COMPRESSOR_STATUS = 35;         // 位偏移35: 压缩机状态: 0:关闭, 1:开启
constexpr uint8_t DI_BIT_RESERVED_36 = 36;               // 位偏移36: 预留
constexpr uint8_t DI_BIT_OFF_AQ_DETECTING = 37;          // 位偏移37: 关机状态下空气质量检测中(风阀开,风机转): 0:否, 1:是
// 位偏移38-43: 待添加
// 位偏移44-63: 预留

// 故障码表（3004H，位偏移64起）
constexpr uint8_t DI_BIT_FAULT_FAN1 = 64;               // 位偏移64: 新风机异常: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_FAN2 = 65;               // 位偏移65: 排风机异常: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_FAN3 = 66;               // 位偏移66: 增压风机异常: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_RESERVED_67 = 67;        // 位偏移67: 待补充
constexpr uint8_t DI_BIT_FAULT_HUMIDIFY_COMM = 68;      // 位偏移68: 加湿机通讯失联: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_INLET_FLOAT_ALARM = 69; // 位偏移69: 加湿进水槽浮子警报: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_DRAIN_FLOAT_ALARM = 70; // 位偏移70: 加湿排水槽浮子警报: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_DRAIN_NOT_DROP = 71;    // 位偏移71: 加湿排水槽水位浮子排水后不下降: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_INLET_EMPTY = 72;       // 位偏移72: 加湿进水槽缺水: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_HEATER1_PROTECT = 73;    // 位偏移73: 加湿电辅热1过流/过压保护: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_HEATER2_PROTECT = 74;    // 位偏移74: 加湿电辅热2过流/过压保护: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_INLET_FLOAT_ERR = 75;    // 位偏移75: 加湿进水槽浮子有异常: 0:无故障, 1:故障
constexpr uint8_t DI_BIT_FAULT_DRAIN_FLOAT_ERR = 76;    // 位偏移76: 加湿排水槽浮子有异常: 0:无故障, 1:故障

constexpr uint16_t DISCRETE_BIT_COUNT = 77;             // 位偏移0..76
constexpr uint16_t DISCRETE_WORD_COUNT = 5;             // 77 bit按16位归并

static inline void bit_word_set(uint16_t* words, uint16_t bit, uint8_t value) {
    const uint16_t mask = static_cast<uint16_t>(1u << (bit & 15u));
    uint16_t* word = &words[bit >> 4];
    *word = value != 0
        ? static_cast<uint16_t>(*word | mask)
        : static_cast<uint16_t>(*word & static_cast<uint16_t>(~mask));
}

static inline uint8_t bit_word_get(const uint16_t* words, uint16_t bit) {
    return static_cast<uint8_t>((words[bit >> 4] >> (bit & 15u)) & 1u);
}

// ========== Modbus RTU 帧结构 ==========

// Modbus RTU 请求帧 - 读保持寄存器 (03H)
#pragma pack(push, 1)
struct ModbusReadRequest {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (03H)
    uint16_t startAddress;      // 起始地址 (大端序)
    uint16_t registerCount;     // 寄存器数量 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus RTU 响应帧 - 读保持寄存器 (03H)
struct ModbusReadResponse {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (03H)
    uint8_t byteCount;          // 数据字节数
    uint8_t data[252];          // 寄存器数据 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus RTU 请求帧 - 写单个寄存器 (06H)
struct ModbusWriteSingleRequest {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (06H)
    uint16_t registerAddress;   // 寄存器地址 (大端序)
    uint16_t registerValue;     // 寄存器值 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus RTU 响应帧 - 写单个寄存器 (06H)
struct ModbusWriteSingleResponse {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (06H)
    uint16_t registerAddress;   // 寄存器地址 (大端序)
    uint16_t registerValue;     // 寄存器值 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus RTU 请求帧 - 写多个寄存器 (10H)
struct ModbusWriteMultipleRequest {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (10H)
    uint16_t startAddress;      // 起始地址 (大端序)
    uint16_t registerCount;     // 寄存器数量 (大端序)
    uint8_t byteCount;          // 数据字节数
    uint8_t data[246];          // 寄存器值 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus RTU 响应帧 - 写多个寄存器 (10H)
struct ModbusWriteMultipleResponse {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 (10H)
    uint16_t startAddress;      // 起始地址 (大端序)
    uint16_t registerCount;     // 寄存器数量 (大端序)
    uint16_t crc;               // CRC16校验 (小端序)
};

// Modbus 异常响应帧
struct ModbusExceptionResponse {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码 + 0x80
    uint8_t exceptionCode;      // 异常码
    uint16_t crc;               // CRC16校验 (小端序)
};
#pragma pack(pop)

// ========== 通用帧结构 (用于解析) ==========

struct ModbusFrame {
    uint8_t deviceAddress;      // 设备地址
    uint8_t functionCode;       // 功能码
    std::vector<uint8_t> data;  // 数据域
    uint16_t crc;               // CRC16 (已解析，小端序)

    ModbusFrame() : deviceAddress(0), functionCode(0), crc(0) {}
};

// ========== 寄存器存储 ==========

// 寄存器值类型
using RegisterValue = uint16_t;

// 寄存器映射表 (地址 -> 值)
using RegisterMap = std::map<uint16_t, RegisterValue>;

// 寄存器读写权限
enum class RegisterAccess : uint8_t {
    READ_ONLY = 0,     // 只读
    READ_WRITE = 1,    // 读写
    WRITE_ONLY = 2      // 只写
};

// ========== CRC16 计算 (Modbus 标准) ==========

uint16_t CalculateCRC16(const uint8_t* data, size_t length);

// ========== 字节序转换 ==========

// 大端序：读取 uint16_t
inline uint16_t ReadBigEndianUint16(const uint8_t* buffer) {
    return (static_cast<uint16_t>(buffer[0]) << 8) |
           static_cast<uint16_t>(buffer[1]);
}

// 大端序：写入 uint16_t
inline void WriteBigEndianUint16(uint8_t* buffer, uint16_t value) {
    buffer[0] = static_cast<uint8_t>((value >> 8) & 0xFF);
    buffer[1] = static_cast<uint8_t>(value & 0xFF);
}

// 小端序：读取 uint16_t
inline uint16_t ReadLittleEndianUint16(const uint8_t* buffer) {
    return static_cast<uint16_t>(buffer[0]) |
           (static_cast<uint16_t>(buffer[1]) << 8);
}

// 小端序：写入 uint16_t
inline void WriteLittleEndianUint16(uint8_t* buffer, uint16_t value) {
    buffer[0] = static_cast<uint8_t>(value & 0xFF);
    buffer[1] = static_cast<uint8_t>((value >> 8) & 0xFF);
}

// ========== Modbus 协议构建和解析 ==========

class ModbusProtocol {
public:
    // 构建 03H - 读保持寄存器请求
    static std::vector<uint8_t> BuildReadHoldingRegistersRequest(
        uint8_t deviceAddress,
        uint16_t startAddress,
        uint16_t registerCount
    );

    // 构建 03H - 读保持寄存器响应
    static std::vector<uint8_t> BuildReadHoldingRegistersResponse(
        uint8_t deviceAddress,
        const std::vector<uint16_t>& registerValues
    );

    // 构建 06H - 写单个寄存器请求
    static std::vector<uint8_t> BuildWriteSingleRegisterRequest(
        uint8_t deviceAddress,
        uint16_t registerAddress,
        uint16_t registerValue
    );

    // 构建 06H - 写单个寄存器响应
    static std::vector<uint8_t> BuildWriteSingleRegisterResponse(
        uint8_t deviceAddress,
        uint16_t registerAddress,
        uint16_t registerValue
    );

    // 构建 10H - 写多个寄存器请求
    static std::vector<uint8_t> BuildWriteMultipleRegistersRequest(
        uint8_t deviceAddress,
        uint16_t startAddress,
        const std::vector<uint16_t>& registerValues
    );

    // 构建 10H - 写多个寄存器响应
    static std::vector<uint8_t> BuildWriteMultipleRegistersResponse(
        uint8_t deviceAddress,
        uint16_t startAddress,
        uint16_t registerCount
    );

    // ========== v1.20 功能码 ==========

    // 构建 02H - 读离散输入请求
    static std::vector<uint8_t> BuildReadDiscreteInputsRequest(
        uint8_t deviceAddress,
        uint16_t startAddress,
        uint16_t inputCount
    );

    // 构建 02H - 读离散输入响应
    static std::vector<uint8_t> BuildReadDiscreteInputsResponse(
        uint8_t deviceAddress,
        const std::vector<uint8_t>& inputValues
    );

    // 构建 04H - 读输入寄存器请求
    static std::vector<uint8_t> BuildReadInputRegistersRequest(
        uint8_t deviceAddress,
        uint16_t startAddress,
        uint16_t registerCount
    );

    // 构建 04H - 读输入寄存器响应
    static std::vector<uint8_t> BuildReadInputRegistersResponse(
        uint8_t deviceAddress,
        const std::vector<uint16_t>& registerValues
    );

    // 构建异常响应
    static std::vector<uint8_t> BuildExceptionResponse(
        uint8_t deviceAddress,
        uint8_t functionCode,
        ModbusExceptionCode exceptionCode
    );

    // 解析 Modbus 帧
    static bool ParseFrame(
        const std::vector<uint8_t>& buffer,
        ModbusFrame& frame,
        size_t& frameLen
    );

    // 验证 CRC
    static bool ValidateCRC(const std::vector<uint8_t>& frame);
};

// ========== 寄存器权限检查工具 ==========

class RegisterAccessChecker {
public:
    // 检查寄存器是否可写
    static bool IsWritable(uint16_t address);

    // 检查寄存器是否可读
    static bool IsReadable(uint16_t address);

    // 获取寄存器访问权限
    static RegisterAccess GetAccess(uint16_t address);
};

} // namespace _4CP
