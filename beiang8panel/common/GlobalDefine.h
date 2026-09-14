/**
 * 全局定义和宏
 */

#ifndef GLOBALDEFINE_H
#define GLOBALDEFINE_H

#include "BuildConfig.h"  // 编译期宏(BEIANG_NATIVE_BUILD 等)，由 CMake 生成

// 版本信息
// 1.4.3: MemoryWatchModule 低内存重启 Flutter 的命令去掉 -r 90 软件旋转——
//        屏幕旋转已由内核 fb_g2d_rot(G2D 硬件)统一接管(dts disp_rotation_used),
//        保留 -r 90 会导致重启后 UI 双重旋转
// 1.4.2: 新增 GET /api/device/air-conditioner/presence 与
//        /api/device/floor-heating/presence(裸对象 {"hasAirConditioner":false}/
//        {"hasFloorHeating":false}, 产品级静态值); /api/device/capabilities
//        data 补充 hasAirConditioner/hasFloorHeating 两字段(静态false);
//        4CP仅含新风/调湿/超净, 无空调无地暖, 协议v1.22离散能力表亦无此两位
// 1.4.1: 新增内存水位监控 MemoryWatchModule: 周期读 /proc/meminfo MemAvailable,
//        三级阈值处置(告警日志 64MB/重启Flutter 32MB/重启设备 16MB, 连续3次命中
//        才动作, 重启App后300s冷却内仍低则升级重启设备; OTA进行中抑制动作;
//        PVR约束: 只SIGTERM不kill -9); 新增 GET /api/memwatch/status
// 1.4.0: 新增历史趋势: HistoryRecorder 周期采样输入寄存器 200DH-2014H
//        (室内/外温湿/PM2.5/CO2, 只读缓存)落盘 UDISK 日文件(18B/样本,
//        fdatasync, 保留370天); 新增 GET /api/history/trend?range=day|week|month
//        [+&date=YYYY-MM-DD] 返回 wrapped 桶序列(空桶null)与
//        GET /api/history/status 诊断; 移除未实现桩 /api/history/data;
//        设计文档 docs/历史趋势数据存储与接口设计.md
// 1.3.11: 新增 GET /api/device/factory-test/status 返回 1030H 厂测模式
//         (裸对象 {"factoryTestMode":N,"factoryTestActive":N==100})
// 1.3.10: 新增 GET /api/device/unit-run-mode/status 返回 100AH 整机运行模式缓存值
//         (裸对象 {"wholeUnitRunMode":0-5}); 记录100AH设备端场景异步落位现象
// 1.3.9: 新增 GET /api/device/leave-home/status 返回 1006H 一键离家开关缓存值
//        (裸对象 {"leaveHomeOn":bool}, 与 super-pure/status 同款)
// 1.3.8: /api/rtc/time POST 新增 format 参数(0=24h默认/1=12h, 时间仍按24h传入,
//        12h打包(1-12+bit7=PM)由后端换算); 严格日历校验(非法日期如2-30拒绝且不写
//        寄存器); GET 在12h制下归一为24h输出并附 meridiem
// 1.3.7: 删除网关层遗留死代码 setRTCTime()(无调用方, HTTP层 handleSetRTCTimeApi
//        直接 submitMultipleWrite 下发 101BH-101FH 打包5寄存器)
// 1.3.6: 删除遗留死代码 BeiAng4CPGateway::readEnvironmentData()(无调用方,
//        且TVOC/甲醛不做÷100换算易误导); 环境数据统一走周期采集04H块解析
// 1.3.5: 模块开关改单写——互斥联动(开新风→设备关超净; 开超净→设备关新风/调湿;
//        开调湿→设备关超净)由4CP设备端自动执行；后端写后读回反映设备实际状态。
// 1.3.4: 1008H 风速可写条件收紧为白名单 1007H∈{0,1,2,4}(与规格原文一致, 防御越界读回值)
// 1.3.3: /api/freshair/status 按规格返回 6 寄存器(新增 100CH 新风占空比, 移除 1006H/201DH)
// 1.3.2: libhv 日志固定到 /mnt/UDISK/logs/libhv.log+1M截断; emc6069 网络状态变化才记录
// 1.3.1: 背光亮度直传 0-255 给 DISP_LCD_SET_BRIGHTNESS(原 0-100 换算导致满亮度正占空比 60% 而非 0%)
#define BEIANG_8PANEL_VERSION "1.4.3"
#define BEIANG_8PANEL_BUILD_DATE __DATE__
#define BEIANG_8PANEL_BUILD_TIME __TIME__
#define PROTOCOL_VERSION "V1.22"  // 4CP/全热新风/新风除湿通讯协议版本

