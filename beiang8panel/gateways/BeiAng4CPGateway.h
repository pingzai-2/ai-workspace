/**
 * 贝昂4CP设备网关类
 *
 * 实现与4CP设备的Modbus RTU协议通信（使用 libmodbus）
 */

#ifndef BEIANG4CPGATEWAY_H
#define BEIANG4CPGATEWAY_H

#include "structure/GatewayGeneralDataStructure.h"
#include "structure/ManualModeDataStructure.h"
#include "structure/SmartModeDataStructure.h"
#include "structure/EnvironmentDataStructure.h"
#include "common/GlobalDefine.h"
#include "CommunicationScheduler.h"
#include <cerrno>
#include <cstdint>
#include <functional>
#include <memory>
#include <modbus/modbus.h>
#include <mutex>
#include <string>
#include <vector>

// 4CP Modbus寄存器地址定义（根据协议文档v1.22）
namespace BeiAng4CPRegisters {
// ========== 保持寄存器（03/06/10功能码，起始地址1000H） ==========

// ========== 总开关与模块开关（1000H-1005H） ==========
const uint16_t SWITCH_CONTROL = 0x1000; // 总开关（0:关闭 1:开启；注：1001H、1002H、1003H任一个开启，总开关会自动开启；三者全关闭则总开关关闭）[读写]
const uint16_t FRESH_AIR_MODULE_SWITCH = 0x1001; // 新风模块开关（0:关闭 1:开启；与1002H互斥，新风模块开则超净模块关闭；1007H、1008H仅在此开启时可写）[读写]
const uint16_t SUPER_PURE_MODE_SWITCH = 0x1002; // 超净模式开关（0:关闭 1:开启；与1001H、1003H互斥，超净模块开则新风模块关闭，调湿模块关闭）[读写]
const uint16_t HUMIDITY_MODULE_SWITCH = 0x1003; // 调湿模块开关（0:调湿关闭 1:调湿开启；此时加湿1004H、除湿1005H为只读；与1002H互斥）[读写]
const uint16_t HUMIDIFICATION_SWITCH = 0x1004; // 加湿开关（0:加湿关闭 1:加湿开启）[读写]
const uint16_t DEHUMIDIFICATION_SWITCH = 0x1005; // 除湿开关（0:除湿关闭 1:除湿开启）[读写]

// ========== 新风模块控制（1006H-1009H） ==========
const uint16_t LEAVE_HOME_SWITCH = 0x1006; // 一键离家开关（0:关闭 1:开启；v1.22由手动/自动改为一键离家）[读写]
const uint16_t FRESH_AIR_RUN_MODE = 0x1007; // 新风运行模式（0:内循环 1:内循环/混风 2:全热新风/节能新风 3:自动模式 4:旁通/换气 5:睡眠模式；仅在1001H开启时可写）[读写]
const uint16_t FAN_GEAR = 0x1008; // 风量档位（0/1/2/3/4/5/6；仅1001H开启且1007H为0/1/2/4时可写（3自动、5睡眠只读）；4CP新风模式最大档为3档，其他最大可控为5档，超净模式开启时显示为6档）[读写]
const uint16_t EXHAUST_FAN_GEAR = 0x1009; // 排风风量档位（预留）[读写]

// ========== 整机运行模式与无极风量（100AH-100EH） ==========
const uint16_t WHOLE_UNIT_RUN_MODE = 0x100A; // 整机运行模式（0:无/(对应8寸：手动) 1:标准 2:会客 3:干爽 4:温润 5:旅行；v1.22由增压风量档位(预留)改为整机运行模式）[读写]
const uint16_t STEPLESS_FAN_CONTROL = 0x100B; // 无极风量控制开关（0:关闭 1:打开）[读写]
const uint16_t FRESH_FAN_DUTY_CYCLE = 0x100C; // 新风风量占空比（0-100%）[读写]
const uint16_t EXHAUST_FAN_DUTY_CYCLE = 0x100D; // 排风风量占空比（0-100%）[读写]
const uint16_t BOOST_FAN_DUTY_CYCLE = 0x100E; // 增压风风量占空比（0-100%）[读写]

// ========== 环境目标设定（100FH-1015H） ==========
const uint16_t TARGET_HUMIDITY = 0x100F; // 目标湿度设定（范围30~70）[读写]
const uint16_t TARGET_TEMPERATURE = 0x1010; // 目标温度设定（范围160~310，实际设定温度×10）[读写]
const uint16_t PLASMA_DISINFECT_SWITCH = 0x1011; // 等离子消毒开关（0:关闭 1:开启）[读写]
const uint16_t IEF_SWITCH = 0x1012; // IEF（0:关闭 1:开启）[读写]
const uint16_t AUX_HEAT = 0x1013; // 电辅热选择（0x00:关闭 0x01:开启电辅热1 0x02:开启电辅热2 0x03:开启电辅热1、2）[读写]
const uint16_t HUMIDITY_INTENSITY = 0x1014; // 加湿/除湿强度设定（0:弱 1:中 2:强）[读写]
const uint16_t SA_FAN_RATIO = 0x1015; // SA风量与增压风机比例设定（实际值×10，例：1.8×10=18）[读写]

// ========== RTC时间设置寄存器（101BH-101FH，共10字节，功能码0x10） ==========
// 1016H-101AH 预留。按结构体打包：101BH=year；101CH=month<<8|day；
// 101DH=hour<<8|minute（12小时制时hour bit7=PM）；101EH=second<<8|week；101FH=format<<8|res
const uint16_t RTC_YEAR = 0x101B;   // 年（2026...）
const uint16_t RTC_MONTH_DAY = 0x101C; // 月（高字节）+ 日（低字节）
const uint16_t RTC_HOUR_MINUTE = 0x101D; // 时（高字节）+ 分（低字节）
const uint16_t RTC_SECOND_WEEK = 0x101E; // 秒（高字节）+ 周（低字节）
const uint16_t RTC_FORMAT_RES = 0x101F;  // 格式（高字节，0:24小时制）+ 字节对齐（低字节）

// ========== 定时/延时与设备地址（1020H-1027H） ==========
const uint16_t FAN_DELAY_OFF_TIME = 0x1020; // 关机后延时关风机时间（分钟）[读写]
const uint16_t HUMIDIFICATION_PUMP_ON_TIME = 0x1021; // 加湿循环泵开时间（秒）[读写]
const uint16_t HUMIDIFICATION_PUMP_OFF_TIME = 0x1022; // 加湿循环泵关时间（秒）[读写]
const uint16_t HUMIDIFICATION_DRAIN_ON_TIME = 0x1023; // 加湿排水开时间（秒）[读写]
const uint16_t DEVICE_ADDRESS = 0x1024; // 设备地址（4CP:209/D1H 默认值209；全热新风:193/C1H 默认值193；范围0-254）[读写]
const uint16_t OFF_AIR_QUALITY_DETECT_SWITCH = 0x1025; // 关机状态下空气品质检测开关（0:关闭 1:开启）[读写]
const uint16_t OFF_AIR_QUALITY_DETECT_INTERVAL = 0x1026; // 关机状态下空气品质检测间隔时间（分钟，例如60分钟）[读写]
const uint16_t OFF_AIR_QUALITY_DETECT_RUNTIME = 0x1027; // 关机状态下空气品质检测运行时间（分钟，例如2分钟）[读写]

// ========== 压缩机与高低压开关（1028H-102CH） ==========
const uint16_t COMPRESSOR_EEV_OPENING = 0x1028; // 压缩机电子膨胀阀开度（0-500）[读写]
const uint16_t COMPRESSOR_FREQUENCY_SET = 0x1029; // 压缩机运行频率设定值（0-90Hz）[读写]
const uint16_t COMPRESSOR_FREQUENCY_MAX = 0x102A; // 压缩机频率上限设定值（60-95Hz）[读写]
const uint16_t HIGH_PRESSURE_SWITCH = 0x102B; // 高压开关（0:关 1:开；仅厂测模式可写）[读写]
const uint16_t LOW_PRESSURE_SWITCH = 0x102C; // 低压开关（0:关 1:开；仅厂测模式可写）[读写]

// ========== 厂测与滤网保养（1030H-1036H） ==========
const uint16_t FACTORY_TEST_MODE = 0x1030; // 厂测模式（100:测试模式；其他均为正常运行模式）[读写]
const uint16_t FILTER1_REMAINING_TIME = 0x1031; // （设置）初效滤网1剩余时间（小时）[读写]
const uint16_t FILTER2_REMAINING_TIME = 0x1032; // （设置）中效滤网2剩余时间（小时）[读写]
const uint16_t FILTER3_REMAINING_TIME = 0x1033; // （设置）高效滤网3剩余时间（小时）[读写]
const uint16_t HUMIDITY_FILTER_REMAINING_TIME = 0x1034; // （设置）加湿模块剩余时间（小时）[读写]
const uint16_t IEF_CLEAN_REMAINING_TIME = 0x1035; // （设置）IEF需清洗剩余时间（小时）[读写]
const uint16_t WHOLE_UNIT_MAINTENANCE_TIME = 0x1036; // （设置）整机保养剩余时间（天）[读写]

// ========== 厂测设定与阀门（1038H-103EH，仅厂测模式可写） ==========
const uint16_t FAN1_CURRENT_SETTING = 0x1038; // 当前FAN1风量设定值[读写]
const uint16_t FAN2_CURRENT_SETTING = 0x1039; // 当前FAN2风量设定值[读写]
const uint16_t FAN3_CURRENT_SETTING = 0x103A; // 当前FAN3风量设定值[读写]
const uint16_t FAN4_CURRENT_SETTING = 0x103B; // 当前FAN4风量设定值[读写]
const uint16_t VALVE1_STATUS_SETTING = 0x103C; // 阀门1状态设定（0:关闭 1:半开 2:全开）[读写]
const uint16_t VALVE2_STATUS_SETTING = 0x103D; // 阀门2状态设定（0:关闭 1:半开 2:全开）[读写]
const uint16_t VALVE3_STATUS_SETTING = 0x103E; // 阀门3状态设定（0:关闭 1:半开 2:全开）[读写]

// ========== 维护操作寄存器（103FH-1040H，只写） ==========
const uint16_t CLEAR_ALL_FAN_RUNTIME = 0x103F; // 清除所有风机累计运转时间（写1清除）
const uint16_t RESTORE_FACTORY = 0x1040; // 恢复出厂（写1恢复）

// ========== 风机内外循环各档风量设定（1041H-1070H，v1.22新增可设定） ==========
// 每台风机12个寄存器：外循环1-6档 + 内循环1-6档
const uint16_t FAN1_EXTERNAL_GEAR_FLOW = 0x1041; // FAN1外循环1-6档风量设定值（1041H-1046H）
const uint16_t FAN1_INTERNAL_GEAR_FLOW = 0x1047; // FAN1内循环1-6档风量设定值（1047H-104CH）
const uint16_t FAN2_EXTERNAL_GEAR_FLOW = 0x104D; // FAN2外循环1-6档（104DH-1052H）
const uint16_t FAN2_INTERNAL_GEAR_FLOW = 0x1053; // FAN2内循环1-6档（1053H-1058H）
const uint16_t FAN3_EXTERNAL_GEAR_FLOW = 0x1059; // FAN3外循环1-6档（1059H-105EH）
const uint16_t FAN3_INTERNAL_GEAR_FLOW = 0x105F; // FAN3内循环1-6档（105FH-1064H）
const uint16_t FAN4_EXTERNAL_GEAR_FLOW = 0x1065; // FAN4外循环1-6档（1065H-106AH）
const uint16_t FAN4_INTERNAL_GEAR_FLOW = 0x106B; // FAN4内循环1-6档（106BH-1070H）

// ========== 风阀设定（1071H-1076H，v1.22新增可设定） ==========
const uint16_t DAMPER1_DIRECTION_SETTING = 0x1071; // 风阀1方向设定（0/1）[读写]
const uint16_t DAMPER2_DIRECTION_SETTING = 0x1072; // 风阀2方向设定（0/1）[读写]
const uint16_t DAMPER3_DIRECTION_SETTING = 0x1073; // 风阀3方向设定（0/1）[读写]
const uint16_t DAMPER1_STEPS_SETTING = 0x1074; // 风阀1运行步数设定[读写]
const uint16_t DAMPER2_STEPS_SETTING = 0x1075; // 风阀2运行步数设定[读写]
const uint16_t DAMPER3_STEPS_SETTING = 0x1076; // 风阀3运行步数设定[读写]

// ========== 输入寄存器（04功能码，起始地址2000H） ==========

// ========== 基础信息寄存器（2000H-2004H，只读） ==========
const uint16_t INPUT_FACTORY_FLAG = 0x2000; // 工厂标志（两位ASCII字符：BA）
const uint16_t INPUT_DEVICE_MODEL = 0x2001; // 机型（4CP:0, 全热新风：1）
const uint16_t INPUT_VERSION = 0x2002; // 版本（0101，除以100，代表1.01）
const uint16_t INPUT_MAX_FAN_GEAR_FRESH = 0x2003; // 新风模式风量最大档位（3、4、5、6...）
const uint16_t INPUT_MAX_FAN_GEAR_RECIRC = 0x2004; // 内循环/混风模式风量最大档位（3、4、5、6...）

// ========== 风机档位寄存器（2005H-2008H，只读） ==========
const uint16_t INPUT_FAN1_GEAR = 0x2005; // FAN1档位（0/1/2/3/4/5/6）
const uint16_t INPUT_FAN2_GEAR = 0x2006; // FAN2档位（0/1/2/3/4/5/6）
const uint16_t INPUT_FAN3_GEAR = 0x2007; // FAN3档位（0/1/2/3/4/5/6）
const uint16_t INPUT_FAN4_GEAR = 0x2008; // FAN4档位（0/1/2/3/4/5/6）

// ========== 风机RPM寄存器（2009H-200CH，只读） ==========
const uint16_t INPUT_FAN1_RPM = 0x2009; // FAN1实时RPM
const uint16_t INPUT_FAN2_RPM = 0x200A; // FAN2实时RPM
const uint16_t INPUT_FAN3_RPM = 0x200B; // FAN3实时RPM
const uint16_t INPUT_FAN4_RPM = 0x200C; // FAN4实时RPM

// ========== RA1传感器数据寄存器（200DH-2010H，只读） ==========
const uint16_t INPUT_RA1_TEMPERATURE = 0x200D; // RA1温度（实际温度×10）
const uint16_t INPUT_RA1_HUMIDITY = 0x200E; // RA1湿度（0-100）
const uint16_t INPUT_RA1_PM25 = 0x200F; // RA1 PM2.5（ug/m³ 0-999）
const uint16_t INPUT_RA1_CO2 = 0x2010; // RA1 CO2（ppm 0-9999）

// ========== OA传感器数据寄存器（2011H-2014H，只读） ==========
const uint16_t INPUT_OA_TEMPERATURE = 0x2011; // OA温度（实际温度×10）
const uint16_t INPUT_OA_HUMIDITY = 0x2012; // OA湿度（0-100）
const uint16_t INPUT_OA_PM25 = 0x2013; // OA PM2.5（ug/m³ 0-999）
const uint16_t INPUT_OA_CO2 = 0x2014; // OA CO2（ppm 0-9999）

// ========== SA传感器数据寄存器（2015H-2018H，只读） ==========
const uint16_t INPUT_SA_TEMPERATURE = 0x2015; // SA温度（实际温度×10）
const uint16_t INPUT_SA_HUMIDITY = 0x2016; // SA湿度（0-100）
const uint16_t INPUT_SA_PM25 = 0x2017; // SA PM2.5（ug/m³ 0-999）
const uint16_t INPUT_SA_CO2 = 0x2018; // SA CO2（ppm 0-9999，实际400以上）

// ========== 空气质量寄存器（2019H-201AH，只读） ==========
const uint16_t INPUT_TVOC = 0x2019; // TVOC（mg/m³，实际数值/100）
const uint16_t INPUT_FORMALDEHYDE = 0x201A; // 甲醛（mg/m³，实际数值/100）

// ========== 系统状态寄存器（201BH-2023H，只读） ==========
const uint16_t INPUT_COMPRESSOR_FREQUENCY = 0x201B; // 压缩机运行频率（0-90Hz）
const uint16_t INPUT_AUX_HEAT_STATUS = 0x201C; // 电辅热状态（0x00:关闭 0x01:开启电辅热1 0x02:开启电辅热2 0x03:开启电辅热1、2）
const uint16_t INPUT_AUTO_CIRCULATION_DISPLAY = 0x201D; // 1007H在自动模式时内外循环显示（0:内循环 1:内循环/混风 2:全热新风/节能新风）
const uint16_t INPUT_INLET_TEMPERATURE = 0x201E; // 进风口温度（实际温度×10）
const uint16_t INPUT_INLET_HUMIDITY = 0x201F; // 进风口湿度（0-100）
const uint16_t INPUT_OUTLET_TEMPERATURE = 0x2020; // 出风口温度（预留，实际温度×10）
const uint16_t INPUT_OUTLET_HUMIDITY = 0x2021; // 出风口湿度（预留，0-100）
const uint16_t INPUT_HIGH_PRESSURE = 0x2022; // 高压压力值（bar，实际值/100，0-5000）
const uint16_t INPUT_LOW_PRESSURE = 0x2023; // 低压压力值（bar，实际值/100，0-5000）

// ========== 加湿浮子状态寄存器（2024H-2025H，只读） ==========
const uint16_t INPUT_INLET_FLOAT_STATUS = 0x2024; // 加湿进水水位浮子状态（Bit0/Bit1/Bit2）
const uint16_t INPUT_DRAIN_FLOAT_STATUS = 0x2025; // 加湿排水水位浮子状态（Bit0/Bit1/Bit2）

// ========== 运行时间寄存器（2026H-202AH，只读） ==========
const uint16_t INPUT_SYSTEM_RUNTIME_DAYS = 0x2026; // 系统运行（开机）时间（累计），单位：天（恢复出厂清零）
const uint16_t INPUT_FAN1_RUNTIME = 0x2027; // FAN1累计运转时间（小时，恢复出厂清零）
const uint16_t INPUT_FAN2_RUNTIME = 0x2028; // FAN2累计运转时间（小时，恢复出厂清零）
const uint16_t INPUT_FAN3_RUNTIME = 0x2029; // FAN3累计运转时间（小时，恢复出厂清零）
const uint16_t INPUT_FAN4_RUNTIME = 0x202A; // FAN4累计运转时间（小时，恢复出厂清零）

// ========== 压缩机温度与电压（202BH-202FH，只读，v1.22新增） ==========
const uint16_t INPUT_COMPRESSOR_DISCHARGE_TEMP = 0x202B; // 压缩机排气温度（实际温度×10）
const uint16_t INPUT_COMPRESSOR_SUCTION_TEMP = 0x202C; // 压缩机吸气温度（实际温度×10）
const uint16_t INPUT_EVAPORATOR_TEMP = 0x202D; // 蒸发器盘管温度（实际温度×10）
const uint16_t INPUT_RESERVED_TEMP = 0x202E; // 预留温度（实际温度×10）
const uint16_t INPUT_AC_VOLTAGE = 0x202F; // 交流电压检测值（待定）

// ========== 主控板版本时间字符串（2030H-203BH，只读） ==========
const uint16_t INPUT_VERSION_STRING_START = 0x2030; // Char[24]，不满填0x00（12个寄存器）

// ========== 离散输入寄存器（02功能码，起始地址3000H） ==========

// ========== 设备能力配置表（3000H-3001H，偏移0-7） ==========
const uint16_t DISCRET_CAPABILITY_START = 0x3000; // 能力配置表起始地址
const uint16_t DISCRET_CAPABILITY_HUMIDITY_MODULE = 0; // 有无加湿模块（0:无 1:有）
const uint16_t DISCRET_CAPABILITY_DEHUMIDIFICATION = 1; // 有无除湿模块
const uint16_t DISCRET_CAPABILITY_BYPASS_MODE = 2; // 有无(旁通/换气)模式
const uint16_t DISCRET_CAPABILITY_IEF = 3; // 有无IEF净化
const uint16_t DISCRET_CAPABILITY_DISINFECT = 4; // 有无消毒模块
const uint16_t DISCRET_CAPABILITY_ELECTRIC_HEATING = 5; // 有无电加热控制
const uint16_t DISCRET_CAPABILITY_FROST_PROTECTION = 6; // 有无防冻保护
const uint16_t DISCRET_CAPABILITY_HCHO = 7; // 有无甲醛HCHO

// ========== 设备状态表（3002H-3003H，偏移32-37） ==========
const uint16_t DISCRET_HUMIDIFICATION_PUMP_STATUS = 32; // 加湿循环泵状态
const uint16_t DISCRET_WATER_INLET_VALVE_STATUS = 33; // 加湿进水阀状态（0:关闭 1:开启）
const uint16_t DISCRET_DRAIN_PUMP_STATUS = 34; // 加湿排水泵状态
const uint16_t DISCRET_COMPRESSOR_STATUS = 35; // 压缩机状态
const uint16_t DISCRET_DEFROSTING = 36; // 除霜中（0未除霜 1正在除霜）
const uint16_t DISCRET_OFF_AIR_QUALITY_DETECTING = 37; // 关机状态下空气质量检测中（风阀开，风机转）

// ========== 故障码表（3004H，偏移64-76） ==========
const uint16_t DISCRET_FAULT_START = 64; // 故障码起始地址
const uint16_t DISCRET_FAULT_COUNT = 13; // 故障码位数（64-76）
const uint16_t DISCRET_FRESH_FAN_FAULT = 64; // 新风机异常
const uint16_t DISCRET_EXHAUST_FAN_FAULT = 65; // 排风机异常
const uint16_t DISCRET_BOOST_FAN_FAULT = 66; // 增压风机异常
const uint16_t DISCRET_RESERVED_67 = 67; // 待补充
const uint16_t DISCRET_HUMIDIFICATION_LOST = 68; // 加湿机通讯失联
const uint16_t DISCRET_INLET_FLOAT_ALARM = 69; // 加湿进水槽浮子警报
const uint16_t DISCRET_DRAIN_FLOAT_ALARM = 70; // 加湿排水槽浮子警报
const uint16_t DISCRET_DRAIN_FLOAT_NO_DROP = 71; // 加湿排水槽水位浮子排水后不下降
const uint16_t DISCRET_INLET_WATER_LOW = 72; // 加湿进水槽缺水
const uint16_t DISCRET_AUX_HEAT1_OVERCURRENT = 73; // 加湿电辅热1过流/过压保护
const uint16_t DISCRET_AUX_HEAT2_OVERCURRENT = 74; // 加湿电辅热2过流/过压保护
const uint16_t DISCRET_INLET_FLOAT_ABNORMAL = 75; // 加湿进水槽浮子有异常
const uint16_t DISCRET_DRAIN_FLOAT_ABNORMAL = 76; // 加湿排水槽浮子有异常

// ========== 寄存器读取范围定义 ==========
const uint16_t HOLDING_READ_START = 0x1000; // 保持寄存器读取起始地址
const uint16_t HOLDING_READ_COUNT = 0x0077; // 保持寄存器读取数量（1000H-1076H，119个）
const uint16_t INPUT_READ_START = 0x2000; // 输入寄存器读取起始地址
const uint16_t INPUT_READ_COUNT = 0x003C; // 输入寄存器读取数量（2000H-203BH，60个）
const uint16_t DISCRETE_READ_START = 0x3000; // 离散输入读取起始地址
const uint16_t DISCRETE_READ_COUNT = 0x004D; // 离散输入读取数量（3000H+0-76，77位）
}