// 产品级模块有无(非协议寄存器, 面板固件静态事实; 换机型只需改这里)
// 4CP 仅含 新风/调湿/超净 三项, 无空调、无地暖
#define BEIANG_PRODUCT_HAS_AIR_CONDITIONER 0
#define BEIANG_PRODUCT_HAS_FLOOR_HEATING 0

// Modbus功能码定义
#define MODBUS_FUNC_READ_HOLDING_REGISTERS 0x03    // 读保持寄存器
#define MODBUS_FUNC_WRITE_SINGLE_REGISTER 0x06     // 写单个寄存器
#define MODBUS_FUNC_WRITE_MULTIPLE_REGISTERS 0x10  // 写多个寄存器
#define MODBUS_FUNC_READ_INPUT_REGISTERS 0x04      // 读输入寄存器
#define MODBUS_FUNC_READ_DISCRETE_INPUTS 0x02       // 读离散输入

// Modbus寄存器地址定义
#define REG_HOLDING_START_ADDR 0x1000              // 保持寄存器起始地址
#define REG_INPUT_START_ADDR 0x2000                // 输入寄存器起始地址
#define REG_DISCRETE_INPUT_START_ADDR 0x3000       // 离散输入起始地址

// 保持寄存器地址偏移 (相对于0x1000，协议v1.22)
#define REG_OFFSET_SWITCH_CONTROL 0x0000           // 总开关
#define REG_OFFSET_FRESH_AIR_MODULE_SWITCH 0x0001  // 新风模块开关
#define REG_OFFSET_SUPER_PURE_MODE_SWITCH 0x0002   // 超净模式开关
#define REG_OFFSET_HUMIDITY_MODULE_SWITCH 0x0003   // 调湿模块开关
#define REG_OFFSET_HUMIDIFIER 0x0004               // 加湿开关
#define REG_OFFSET_DEHUMIDIFIER 0x0005             // 除湿开关
#define REG_OFFSET_LEAVE_HOME_SWITCH 0x0006        // 一键离家开关（0:关闭 1:开启）
#define REG_OFFSET_OPERATION_MODE 0x0007           // 新风运行模式（0-5）
#define REG_OFFSET_FAN_GEAR 0x0008                 // 风量档位（1001H开启且1007H为0/1/2/4时可写）
#define REG_OFFSET_EXHAUST_FAN_GEAR 0x0009         // 排风风量档位(预留)
#define REG_OFFSET_WHOLE_UNIT_RUN_MODE 0x000A      // 整机运行模式（0-5）
#define REG_OFFSET_STEPLESS_FAN_CTRL 0x000B        // 无极风量控制开关
#define REG_OFFSET_FRESH_AIR_DUTY 0x000C           // 新风风量占空比
#define REG_OFFSET_EXHAUST_AIR_DUTY 0x000D         // 排风风量占空比
#define REG_OFFSET_BOOST_AIR_DUTY 0x000E           // 增压风风量占空比
#define REG_OFFSET_TARGET_HUMIDITY 0x000F          // 目标湿度设定(30-70)
#define REG_OFFSET_TARGET_TEMP 0x0010              // 目标温度设定(160-310, 实际×10)
#define REG_OFFSET_PLASMA_DISINFECT 0x0011         // 等离子消毒开关
#define REG_OFFSET_IEF 0x0012                      // IEF开关
#define REG_OFFSET_AUX_HEAT 0x0013                 // 电辅热选择
#define REG_OFFSET_HUMIDITY_INTENSITY 0x0014       // 加湿/除湿强度设定
#define REG_OFFSET_SA_FAN_RATIO 0x0015             // SA风量与增压风机比例设定
#define REG_OFFSET_RTC_START 0x001B                // Set RTC起始地址（1016H-101AH预留）
#define REG_OFFSET_RTC_END 0x001F                  // Set RTC结束地址
#define REG_OFFSET_FAN_DELAY_OFF_TIME 0x0020       // 关机后延时关风机时间
#define REG_OFFSET_HUMIDIFIER_PUMP_ON_TIME 0x0021  // 加湿循环泵开时间
#define REG_OFFSET_HUMIDIFIER_PUMP_OFF_TIME 0x0022 // 加湿循环泵关时间
#define REG_OFFSET_HUMIDIFIER_DRAIN_ON_TIME 0x0023 // 加湿排水开时间
#define REG_OFFSET_DEVICE_ADDRESS 0x0024           // 设备地址(0-254)
#define REG_OFFSET_OFF_AIR_QUALITY_DETECT 0x0025   // 关机状态下空气品质检测开关
#define REG_OFFSET_OFF_AIR_QUALITY_INTERVAL 0x0026 // 关机状态下空气品质检测间隔时间
#define REG_OFFSET_OFF_AIR_QUALITY_RUN_TIME 0x0027 // 关机状态下空气品质检测运行时间
#define REG_OFFSET_COMPRESSOR_EEV_OPENING 0x0028   // 压缩机电子膨胀阀开度(0-500)
#define REG_OFFSET_COMPRESSOR_FREQ_SET 0x0029      // 压缩机运行频率设定值(0-90Hz)
#define REG_OFFSET_COMPRESSOR_FREQ_MAX 0x002A      // 压缩机频率上限设定值(60-95Hz)
#define REG_OFFSET_HIGH_PRESSURE_SWITCH 0x002B     // 高压开关（仅厂测模式可写）
#define REG_OFFSET_LOW_PRESSURE_SWITCH 0x002C      // 低压开关（仅厂测模式可写）
#define REG_OFFSET_FACTORY_TEST_MODE 0x0030        // 厂测模式（100:测试模式）
#define REG_OFFSET_FILTER1_REMAINING_TIME 0x0031   // 初效滤网1剩余时间
#define REG_OFFSET_FILTER2_REMAINING_TIME 0x0032   // 中效滤网2剩余时间
#define REG_OFFSET_FILTER3_REMAINING_TIME 0x0033   // 高效滤网3剩余时间
#define REG_OFFSET_HUMIDITY_MODULE_TIME 0x0034     // 加湿模块剩余时间
#define REG_OFFSET_IEF_CLEAN_TIME 0x0035           // IEF需清洗剩余时间
#define REG_OFFSET_MAINTENANCE_TIME 0x0036         // 整机保养剩余时间
#define REG_OFFSET_FAN1_CURRENT_SETTING 0x0038     // 当前FAN1风量设定值（仅厂测）
#define REG_OFFSET_FAN2_CURRENT_SETTING 0x0039     // 当前FAN2风量设定值（仅厂测）
#define REG_OFFSET_FAN3_CURRENT_SETTING 0x003A     // 当前FAN3风量设定值（仅厂测）
#define REG_OFFSET_FAN4_CURRENT_SETTING 0x003B     // 当前FAN4风量设定值（仅厂测）
#define REG_OFFSET_VALVE1_STATUS_SET 0x003C        // 阀门1状态设定（仅厂测）
#define REG_OFFSET_VALVE2_STATUS_SET 0x003D        // 阀门2状态设定（仅厂测）
#define REG_OFFSET_VALVE3_STATUS_SET 0x003E        // 阀门3状态设定（仅厂测）
#define REG_OFFSET_CLEAR_ALL_FAN_RUNTIME 0x003F    // 清除所有风机累计运转时间(写1)
#define REG_OFFSET_FACTORY_RESET 0x0040            // 恢复出厂(写1)
#define REG_OFFSET_FAN1_EXTERNAL_GEAR1_FLOW 0x0041 // FAN1外循环1档风量设定值
#define REG_OFFSET_FAN1_INTERNAL_GEAR1_FLOW 0x0047 // FAN1内循环1档风量设定值
#define REG_OFFSET_FAN2_EXTERNAL_GEAR1_FLOW 0x004D // FAN2外循环1档风量设定值
#define REG_OFFSET_FAN2_INTERNAL_GEAR1_FLOW 0x0053 // FAN2内循环1档风量设定值
#define REG_OFFSET_FAN3_EXTERNAL_GEAR1_FLOW 0x0059 // FAN3外循环1档风量设定值
#define REG_OFFSET_FAN3_INTERNAL_GEAR1_FLOW 0x005F // FAN3内循环1档风量设定值
#define REG_OFFSET_FAN4_EXTERNAL_GEAR1_FLOW 0x0065 // FAN4外循环1档风量设定值
#define REG_OFFSET_FAN4_INTERNAL_GEAR1_FLOW 0x006B // FAN4内循环1档风量设定值
#define REG_OFFSET_DAMPER1_DIRECTION_SET 0x0071    // 风阀1方向设定(0/1)
#define REG_OFFSET_DAMPER2_DIRECTION_SET 0x0072    // 风阀2方向设定(0/1)
#define REG_OFFSET_DAMPER3_DIRECTION_SET 0x0073    // 风阀3方向设定(0/1)
#define REG_OFFSET_DAMPER1_STEPS_SET 0x0074        // 风阀1运行步数设定
#define REG_OFFSET_DAMPER2_STEPS_SET 0x0075        // 风阀2运行步数设定
#define REG_OFFSET_DAMPER3_STEPS_SET 0x0076        // 风阀3运行步数设定