// 4CP网关类
class BeiAng4CPGateway {
public:
    // readDeviceData() 的原始寄存器输出缓存，供上层缓存到 DataManager 中
    struct RawRegisterCache {
        static constexpr uint16_t HOLDING_COUNT = BeiAng4CPRegisters::HOLDING_READ_COUNT;  // 119
        static constexpr uint16_t INPUT_COUNT   = BeiAng4CPRegisters::INPUT_READ_COUNT;    // 60
        static constexpr uint16_t DISCRETE_COUNT = BeiAng4CPRegisters::DISCRETE_READ_COUNT; // 77
        static constexpr uint16_t DISCRETE_WORD_COUNT = 5;

        uint16_t holdingRegs[HOLDING_COUNT] = {0};
        uint16_t inputRegs[INPUT_COUNT]     = {0};
        uint8_t discreteInputs[DISCRETE_COUNT] = {0};
        uint16_t discreteWords[DISCRETE_WORD_COUNT] = {0};
        bool holdingValid = false;  // 保持寄存器读取成功
        bool inputValid   = false;  // 输入寄存器读取成功
        bool discreteValid = false; // 离散输入读取成功
    };
    explicit BeiAng4CPGateway(std::unique_ptr<CommunicationScheduler> scheduler,
                              const std::string& port, int baudRate = 9600,
                              char parity = 'N', int dataBits = 8, int stopBits = 1,
                              int responseTimeoutMs = MODBUS_RESPONSE_TIMEOUT_MS);
    ~BeiAng4CPGateway();

    // 每个真实 Modbus 事务成功后通知上层。回调用于刷新通信新鲜度，
    // 不参与协议解析，也不改变调度器的读写顺序。
    void setCommunicationSuccessCallback(std::function<void()> callback);

    // 初始化
    bool initialize();
    void shutdown();

    // 连接管理
    bool connect();
    void disconnect();
    bool reconnect(); // 断开并重建底层连接，用于通信失败后的自动恢复
    bool isConnected() const { return m_isConnected; }

    // 数据读取（使用正确的输入寄存器地址）
    // rawCache: 可选输出参数，读取成功时填充原始寄存器值，供上层缓存
    bool readDeviceData(GatewayGeneralDataStructure& data,
                        RawRegisterCache* rawCache = nullptr);
    // 快路径只采集原始寄存器；解析函数不接触串口，可由独立处理线程调用。
    // 环境数据(200DH-201AH)由周期采集的输入寄存器块(2000H-203BH)解析填充，
    // 无独立环境读取函数。
    bool readRawDeviceData(RawRegisterCache& rawCache);
    bool parseRawDeviceData(const RawRegisterCache& rawCache,
                            GatewayGeneralDataStructure& data);
    bool readManualModeData(ManualModeDataStructure& data);
    bool readSmartModeData(SmartModeDataStructure& data);