// 输入寄存器地址偏移 (相对于0x2000，协议v1.22)
#define REG_INPUT_OFFSET_FACTORY_FLAG 0x0000      // 工厂标志
#define REG_INPUT_OFFSET_DEVICE_MODEL 0x0001      // 机型
#define REG_INPUT_OFFSET_VERSION 0x0002            // 版本（除以100，0101=1.01）
#define REG_INPUT_OFFSET_MAX_FAN_GEAR_FRESH 0x0003 // 新风模式风量最大档位
#define REG_INPUT_OFFSET_MAX_FAN_GEAR_RECIRC 0x0004 // 内循环/混风模式风量最大档位
#define REG_INPUT_OFFSET_FAN1_GEAR 0x0005         // FAN1档位
#define REG_INPUT_OFFSET_FAN2_GEAR 0x0006         // FAN2档位
#define REG_INPUT_OFFSET_FAN3_GEAR 0x0007         // FAN3档位
#define REG_INPUT_OFFSET_FAN4_GEAR 0x0008         // FAN4档位
#define REG_INPUT_OFFSET_FAN1_RPM 0x0009           // FAN1实时rpm
#define REG_INPUT_OFFSET_FAN2_RPM 0x000A           // FAN2实时rpm
#define REG_INPUT_OFFSET_FAN3_RPM 0x000B           // FAN3实时rpm
#define REG_INPUT_OFFSET_FAN4_RPM 0x000C           // FAN4实时rpm
#define REG_INPUT_OFFSET_RA1_TEMP 0x000D          // RA1温度
#define REG_INPUT_OFFSET_RA1_HUMIDITY 0x000E      // RA1湿度
#define REG_INPUT_OFFSET_RA1_PM25 0x000F          // RA1 PM2.5（ug/m³ 0-999）
#define REG_INPUT_OFFSET_RA1_CO2 0x0010           // RA1 CO2（ppm 0-9999）
#define REG_INPUT_OFFSET_OA_TEMP 0x0011           // OA温度
#define REG_INPUT_OFFSET_OA_HUMIDITY 0x0012       // OA湿度
#define REG_INPUT_OFFSET_OA_PM25 0x0013           // OA PM2.5（ug/m³ 0-999）
#define REG_INPUT_OFFSET_OA_CO2 0x0014            // OA CO2（ppm 0-9999）
#define REG_INPUT_OFFSET_SA_TEMP 0x0015           // SA温度
#define REG_INPUT_OFFSET_SA_HUMIDITY 0x0016       // SA湿度
#define REG_INPUT_OFFSET_SA_PM25 0x0017           // SA PM2.5（ug/m³ 0-999）
#define REG_INPUT_OFFSET_SA_CO2 0x0018            // SA CO2（ppm 0-9999）
#define REG_INPUT_OFFSET_TVOC 0x0019              // TVOC（mg/m³，实际数值/100）
#define REG_INPUT_OFFSET_FORMALDEHYDE 0x001A      // 甲醛（mg/m³，实际数值/100）
#define REG_INPUT_OFFSET_COMPRESSOR_FREQUENCY 0x001B // 压缩机运行频率(0-90Hz)
#define REG_INPUT_OFFSET_AUX_HEAT_STATUS 0x001C   // 电辅热状态
#define REG_INPUT_OFFSET_AUTO_CIRCULATION_DISPLAY 0x001D // 1007H自动模式时内外循环显示(0/1/2)
#define REG_INPUT_OFFSET_INLET_TEMP 0x001E        // 进风口温度（实际温度×10）
#define REG_INPUT_OFFSET_INLET_HUMIDITY 0x001F    // 进风口湿度
#define REG_INPUT_OFFSET_OUTLET_TEMP 0x0020       // 出风口温度（预留）
#define REG_INPUT_OFFSET_OUTLET_HUMIDITY 0x0021   // 出风口湿度（预留）
#define REG_INPUT_OFFSET_HIGH_PRESSURE 0x0022     // 高压压力值（bar，实际值/100，0-5000）
#define REG_INPUT_OFFSET_LOW_PRESSURE 0x0023      // 低压压力值（bar，实际值/100，0-5000）
#define REG_INPUT_OFFSET_HUMIDIFIER_WATER_FLOAT 0x0024   // 加湿进水水位浮子状态
#define REG_INPUT_OFFSET_HUMIDIFIER_DRAIN_FLOAT 0x0025   // 加湿排水水位浮子状态
#define REG_INPUT_OFFSET_SYSTEM_RUNTIME_DAYS 0x0026 // 系统运行（开机）时间（天）
#define REG_INPUT_OFFSET_FAN1_RUNTIME 0x0027      // FAN1累计运转时间
#define REG_INPUT_OFFSET_FAN2_RUNTIME 0x0028      // FAN2累计运转时间
#define REG_INPUT_OFFSET_FAN3_RUNTIME 0x0029      // FAN3累计运转时间
#define REG_INPUT_OFFSET_FAN4_RUNTIME 0x002A      // FAN4累计运转时间
#define REG_INPUT_OFFSET_COMPRESSOR_DISCHARGE_TEMP 0x002B // 压缩机排气温度（实际温度×10）
#define REG_INPUT_OFFSET_COMPRESSOR_SUCTION_TEMP 0x002C   // 压缩机吸气温度（实际温度×10）
#define REG_INPUT_OFFSET_EVAPORATOR_TEMP 0x002D   // 蒸发器盘管温度（实际温度×10）
#define REG_INPUT_OFFSET_RESERVED_TEMP 0x002E     // 预留温度（实际温度×10）
#define REG_INPUT_OFFSET_AC_VOLTAGE 0x002F        // 交流电压检测值（待定）
#define REG_INPUT_OFFSET_VERSION_STRING_START 0x0030 // 主控板版本时间字符串Char[24]（2030H-203BH）