    // ========== 设备控制（根据协议文档v1.22） ==========

    // 总开关与模块开关
    bool setSwitchControl(bool on); // 1000H: 总开关
    bool setFreshAirModuleSwitch(bool on); // 1001H: 新风模块开关
    bool setSuperPureModeSwitch(bool on); // 1002H: 超净模式开关
    bool setHumidityModuleSwitch(bool on); // 1003H: 调湿模块开关
    bool setHumidification(bool on); // 1004H: 加湿开关
    bool setDehumidification(bool on); // 1005H: 除湿开关

    // 新风模块控制
    bool setLeaveHomeSwitch(bool on); // 1006H: 一键离家开关
    bool setRunMode(AirCirculationMode mode); // 1007H: 新风运行模式（0-5）
    bool setFanGear(int gear); // 1008H: 风量档位
    bool setExhaustFanGear(int gear); // 1009H: 排风风量档位（预留）

    // 整机运行模式与无极风量控制
    bool setWholeUnitRunMode(int mode); // 100AH: 整机运行模式（0:无/手动 1:标准 2:会客 3:干爽 4:温润 5:旅行）
    bool setSteplessFanControl(bool on); // 100BH: 无极风量控制开关
    bool setFreshFanDutyCycle(int duty); // 100CH: 新风风量占空比（0-100）
    bool setExhaustFanDutyCycle(int duty); // 100DH: 排风风量占空比（0-100）
    bool setBoostFanDutyCycle(int duty); // 100EH: 增压风风量占空比（0-100）

    // 环境目标设定
    bool setTargetHumidity(int humidity); // 100FH: 目标湿度（30-70）
    bool setTargetTemperature(int tempX10); // 1010H: 目标温度（160-310，实际设定温度×10）
    bool setPlasmaDisinfectSwitch(bool on); // 1011H: 等离子消毒开关
    bool setIEFPurification(bool on); // 1012H: IEF开关
    bool setAuxHeat(AuxHeatMode mode); // 1013H: 电辅热选择
    bool setHumidityIntensity(HumidityIntensity intensity); // 1014H: 加湿/除湿强度
    bool setSAFanRatio(float ratio); // 1015H: SA风量与增压风机比例设定

    // RTC时间设置(101BH-101FH打包5寄存器)由 HTTP 层 handleSetRTCTimeApi 直接
    // submitMultipleWrite 下发, 网关层不再保留独立写函数。

    // 定时/延时与设备地址
    bool setFanDelayOffTime(int minutes); // 1020H: 延时关风机
    bool setHumidificationPumpOnTime(int seconds); // 1021H: 加湿循环泵开时间
    bool setHumidificationPumpOffTime(int seconds); // 1022H: 加湿循环泵关时间
    bool setHumidificationDrainOnTime(int seconds); // 1023H: 加湿排水开时间
    bool setDeviceAddress(uint8_t address); // 1024H: 设备地址（0-254）
    bool setOffAirQualityDetectSwitch(bool on); // 1025H: 关机状态下空气品质检测开关
    bool setOffAirQualityDetectInterval(int minutes); // 1026H: 关机状态下空气品质检测间隔时间
    bool setOffAirQualityDetectRuntime(int minutes); // 1027H: 关机状态下空气品质检测运行时间