// 离散输入地址偏移 (相对于0x3000，协议v1.22)
#define REG_DISCRETE_OFFSET_HAS_HUMIDITY_MODULE 0  // 有无加湿模块
#define REG_DISCRETE_OFFSET_HAS_DEHUMIDIFIER 1     // 有无除湿模块
#define REG_DISCRETE_OFFSET_HAS_BYPASS_MODE 2      // 有无(旁通/换气)模式
#define REG_DISCRETE_OFFSET_HAS_IEF 3              // 有无IEF净化
#define REG_DISCRETE_OFFSET_HAS_DISINFECT 4        // 有无消毒模块
#define REG_DISCRETE_OFFSET_HAS_ELECTRIC_HEATING 5 // 有无电加热控制
#define REG_DISCRETE_OFFSET_HAS_FROST_PROTECTION 6 // 有无防冻保护
#define REG_DISCRETE_OFFSET_HAS_HCHO 7             // 有无甲醛HCHO
#define REG_DISCRETE_OFFSET_HUMIDIFIER_PUMP_STATUS 32  // 加湿循环泵状态
#define REG_DISCRETE_OFFSET_HUMIDIFIER_WATER_STATUS 33  // 加湿进水阀状态
#define REG_DISCRETE_OFFSET_HUMIDIFIER_DRAIN_STATUS 34  // 加湿排水泵状态
#define REG_DISCRETE_OFFSET_COMPRESSOR_STATUS 35        // 压缩机状态
#define REG_DISCRETE_OFFSET_OFF_AQ_DETECTING 37         // 关机状态下空气质量检测中（风阀开，风机转）