    // 压缩机与高低压开关（1028H-102CH）
    bool setCompressorEEVOpening(int opening); // 1028H: 电子膨胀阀开度（0-500）
    bool setCompressorFrequencySet(int freq); // 1029H: 运行频率设定值（0-90）
    bool setCompressorFrequencyMax(int freq); // 102AH: 频率上限设定值（60-95）
    bool setHighPressureSwitch(bool on); // 102BH: 高压开关（仅厂测模式）
    bool setLowPressureSwitch(bool on); // 102CH: 低压开关（仅厂测模式）

    // 厂测模式与滤网保养
    bool setFactoryTestMode(bool testMode); // 1030H: 厂测模式（true写100:测试模式，false写0:正常运行）
    bool setFilter1RemainingTime(int hours); // 1031H: 初效滤网1
    bool setFilter2RemainingTime(int hours); // 1032H: 中效滤网2
    bool setFilter3RemainingTime(int hours); // 1033H: 高效滤网3
    bool setHumidityFilterRemainingTime(int hours); // 1034H: 加湿模块
    bool setIEFCleanRemainingTime(int hours); // 1035H: IEF需清洗
    bool setWholeUnitMaintenanceTime(int days); // 1036H: 整机保养

    // 厂测设定（1038H-103EH，设备侧仅厂测模式接受写入）
    bool setFanCurrentSetting(int fanIndex, uint16_t value); // 1038H-103BH: 当前FAN1-4风量设定值
    bool setValveStatusSetting(int valveIndex, ValveStatus status); // 103CH-103EH: 阀门1-3状态设定

    // 维护操作
    bool clearAllFanRuntime(); // 103FH: 清除所有风机累计运转时间
    bool restoreFactorySettings(); // 1040H: 恢复出厂

    // 风机内外循环各档风量设定（1041H-1070H，v1.22新增）
    // fanIndex: 1-4；external: true外循环 false内循环；gear: 1-6
    bool setFanGearFlowSetting(int fanIndex, bool external, int gear, uint16_t value);

    // 风阀设定（1071H-1076H，v1.22新增）
    bool setDamperDirectionSetting(int damperIndex, uint16_t direction); // 0/1
    bool setDamperStepsSetting(int damperIndex, uint16_t steps);

    // ========== 兼容旧接口（映射到v1.22寄存器） ==========
    bool setPowerOn(bool on); // 映射到 1000H 总开关
    bool setFanSpeed(int level); // 映射到 1008H 风量档位
    bool setHumidityControlSwitch(bool on); // 映射到 1003H 调湿模块开关

    // ========== 02H功能码：离散输入读取 ==========
    bool readDiscreteInputs(uint16_t startAddr, uint16_t count, uint8_t* values);
    bool readCapabilityFlags(uint8_t* values); // 读取设备能力标志（3000H+0-15）
    bool readHumidificationStatus(uint8_t* values); // 读取设备状态（3000H+32-47）
    bool readFaultCodes(uint8_t* values); // 读取故障码（3000H+64-76）

    // 新增：读取完整设备能力信息
    bool hasHumidificationModule(); // 是否有加湿模块
    bool hasDehumidification(); // 是否有除湿模块
    bool hasBypassMode(); // 是否有旁通/换气模式
    bool hasIEFPurification(); // 是否有IEF净化
    bool hasFormaldehydeSensor(); // 是否有甲醛HCHO检测

    // 新增：故障检查方法
    bool checkFreshAirFanFault(); // 检查新风机故障
    bool checkExhaustFanFault(); // 检查排风机故障
    bool checkBoostFanFault(); // 检查增压风机故障
    std::vector<std::string> getAllFaults(); // 获取所有故障描述

    // 04H功能码：输入寄存器读取
    bool readInputRegisters(uint16_t startAddr, uint16_t count, uint16_t* registers);
    bool readBasicDeviceInfo(uint16_t* registers); // 读取基础设备信息（2000H-2003H）
    bool readFanStatus(uint16_t* registers); // 读取风机档位状态（2004H-2008H）
    bool readAllSensorData(uint16_t* registers); // 读取所有传感器数据（200DH-201AH）