// 故障码地址偏移 (离散输入，从64开始，协议v1.22)
#define REG_DISCRETE_OFFSET_FAULT_FRESH_AIR_FAN 64     // 新风机异常
#define REG_DISCRETE_OFFSET_FAULT_EXHAUST_FAN 65        // 排风机异常
#define REG_DISCRETE_OFFSET_FAULT_BOOST_FAN 66          // 增压风机异常
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_COMM 68    // 加湿机通讯失联
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_INLET_FLOAT 69 // 加湿进水槽浮子警报
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_DRAIN_FLOAT 70 // 加湿排水槽浮子警报
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_DRAIN_NOT_DROP 71 // 加湿排水槽水位浮子排水后不下降
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_NO_WATER 72      // 加湿进水槽缺水
#define REG_DISCRETE_OFFSET_FAULT_AUX_HEAT1_OVERCURRENT 73    // 加湿电辅热1过流/过压保护
#define REG_DISCRETE_OFFSET_FAULT_AUX_HEAT2_OVERCURRENT 74    // 加湿电辅热2过流/过压保护
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_INLET_FLOAT_ABNORMAL 75 // 加湿进水槽浮子有异常
#define REG_DISCRETE_OFFSET_FAULT_HUMIDIFIER_DRAIN_FLOAT_ABNORMAL 76 // 加湿排水槽浮子有异常

// Modbus通讯配置
#define MODBUS_MAX_REGISTER_COUNT 125
#define MODBUS_RESPONSE_TIMEOUT_MS 50      // 协议v1.22建议超时时间50ms
#define MODBUS_COMMAND_INTERVAL_MS 250     // 协议v1.22建议通讯命令间隔≥250ms
#define DEFAULT_DEVICE_ADDRESS_4CP 209     // 4CP设备默认地址 (0xD1)
#define DEFAULT_DEVICE_ADDRESS_HEAT 193   // 全热新风设备默认地址 (0xC1)

// 数据转换宏定义（根据协议文档v1.22）
#define TEMP_TO_RAW(temp) ((int16_t)((temp) * 10))           // 温度转换为raw值 (实际温度*10)
#define RAW_TO_TEMP(raw) ((raw) / 10.0f)                    // raw值转换为温度
#define TEMP_KELVIN_TO_RAW(temp_k) ((int16_t)((temp_k) * 10 + 2730)) // 开尔文温度转raw值 (实际温度*10+2730，v1.20遗留)
#define RAW_TO_TEMP_KELVIN(raw) ((raw) - 2730) / 10.0f       // raw值转开尔文温度
#define HUMIDITY_TO_RAW(hum) ((uint16_t)(hum))               // 湿度转换为raw值 (0-100)
#define RAW_TO_HUMIDITY(raw) (raw)                           // raw值转换为湿度
#define RATIO_TO_RAW(ratio) ((uint16_t)((ratio) * 10))       // 比例转换为raw值 (实际值*10)
#define RAW_TO_RATIO(raw) ((raw) / 10.0f)                    // raw值转换为比例
#define PRESSURE_TO_RAW(bar) ((uint16_t)((bar) * 100))       // 压力转换为raw值 (实际值*100)
#define RAW_TO_PRESSURE(raw) ((raw) / 100.0f)                // raw值转换为压力(bar)
#define TVOC_TO_RAW(mg) ((uint16_t)((mg) * 100))             // TVOC/甲醛转换为raw值 (实际数值/100)
#define RAW_TO_TVOC(raw) ((raw) / 100.0f)                    // raw值转换为TVOC/甲醛(mg/m³)

// 串口配置
// 默认串口按编译目标区分：native(x86_64 调试) 使用 USB 转串口 /dev/ttyUSB0，
// arm64 板端使用硬件串口 /dev/ttyS2。配置文件中的 port 可覆盖此默认值。
#ifdef BEIANG_NATIVE_BUILD
#define DEFAULT_SERIAL_PORT "/dev/ttyUSB0"
#else
#define DEFAULT_SERIAL_PORT "/dev/ttyS2"
#endif
#define DEFAULT_SERIAL_BAUDRATE 9600
#define DEFAULT_SERIAL_DATABITS 8
#define DEFAULT_SERIAL_STOPBITS 1
#define DEFAULT_SERIAL_PARITY 'N'

// HTTP配置（重命名避免与libhv冲突）
#define DEFAULT_HTTP_HOST "0.0.0.0"
#define BEIANG_HTTP_PORT 8080
#define HTTP_MAX_CONNECTIONS 100
#define HTTP_REQUEST_TIMEOUT_MS 30000