    // 10H功能码：写多个寄存器
    bool writeMultipleRegisters(uint16_t startAddr, uint16_t count, const uint16_t* values);
    bool submitHoldingRegisterWrite(uint16_t address, uint16_t value,
        CommunicationScheduler::Completion completion = CommunicationScheduler::Completion());
    bool submitMultipleRegisterWrite(uint16_t startAddr,
        std::vector<uint16_t> values,
        CommunicationScheduler::Completion completion = CommunicationScheduler::Completion());
    using HoldingReadCompletion =
        std::function<void(bool, const std::vector<uint16_t>&)>;
    bool submitHoldingRegisterRead(uint16_t startAddr, uint16_t count,
        HoldingReadCompletion completion);
    std::size_t pendingWriteCount() const;

    // 将完整保持寄存器镜像填入业务结构。该函数只做内存转换，
    // 供周期全量解析和写后局部确认读共用同一份字段映射。
    static void applyHoldingRegisterData(const uint16_t* holdingRegs,
        GatewayGeneralDataStructure& data);

    // 地址设置
    void setSlaveId(uint8_t slaveId) { m_slaveId = slaveId; }
    uint8_t getSlaveId() const { return m_slaveId; }

    // 状态获取
    DeviceStatus getDeviceStatus() const { return m_deviceStatus; }
    std::string getLastErrorMessage() const { return m_lastError; }

    // 最近一次 connect() 失败的 errno（供上层判断失败性质）
    int getLastConnectErrno() const { return m_lastConnectErrno; }
    // 判断最近一次连接失败是否为"串口节点消失类"错误（节点不存在/IO错误），
    // 这类错误下 node 可能瞬时不可用，高频重连无意义，应退避等待节点恢复
    bool isSerialNodeMissing() const {
        return m_lastConnectErrno == ENOENT || m_lastConnectErrno == EIO;
    }

    // 通用寄存器读取（用于工程模式和调试）
    bool readHoldingRegister(uint16_t address, uint16_t count, uint16_t* values);
    bool readInputRegister(uint16_t address, uint16_t count, uint16_t* values);
    bool readDiscreteInput(uint16_t address, uint16_t count, uint8_t* values);

    // 通用寄存器写入（用于工程模式和调试）
    bool writeHoldingRegister(uint16_t address, uint16_t value);

private:
    bool connectDirect();
    void disconnectDirect();

    // Modbus通信功能码实现
    bool readHoldingRegisters(uint16_t startAddr, uint16_t count, uint16_t* registers); // 03H
    bool readInputRegistersInternal(uint16_t startAddr, uint16_t count, uint16_t* registers); // 04H
    bool readDiscreteInputsInternal(uint16_t startAddr, uint16_t count, uint8_t* values); // 02H
    bool writeSingleRegister(uint16_t addr, uint16_t value); // 06H
    bool writeSingleRegisterDirect(uint16_t addr, uint16_t value);
    bool writeMultipleRegistersInternal(uint16_t startAddr, uint16_t count, const uint16_t* values); // 10H
    bool writeMultipleRegistersDirect(uint16_t startAddr, uint16_t count, const uint16_t* values);
    bool executeRead(CommunicationScheduler::Operation operation);
    bool executeWrite(CommunicationScheduler::Operation operation);
    CommunicationScheduler::Operation notifyOnSuccess(
        CommunicationScheduler::Operation operation);
    void prepareRtuTransaction();
    void recoverRtuAfterFailure(int errorCode);

    // 数据转换辅助函数
    float temperatureFromRegister(uint16_t regValue); // 从寄存器值转换温度
    uint16_t temperatureToRegister(float temp); // 从温度转换到寄存器值
    uint16_t dutyCycleToRegister(int duty); // 占空比转换

    // 由进程定义选择的通信调度器；Gateway 只消费统一接口。
    std::unique_ptr<CommunicationScheduler> m_scheduler;

    // libmodbus 上下文，只允许 scheduler 工作线程或启停阶段访问
    modbus_t* m_modbus;

    // 状态
    bool m_isConnected;
    DeviceStatus m_deviceStatus;
    uint8_t m_slaveId; // 从站地址
    std::string m_lastError;
    int m_lastConnectErrno = 0; // 最近一次 connect() 失败时的 errno；连接成功后复位为 0

    // 串口配置
    std::string m_port;
    int m_baudRate;
    char m_parity;      // 奇偶校验: 'N'=无, 'E'=偶, 'O'=奇
    int m_dataBits;     // 数据位: 7 或 8
    int m_stopBits;     // 停止位: 1 或 2
    int m_responseTimeoutMs; // 等待响应/帧内字节超时（毫秒）

    // 重试配置
    int m_maxRetryCount;

    std::function<void()> m_communicationSuccessCallback;
};

#endif // BEIANG4CPGATEWAY_H