// 数据采集配置
#define DEFAULT_DATA_ACQUISITION_INTERVAL_MS 1000
#define MAX_DATA_ACQUISITION_FAILURE_COUNT 5

// 重连退避配置（串口节点消失时，高频重连无意义，按指数退避等待节点恢复）
#define RECONNECT_BACKOFF_BASE_MS 5000      // 退避基础间隔（默认采集间隔×失败阈值）
#define RECONNECT_BACKOFF_MAX_MS 60000      // 退避上限（60s）

// 故障爆发期轮询降频配置（总线冲突/干扰时，高频轮询会加剧总线碰撞，
// 连续失败时逐步拉长轮询间隔让总线喘息）
#define DATA_ACQUISITION_POLL_BACKOFF_MAX_MS 10000  // 轮询降频上限（10s）
#define POLL_BACKOFF_RECOVER_STREAK 3              // 恢复迟滞：连续 N 次"干净成功"才降一档，
                                                   // 避免故障间歇期的单次侥幸成功过早取消降频

// 定时任务配置
#define MAX_SCHEDULED_TASKS 50
#define SCHEDULE_CHECK_INTERVAL_MS 100

// 日志级别
enum class LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    FATAL = 4
};

// 设备状态
enum class DeviceStatus {
    Offline = 0,
    Online = 1,
    Error = 2,
    Maintenance = 3
};

// 工作模式
enum class WorkMode {
    Idle = 0,        // 待机模式
    Manual = 1,      // 手动模式
    Smart = 2,       // 智能模式
    Maintenance = 3  // 维护模式
};

// 运行模式（对应寄存器1002H - 已废弃，v1.22运行模式见AirCirculationMode，仅0-5）
enum class OperationMode {
    InternalCirculation = 0,      // 内循环
    MixedMode = 1,                // 内循环/混风模式
    FreshAirMode = 2,             // 全热新风模式
    BypassMode = 3,               // 旁通模式
    SmartMode = 4,                // 智能模式（v1.20遗留，v1.21起已移除）
    StrongWindMode = 5            // 强风模式（v1.20遗留，v1.21起已移除）
};

// 新风运行模式（对应寄存器1007H，协议v1.22）
enum class AirCirculationMode {
    Internal = 0, // 内循环
    Mixed = 1,    // 内循环/混风
    FreshAir = 2, // 全热新风/节能新风
    Auto = 3,     // 自动模式（实际内外循环由201DH显示）
    Bypass = 4,   // 旁通/换气
    Sleep = 5     // 睡眠模式
};

// 整机运行模式（对应寄存器100AH，协议v1.22）
enum class WholeUnitRunMode {
    None = 0,     // 无（对应8寸屏：手动）
    Standard = 1, // 标准
    Guest = 2,    // 会客
    Dry = 3,      // 干爽
    Mild = 4,     // 温润
    Travel = 5    // 旅行
};

// 风机档位
enum class FanGearLevel {
    Off = 0,
    Gear1 = 1,
    Gear2 = 2,
    Gear3 = 3,
    Gear4 = 4,
    Gear5 = 5,
    Gear6 = 6
};

// 电辅热选择（对应寄存器1013H）
enum class AuxHeatMode {
    Off = 0x00, // 关闭
    Heat1 = 0x01, // 开启电辅热1
    Heat2 = 0x02, // 开启电辅热2
    Both = 0x03 // 开启电辅热1和2
};

// 加湿/除湿强度（对应寄存器1014H）
enum class HumidityIntensity {
    Weak = 0, // 弱
    Medium = 1, // 中
    Strong = 2 // 强
};

// 阀门状态
enum class ValveStatus {
    Closed = 0, // 关闭
    HalfOpen = 1, // 半开
    FullOpen = 2 // 全开
};

// 系统状态
enum class SystemState {
    Initializing = 0,
    Running = 1,
    Stopping = 2,
    Error = 3
};

// API响应码
enum class ApiCode {
    Success = 0,
    InvalidParameter = 1001,
    DeviceOffline = 1002,
    OperationFailed = 1003,
    Timeout = 1004,
    InternalError = 1005
};

// 故障码枚举（对应离散输入偏移64-76，协议v1.22）
enum class FaultCode {
    NoFault = 0,
    FreshAirFanFault = 1,              // 新风机异常（偏移64）
    ExhaustFanFault = 2,               // 排风机异常（偏移65）
    BoostFanFault = 3,                 // 增压风机异常（偏移66）
    HumidifierCommFault = 4,           // 加湿机通讯失联（偏移68）
    HumidifierInletFloatFault = 5,    // 加湿进水槽浮子警报（偏移69）
    HumidifierDrainFloatFault = 6,    // 加湿排水槽浮子警报（偏移70）
    HumidifierDrainNotDrop = 7,       // 加湿排水槽水位浮子排水后不下降（偏移71）
    HumidifierNoWater = 8,            // 加湿进水槽缺水（偏移72）
    AuxHeat1Overcurrent = 9,          // 加湿电辅热1过流/过压保护（偏移73）
    AuxHeat2Overcurrent = 10,         // 加湿电辅热2过流/过压保护（偏移74）
    HumidifierInletFloatAbnormal = 11,// 加湿进水槽浮子有异常（偏移75）
    HumidifierDrainFloatAbnormal = 12 // 加湿排水槽浮子有异常（偏移76）
};

// 机型枚举
enum class DeviceModel {
    Model4CP = 0,      // 4CP机型
    ModelHeat = 1      // 全热新风机型
};

// 工具宏（重命名避免与libhv冲突）
#define BEIANG_SAFE_DELETE(ptr) \
    if (ptr) {                  \
        delete ptr;             \
        ptr = nullptr;          \
    }
#define BEIANG_SAFE_DELETE_ARRAY(ptr) \
    if (ptr) {                        \
        delete[] ptr;                 \
        ptr = nullptr;                \
    }

// 设备地址检查宏
#define IS_VALID_DEVICE_ADDRESS_4CP(addr) ((addr) == DEFAULT_DEVICE_ADDRESS_4CP)
#define IS_VALID_DEVICE_ADDRESS_HEAT(addr) ((addr) == DEFAULT_DEVICE_ADDRESS_HEAT)

// 开关状态宏
#define POWER_ON 1
#define POWER_OFF 0

// 模式控制宏（v1.22开关语义：0:关闭 1:开启）
#define SWITCH_OFF 0
#define SWITCH_ON 1

// 寄存器值范围检查宏（协议v1.22）
#define IS_VALID_FAN_GEAR(gear) ((gear) >= 0 && (gear) <= 6)
#define IS_VALID_HUMIDITY(hum) ((hum) >= 30 && (hum) <= 70)
#define IS_VALID_TEMPERATURE(temp) ((temp) >= 160 && (temp) <= 310)  // 目标温度寄存器值（实际×10）
#define IS_VALID_DUTY_CYCLE(duty) ((duty) >= 0 && (duty) <= 100)
#define IS_VALID_HUMIDITY_INTENSITY(intensity) ((intensity) >= 0 && (intensity) <= 2)
#define IS_VALID_RUN_MODE(mode) ((mode) >= 0 && (mode) <= 5)          // 1007H 新风运行模式
#define IS_VALID_WHOLE_UNIT_RUN_MODE(mode) ((mode) >= 0 && (mode) <= 5) // 100AH 整机运行模式
#define IS_VALID_DEVICE_ADDRESS(addr) ((addr) >= 0 && (addr) <= 254)  // 1024H 设备地址
#define IS_VALID_COMPRESSOR_EEV(val) ((val) >= 0 && (val) <= 500)     // 1028H 电子膨胀阀开度
#define IS_VALID_COMPRESSOR_FREQ(val) ((val) >= 0 && (val) <= 90)     // 1029H 运行频率
#define IS_VALID_COMPRESSOR_FREQ_MAX(val) ((val) >= 60 && (val) <= 95) // 102AH 频率上限
#define FACTORY_TEST_MODE_VALUE 100                                    // 1030H 厂测模式：100=测试模式

// 工厂标志宏
#define FACTORY_FLAG_BA 0x4241  // "BA"的ASCII码

// 版本号宏
#define PROTOCOL_VERSION_1_20 0x0101  // 版本1.20 (0101)
#define PROTOCOL_VERSION_1_21 0x0101  // 版本1.21 (0101)
#define PROTOCOL_VERSION_1_22 0x0101  // 版本1.22 (0101，除以100表示1.01)

// 注意：日志宏已迁移到 LogManager.h (基于 spdlog)
// 保留此文件仅用于全局类型定义和常量

#endif // GLOBALDEFINE_H
