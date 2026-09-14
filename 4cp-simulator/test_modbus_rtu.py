#!/usr/bin/env python3
"""
4CP Modbus RTU 测试客户端
使用标准 Modbus RTU 协议（无帧头/帧尾）
协议版本: v1.22
"""

import serial
import serial.tools.list_ports
import time
import struct
import sys

# ========== Modbus RTU 协议常量 ==========

# 设备地址 (默认 209 = 0xD1)
DEVICE_ADDRESS = 0xD1

# Modbus 功能码
FUNC_READ_DISCRETE_INPUTS = 0x02      # 读离散输入
FUNC_READ_HOLDING_REGISTERS = 0x03
FUNC_READ_INPUT_REGISTERS = 0x04      # 读输入寄存器
FUNC_WRITE_SINGLE_REGISTER = 0x06
FUNC_WRITE_MULTIPLE_REGISTERS = 0x10

# ========== 保持寄存器地址 (1000H-1076H) - 03/06/10H功能码 ==========

# 模块开关控制 (1000H-1005H)
HR_MAIN_SWITCH = 0x1000                # 总开关 (R/W): 0:关闭, 1:开启
HR_FRESH_MODULE_SWITCH = 0x1001        # 新风模块开关 (R/W): 0:关闭, 1:开启
HR_PURIFY_MODE_SWITCH = 0x1002         # 超净模式开关 (R/W): 0:关闭, 1:开启
HR_HUMIDITY_MODULE_SWITCH = 0x1003     # 调湿模块开关 (R/W): 0:关闭, 1:开启
HR_HUMIDIFY_SWITCH = 0x1004             # 加湿开关 (R/W): 0:关闭, 1:开启
HR_DEHUMIDIFY_SWITCH = 0x1005           # 除湿开关 (R/W): 0:关闭, 1:开启

# 新风模块控制 (1006H-100DH)
HR_AWAY_HOME_SWITCH = 0x1006           # 一键离家开关 (R/W): 0:关闭, 1:开启
HR_FRESH_RUN_MODE = 0x1007              # 新风运行模式 (R/W): 0:内循环, 1:内循环/混风, 2:全热新风/节能新风, 3:自动模式, 4:旁通/换气, 5:睡眠模式
HR_FAN_GEAR = 0x1008                    # 风量档位 (R/W): 0/1/2/3/4/5/6
HR_EXHAUST_FAN_GEAR = 0x1009            # 排风风量档位(预留) (R/W)
HR_UNIT_RUN_MODE = 0x100A               # 整机运行模式 (R/W): 0:无(8寸:手动), 1:标准, 2:会客, 3:干爽, 4:温润, 5:旅行
HR_STEPLESS_FAN_CTRL = 0x100B           # 无极风量控制开关 (R/W): 0:关闭, 1:打开
HR_FRESH_AIR_DUTY = 0x100C              # 新风风量占空比 (R/W): 0-100%
HR_EXHAUST_AIR_DUTY = 0x100D            # 排风风量占空比 (R/W): 0-100%
HR_BOOST_AIR_DUTY = 0x100E              # 增压风风量占空比 (R/W): 0-100%

# 温湿度控制 (100FH-1015H)
HR_TARGET_HUMIDITY = 0x100F              # 目标湿度设定 (R/W): 范围 30~70
HR_TARGET_TEMP = 0x1010                 # 目标温度设定 (R/W): 范围 160~310 (实际温度×10)
HR_PLASMA_STERILIZE = 0x1011            # 等离子消毒开关 (R/W): 0:关闭, 1:开启
HR_IEF_SWITCH = 0x1012                  # IEF开关 (R/W): 0:关闭, 1:开启
HR_ELECTRIC_HEATER = 0x1013             # 电辅热选择 (R/W): 0x00关闭, 0x01电辅热1, 0x02电辅热2, 0x03电辅热1+2
HR_HUMIDIFY_INTENSITY = 0x1014          # 加湿/除湿强度设定 (R/W): 0:弱, 1:中, 2:强
HR_SA_FAN_RATIO = 0x1015                # SA风量与增压风机比例设定 (R/W): 实际值×10

# RTC时间设置 (1016H-101FH)
HR_RESERVED_START = 0x1016              # 预留 (1016H-101AH)
HR_RTC_TIME_START = 0x101B              # Set RTC 起始地址 (10字节: 年|月日|时分|秒周|format对齐)
HR_RTC_TIME_END = 0x101F                # Set RTC 结束地址

# 关机延时和加湿控制 (1020H-102AH)
HR_OFF_DELAY_FAN = 0x1020               # 关机后延时关风机时间 (R/W): 单位:分钟
HR_HUMIDIFY_PUMP_ON = 0x1021            # 加湿循环泵开时间 (R/W): 单位:秒
HR_HUMIDIFY_PUMP_OFF = 0x1022           # 加湿循环泵关时间 (R/W): 单位:秒
HR_HUMIDIFY_DRAIN_ON = 0x1023           # 加湿排水开时间 (R/W): 单位:秒
HR_DEVICE_ADDR = 0x1024                 # 设备地址 (R/W): 4CP:209(0xD1), 全热:193(0xC1)
HR_OFF_AQ_DETECT_SWITCH = 0x1025        # 关机下空气质量检测开关 (R/W): 0:关闭, 1:开启
HR_OFF_AQ_DETECT_INTERVAL = 0x1026      # 关机下空气质量检测间隔时间 (R/W): 单位:分钟
HR_OFF_AQ_DETECT_RUNTIME = 0x1027       # 关机下空气质量检测运行时间 (R/W): 单位:分钟
HR_COMPRESSOR_EEV = 0x1028              # 压缩机电子膨胀阀开度 (R/W)
HR_COMPRESSOR_FREQ_SET = 0x1029         # 压缩机运行频率设定值 (R/W)
HR_COMPRESSOR_FREQ_MAX = 0x102A          # 压缩机频率上限设定值 (R/W): 60-95 Hz
HR_HIGH_PRESSURE_SWITCH = 0x102B        # 高压开关 (R/W): 0:关, 1:开 (仅厂测模式可写)
HR_LOW_PRESSURE_SWITCH = 0x102C         # 低压开关 (R/W): 0:关, 1:开 (仅厂测模式可写)

# 厂测和滤网 (1030H-103FH)
HR_FACTORY_TEST_MODE = 0x1030            # 厂测模式 (R/W)
HR_FILTER1_REMAINING = 0x1031           # (设置)滤网1剩余时间 (R/W): 单位:小时
HR_FILTER2_REMAINING = 0x1032           # (设置)滤网2剩余时间 (R/W): 单位:小时
HR_FILTER3_REMAINING = 0x1033           # (设置)滤网3剩余时间 (R/W): 单位:小时
HR_HUMIDIFY_MODULE_REMAINING = 0x1034  # (设置)加湿模块剩余时间 (R/W): 单位:小时
HR_IEF_CLEAN_REMAINING = 0x1035         # (设置)IEF需清洗剩余时间 (R/W): 单位:小时
HR_MAINTENANCE_REMAINING = 0x1036       # (设置)整机保养剩余时间 (R/W): 单位:天
HR_FAN1_FLOW_SET = 0x1038               # 当前FAN1风量设定值 (R/W, 仅厂测模式可设定)
HR_FAN2_FLOW_SET = 0x1039               # 当前FAN2风量设定值 (R/W, 仅厂测模式可设定)
HR_FAN3_FLOW_SET = 0x103A               # 当前FAN3风量设定值 (R/W, 仅厂测模式可设定)
HR_FAN4_FLOW_SET = 0x103B               # 当前FAN4风量设定值 (R/W, 仅厂测模式可设定)
HR_VALVE1_STATUS_SET = 0x103C           # 阀门1状态设定 (R/W, 仅厂测模式可设定): 0:关闭, 1:半开, 2:全开
HR_VALVE2_STATUS_SET = 0x103D           # 阀门2状态设定 (R/W, 仅厂测模式可设定)
HR_VALVE3_STATUS_SET = 0x103E           # 阀门3状态设定 (R/W, 仅厂测模式可设定)
HR_CLEAR_FAN_RUNTIME = 0x103F            # 清除所有风机累计运转时间 (W): 写1清除
HR_FACTORY_RESET = 0x1040                # 恢复出厂 (W): 写1恢复出厂设置
HR_FAN_FLOW_SET_START = 0x1041          # FAN1-4外/内循环1-6档风量设定值起始 (1041H-1070H)
HR_FAN_FLOW_SET_END = 0x1070            # 风量设定值结束
HR_DAMPER1_DIR_SET = 0x1071             # 风阀1方向设定 (R/W): 0/1
HR_DAMPER2_DIR_SET = 0x1072             # 风阀2方向设定 (R/W): 0/1
HR_DAMPER3_DIR_SET = 0x1073             # 风阀3方向设定 (R/W): 0/1
HR_DAMPER1_STEPS_SET = 0x1074           # 风阀1运行步数设定 (R/W)
HR_DAMPER2_STEPS_SET = 0x1075           # 风阀2运行步数设定 (R/W)
HR_DAMPER3_STEPS_SET = 0x1076           # 风阀3运行步数设定 (R/W)

# ========== 输入寄存器地址 (2000H-205BH) - 04H功能码 (只读) ==========

# 设备基本信息 (2000H-2004H)
IR_FACTORY_ID = 0x2000                   # 工厂标志 (R): ASCII "BA"
IR_MODEL = 0x2001                        # 机型 (R): 4CP:0, 全热新风:1
IR_VERSION = 0x2002                      # 版本 (R): 0101
IR_FRESH_MAX_GEAR = 0x2003               # 新风模式风量最大档位 (R): 3/4/5/6...
IR_MIX_MAX_GEAR = 0x2004                # 内循环/混风模式风量最大档位 (R)

# 风机档位 (2005H-2008H)
IR_FAN1_GEAR = 0x2005                    # FAN1档位 (R): 0/1/2/3/4/5/6
IR_FAN2_GEAR = 0x2006                    # FAN2档位 (R)
IR_FAN3_GEAR = 0x2007                    # FAN3档位 (R)
IR_FAN4_GEAR = 0x2008                    # FAN4档位 (R)

# 风机实时转速 (2009H-200CH)
IR_FAN1_RPM = 0x2009                     # FAN1实时rpm (R)
IR_FAN2_RPM = 0x200A                     # FAN2实时rpm (R)
IR_FAN3_RPM = 0x200B                     # FAN3实时rpm (R)
IR_FAN4_RPM = 0x200C                     # FAN4实时rpm (R)

# RA1 传感器数据 (200DH-2010H)
IR_RA1_TEMP = 0x200D                     # RA1温度 (R): 实际温度×10
IR_RA1_HUMIDITY = 0x200E                 # RA1湿度 (R): 湿度值0-100, 单位1%RH
IR_RA1_PM25 = 0x200F                     # RA1 PM2.5 (R)
IR_RA1_CO2 = 0x2010                      # RA1 CO2 (R)

# OA 传感器数据 (2011H-2014H)
IR_OA_TEMP = 0x2011                      # OA温度 (R): 实际温度×10
IR_OA_HUMIDITY = 0x2012                 # OA湿度 (R)
IR_OA_PM25 = 0x2013                      # OA PM2.5 (R)
IR_OA_CO2 = 0x2014                       # OA CO2 (R)

# SA 传感器数据 (2015H-201AH)
IR_SA_TEMP = 0x2015                      # SA温度 (R): 实际温度×10
IR_SA_HUMIDITY = 0x2016                  # SA湿度 (R)
IR_SA_PM25 = 0x2017                      # SA PM2.5 (R)
IR_SA_CO2 = 0x2018                       # SA CO2 (R)
IR_TVOC = 0x2019                         # TVOC (R)
IR_FORMALDEHYDE = 0x201A                 # 甲醛 (R)

# 压缩机和电辅热 (201BH-201CH)
IR_COMPRESSOR_FREQ = 0x201B              # 压缩机运行频率 (R)
IR_HEATER_STATUS = 0x201C                # 电辅热状态 (R)

# 加湿水位浮子状态 (2024H-2025H)
IR_HUMIDIFY_INLET_LEVEL = 0x2024         # 加湿进水水位浮子状态 (R)
IR_HUMIDIFY_DRAIN_LEVEL = 0x2025         # 加湿排水水位浮子状态 (R)

# 系统运行时间 (2026H-202AH)
IR_SYSTEM_RUNTIME_DAYS = 0x2026          # 系统运行（开机）时间（累计）(R): 单位:天
IR_FAN1_RUNTIME = 0x2027                 # FAN1累计运转时间 (R): 单位:小时
IR_FAN2_RUNTIME = 0x2028                 # FAN2累计运转时间 (R)
IR_FAN3_RUNTIME = 0x2029                 # FAN3累计运转时间 (R)
IR_FAN4_RUNTIME = 0x202A                 # FAN4累计运转时间 (R)

# 压缩机温度和电压检测 (202BH-202FH)
IR_COMP_DISCHARGE_TEMP = 0x202B          # 压缩机排气温度 (R): 实际温度×10
IR_COMP_SUCTION_TEMP = 0x202C            # 压缩机吸气温度 (R): 实际温度×10
IR_EVAPORATOR_TEMP = 0x202D              # 蒸发器盘管温度 (R): 实际温度×10
IR_RESERVED_TEMP = 0x202E                # 预留温度 (R)
IR_AC_VOLTAGE = 0x202F                   # 交流电压检测值 (R): 待定

# 主控板版本时间字符串 (2030H-203BH)
IR_MAINBOARD_STRING_START = 0x2030       # 主控板版本时间字符串起始 Char[24]
IR_MAINBOARD_STRING_END = 0x203B         # 主控板版本时间字符串结束

# 自动模式内外循环显示与进/出风口、压力 (201DH-2023H)
IR_AUTO_CIRCULATION_DISPLAY = 0x201D    # 1007H自动模式时内外循环显示 (R): 0:内循环, 1:内循环/混风, 2:全热新风/节能新风
IR_INTAKE_TEMP = 0x201E                 # 进风口温度 (R): 实际温度×10
IR_INTAKE_HUMIDITY = 0x201F             # 进风口湿度 (R)
IR_OUTLET_TEMP = 0x2020                 # 出风口温度(预留) (R): 实际温度×10
IR_OUTLET_HUMIDITY = 0x2021             # 出风口湿度(预留) (R)
IR_HIGH_PRESSURE = 0x2022               # 高压压力值 (R): bar×100
IR_LOW_PRESSURE = 0x2023                # 低压压力值 (R): bar×100

# ========== 离散输入地址 (3000H-3004H) - 02H功能码 (只读) ==========

DI_START_ADDR = 0x3000                   # 离散输入起始地址

# 能力配置位（位偏移0-15，3000H-3001H）
DI_BIT_HAS_HUMIDIFY_MODULE = 0           # 有无加湿模块: 0:无, 1:有
DI_BIT_HAS_DEHUMIDIFY = 1                # 有无除湿模块: 0:无, 1:有
DI_BIT_HAS_BYPASS_MODE = 2               # 有无(旁通/换气)模式: 0:无, 1:有
DI_BIT_HAS_IEF = 3                       # 有无IEF净化: 0:无, 1:有
DI_BIT_HAS_STERILIZE = 4                 # 有无消毒模块: 0:无, 1:有
DI_BIT_HAS_HEATER = 5                    # 有无电加热控制: 0:无, 1:有
DI_BIT_HAS_ANTIFREEZE = 6                # 有无防冻保护: 0:无, 1:有
DI_BIT_HAS_HCHO = 7                      # 有无甲醛HCHO: 0:无, 1:有

# 状态位（位偏移32-47，3002H-3003H）
DI_BIT_HUMIDIFY_PUMP_STATUS = 32         # 加湿循环泵状态: 0:关闭, 1:开启
DI_BIT_HUMIDIFY_INLET_VALVE = 33         # 加湿进水阀状态: 0:关闭, 1:开启
DI_BIT_HUMIDIFY_DRAIN_PUMP = 34          # 加湿排水泵状态: 0:关闭, 1:开启
DI_BIT_COMPRESSOR_STATUS = 35            # 压缩机状态: 0:关闭, 1:开启
DI_BIT_OFF_AQ_DETECTING = 37             # 关机状态下空气质量检测中(风阀开,风机转): 0:否, 1:是

# 故障码位（位偏移64起，3004H）
DI_BIT_FAULT_FAN1 = 64                   # 新风机异常: 0:无故障, 1:故障
DI_BIT_FAULT_FAN2 = 65                   # 排风机异常: 0:无故障, 1:故障
DI_BIT_FAULT_FAN3 = 66                   # 增压风机异常: 0:无故障, 1:故障
DI_BIT_FAULT_HUMIDIFY_COMMS = 68         # 加湿机通讯失联: 0:无故障, 1:故障
DI_BIT_FAULT_INLET_FLOAT = 69            # 加湿进水槽浮子警报: 0:无故障, 1:故障
DI_BIT_FAULT_DRAIN_FLOAT = 70            # 加湿排水槽浮子警报: 0:无故障, 1:故障


# ========== CRC16 计算 (Modbus 标准) ==========

def calculate_crc16(data):
    """计算 Modbus CRC16 校验码"""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc


# ========== Modbus RTU 帧构建 ==========

def build_read_holding_registers_request(device_addr, start_addr, reg_count):
    """
    构建读保持寄存器请求 (03H)

    帧结构:
    | 设备地址 | 功能码 | 起始地址(大端) | 寄存器数量(大端) | CRC16(小端) |
    """
    frame = bytearray()
    frame.append(device_addr)                          # 设备地址
    frame.append(FUNC_READ_HOLDING_REGISTERS)          # 功能码 03H
    frame.extend(struct.pack('>H', start_addr))         # 起始地址 (大端序)
    frame.extend(struct.pack('>H', reg_count))          # 寄存器数量 (大端序)

    # 计算 CRC 并添加 (小端序)
    crc = calculate_crc16(frame)
    frame.extend(struct.pack('<H', crc))                # CRC (小端序)

    return bytes(frame)


def build_write_single_register_request(device_addr, reg_addr, value):
    """
    构建写单个寄存器请求 (06H)

    帧结构:
    | 设备地址 | 功能码 | 寄存器地址(大端) | 寄存器值(大端) | CRC16(小端) |
    """
    frame = bytearray()
    frame.append(device_addr)                          # 设备地址
    frame.append(FUNC_WRITE_SINGLE_REGISTER)           # 功能码 06H
    frame.extend(struct.pack('>H', reg_addr))           # 寄存器地址 (大端序)
    frame.extend(struct.pack('>H', value))              # 寄存器值 (大端序)

    # 计算 CRC 并添加 (小端序)
    crc = calculate_crc16(frame)
    frame.extend(struct.pack('<H', crc))                # CRC (小端序)

    return bytes(frame)


def build_write_multiple_registers_request(device_addr, start_addr, values):
    """
    构建写多个寄存器请求 (10H)

    帧结构:
    | 设备地址 | 功能码 | 起始地址(大端) | 寄存器数量(大端) | 字节数 | 数据(大端)... | CRC16(小端) |
    """
    frame = bytearray()
    frame.append(device_addr)                          # 设备地址
    frame.append(FUNC_WRITE_MULTIPLE_REGISTERS)         # 功能码 10H
    frame.extend(struct.pack('>H', start_addr))         # 起始地址 (大端序)
    reg_count = len(values)
    frame.extend(struct.pack('>H', reg_count))          # 寄存器数量 (大端序)
    byte_count = reg_count * 2
    frame.append(byte_count)                           # 字节数

    # 寄存器值 (大端序)
    for value in values:
        frame.extend(struct.pack('>H', value))

    # 计算 CRC 并添加 (小端序)
    crc = calculate_crc16(frame)
    frame.extend(struct.pack('<H', crc))                # CRC (小端序)

    return bytes(frame)


def build_read_discrete_inputs_request(device_addr, start_addr, bit_count):
    """
    构建读离散输入请求 (02H)

    帧结构:
    | 设备地址 | 功能码 | 起始地址(大端) | 位数量(大端) | CRC16(小端) |
    """
    frame = bytearray()
    frame.append(device_addr)                          # 设备地址
    frame.append(FUNC_READ_DISCRETE_INPUTS)             # 功能码 02H
    frame.extend(struct.pack('>H', start_addr))         # 起始地址 (大端序)
    frame.extend(struct.pack('>H', bit_count))          # 位数量 (大端序)

    # 计算 CRC 并添加 (小端序)
    crc = calculate_crc16(frame)
    frame.extend(struct.pack('<H', crc))                # CRC (小端序)

    return bytes(frame)


def build_read_input_registers_request(device_addr, start_addr, reg_count):
    """
    构建读输入寄存器请求 (04H)

    帧结构:
    | 设备地址 | 功能码 | 起始地址(大端) | 寄存器数量(大端) | CRC16(小端) |
    """
    frame = bytearray()
    frame.append(device_addr)                          # 设备地址
    frame.append(FUNC_READ_INPUT_REGISTERS)             # 功能码 04H
    frame.extend(struct.pack('>H', start_addr))         # 起始地址 (大端序)
    frame.extend(struct.pack('>H', reg_count))          # 寄存器数量 (大端序)

    # 计算 CRC 并添加 (小端序)
    crc = calculate_crc16(frame)
    frame.extend(struct.pack('<H', crc))                # CRC (小端序)

    return bytes(frame)


def parse_modbus_response(data):
    """解析 Modbus RTU 响应帧"""
    if len(data) < 4:
        print(f"响应太短: {len(data)} 字节")
        return None

    # 验证 CRC
    received_crc = struct.unpack('<H', data[-2:])[0]
    calculated_crc = calculate_crc16(data[:-2])

    if received_crc != calculated_crc:
        print(f"CRC 校验失败: 接收=0x{received_crc:04X}, 计算=0x{calculated_crc:04X}")
        return None

    device_addr = data[0]
    function_code = data[1]

    # 检查异常响应
    if function_code & 0x80:
        exception_code = data[2]
        print(f"收到异常响应: 功能码=0x{function_code:02X}, 异常码=0x{exception_code:02X}")
        return {'device_addr': device_addr, 'function_code': function_code, 'exception': exception_code}

    # 正常响应
    if function_code == FUNC_READ_DISCRETE_INPUTS:
        # 02H 响应: | 设备地址 | 功能码 | 字节数 | 数据位... | CRC |
        byte_count = data[2]
        data_bytes = data[3:3 + byte_count]
        # 将位数据转换为布尔列表
        bits = []
        for byte in data_bytes:
            for i in range(8):
                bits.append(bool(byte & (1 << i)))
        return {
            'device_addr': device_addr,
            'function_code': function_code,
            'byte_count': byte_count,
            'bits': bits
        }

    elif function_code == FUNC_READ_HOLDING_REGISTERS:
        byte_count = data[2]
        values = []
        for i in range(byte_count // 2):
            value = struct.unpack('>H', data[3 + i*2:5 + i*2])[0]
            values.append(value)
        return {
            'device_addr': device_addr,
            'function_code': function_code,
            'byte_count': byte_count,
            'values': values
        }

    elif function_code == FUNC_READ_INPUT_REGISTERS:
        # 04H 响应格式与 03H 相同
        byte_count = data[2]
        values = []
        for i in range(byte_count // 2):
            value = struct.unpack('>H', data[3 + i*2:5 + i*2])[0]
            values.append(value)
        return {
            'device_addr': device_addr,
            'function_code': function_code,
            'byte_count': byte_count,
            'values': values
        }

    elif function_code == FUNC_WRITE_SINGLE_REGISTER:
        reg_addr = struct.unpack('>H', data[2:4])[0]
        reg_value = struct.unpack('>H', data[4:6])[0]
        return {
            'device_addr': device_addr,
            'function_code': function_code,
            'register_address': reg_addr,
            'register_value': reg_value
        }

    elif function_code == FUNC_WRITE_MULTIPLE_REGISTERS:
        start_addr = struct.unpack('>H', data[2:4])[0]
        reg_count = struct.unpack('>H', data[4:6])[0]
        return {
            'device_addr': device_addr,
            'function_code': function_code,
            'start_address': start_addr,
            'register_count': reg_count
        }

    return {'device_addr': device_addr, 'function_code': function_code, 'raw_data': data}


# ========== 测试功能 ==========

def list_ports():
    """列出可用的串口"""
    print("可用串口:")
    ports = serial.tools.list_ports.comports()
    for port in ports:
        print(f"  {port.device}: {port.description}")
    return len(ports) > 0


def test_modbus_rtu(port_name, baudrate=9600):
    """测试 Modbus RTU 通信"""
    print(f"\n{'='*60}")
    print(f"4CP Modbus RTU 测试 (v1.22 协议)")
    print(f"端口: {port_name}, 波特率: {baudrate}")
    print(f"{'='*60}\n")

    try:
        ser = serial.Serial(
            port=port_name,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5
        )

        print(f"串口 {port_name} 打开成功\n")

        # 测试 1: 读取总开关状态 (1000H)
        print("[测试 1] 读取总开关状态 (寄存器 0x1000)")
        request = build_read_holding_registers_request(DEVICE_ADDRESS, HR_MAIN_SWITCH, 1)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                value = result['values'][0]
                status = "开启" if value == 1 else "关闭"
                print(f"  总开关状态: {status} (值: {value})")

        # 测试 2: 读取设备地址 (1024H)
        print(f"\n[测试 2] 读取设备地址 (寄存器 0x1024)")
        request = build_read_holding_registers_request(DEVICE_ADDRESS, HR_DEVICE_ADDR, 1)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                value = result['values'][0]
                print(f"  设备地址: {value} (0x{value:02X})")
                if value == DEVICE_ADDRESS:
                    print("  ✓ 设备地址正确!")

        # 测试 3: 开启总开关 (1000H = 1)
        print(f"\n[测试 3] 开启总开关 (写寄存器 0x1000 = 1)")
        request = build_write_single_register_request(DEVICE_ADDRESS, HR_MAIN_SWITCH, 1)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'register_value' in result:
                print(f"  确认写入: 地址=0x{result['register_address']:04X}, 值={result['register_value']}")

        # 测试 4: 开启新风模块 (1001H = 1)
        print(f"\n[测试 4] 开启新风模块 (写寄存器 0x1001 = 1)")
        request = build_write_single_register_request(DEVICE_ADDRESS, HR_FRESH_MODULE_SWITCH, 1)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'register_value' in result:
                print(f"  确认写入: 地址=0x{result['register_address']:04X}, 值={result['register_value']}")

        # 测试 5: 设置运行模式为全热新风 (1007H = 2)
        print(f"\n[测试 5] 设置运行模式为全热新风 (寄存器 0x1007 = 2)")
        request = build_write_single_register_request(DEVICE_ADDRESS, HR_FRESH_RUN_MODE, 2)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'register_value' in result:
                print(f"  确认写入: 地址=0x{result['register_address']:04X}, 值={result['register_value']}")

        # 测试 6: 读取输入寄存器 - 设备信息 (2000H-2004H)
        print(f"\n[测试 6] 读输入寄存器 - 设备信息 (0x2000-0x2004)")
        request = build_read_input_registers_request(DEVICE_ADDRESS, IR_FACTORY_ID, 5)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                factory_id = result['values'][0]
                chars = struct.pack('>H', factory_id).decode('ascii', errors='ignore')
                print(f"  工厂标志: 0x{factory_id:04X} ('{chars}')")
                print(f"  机型: {result['values'][1]} (0=4CP, 1=全热新风)")
                print(f"  版本: 0x{result['values'][2]:04X}")
                print(f"  新风模式风量最大档位: {result['values'][3]}")
                print(f"  混风模式风量最大档位: {result['values'][4]}")

        # 测试 7: 读取输入寄存器 - 传感器数据 (200DH-2014H)
        print(f"\n[测试 7] 读输入寄存器 - 传感器数据 (0x200D-0x2014)")
        request = build_read_input_registers_request(DEVICE_ADDRESS, IR_RA1_TEMP, 8)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                # 有符号温度处理
                ra1_temp = struct.unpack('>h', struct.pack('>H', result['values'][0]))[0] / 10.0
                oa_temp = struct.unpack('>h', struct.pack('>H', result['values'][4]))[0] / 10.0
                print(f"  RA1 温度: {ra1_temp:.1f}°C")
                print(f"  RA1 湿度: {result['values'][1]}%")
                print(f"  RA1 PM2.5: {result['values'][2]}")
                print(f"  RA1 CO2: {result['values'][3]} ppm")
                print(f"  OA 温度: {oa_temp:.1f}°C")
                print(f"  OA 湿度: {result['values'][5]}%")
                print(f"  OA PM2.5: {result['values'][6]}")
                print(f"  OA CO2: {result['values'][7]} ppm")

        # 测试 8: 读取输入寄存器 - 风机转速 (2009H-200CH)
        print(f"\n[测试 8] 读输入寄存器 - 风机转速 (0x2009-0x200C)")
        request = build_read_input_registers_request(DEVICE_ADDRESS, IR_FAN1_RPM, 4)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                print(f"  FAN1 转速: {result['values'][0]} RPM")
                print(f"  FAN2 转速: {result['values'][1]} RPM")
                print(f"  FAN3 转速: {result['values'][2]} RPM")
                print(f"  FAN4 转速: {result['values'][3]} RPM")

        # 测试 9: 读离散输入 - 设备能力配置 (02H)
        print(f"\n[测试 9] 读离散输入 - 设备能力配置 (功能码 02H, 起址 0x3000)")
        request = build_read_discrete_inputs_request(DEVICE_ADDRESS, DI_START_ADDR, 16)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'bits' in result:
                print(f"  设备能力配置位: {result['bits'][:8]}")
                print(f"    有加湿模块: {'是' if result['bits'][0] else '否'}")
                print(f"    有除湿模块: {'是' if result['bits'][1] else '否'}")
                print(f"    有旁通/换气模式: {'是' if result['bits'][2] else '否'}")
                print(f"    有IEF净化: {'是' if result['bits'][3] else '否'}")
                print(f"    有消毒模块: {'是' if result['bits'][4] else '否'}")
                print(f"    有电加热: {'是' if result['bits'][5] else '否'}")
                print(f"    有甲醛HCHO: {'是' if result['bits'][7] else '否'}")

        # 测试 10: 写多个寄存器 - 设置温湿度
        print(f"\n[测试 10] 写多个寄存器 - 设置目标温湿度")
        # 设置目标温度为24.0°C (240), 目标湿度为55%
        values = [240, 55]
        request = build_write_multiple_registers_request(DEVICE_ADDRESS, HR_TARGET_TEMP, values)
        print(f"  写入: 目标温度=24.0°C (0x{HR_TARGET_TEMP:04X}), 目标湿度=55% (0x{HR_TARGET_HUMIDITY:04X})")
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'register_count' in result:
                print(f"  确认写入: 起始地址=0x{result['start_address']:04X}, 数量={result['register_count']}")

        # 测试 11: 读取SA传感器数据 (2015H-201AH)
        print(f"\n[测试 11] 读输入寄存器 - SA传感器数据 (0x2015-0x201A)")
        request = build_read_input_registers_request(DEVICE_ADDRESS, IR_SA_TEMP, 6)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'values' in result:
                sa_temp = struct.unpack('>h', struct.pack('>H', result['values'][0]))[0] / 10.0
                print(f"  SA 温度: {sa_temp:.1f}°C")
                print(f"  SA 湿度: {result['values'][1]}%")
                print(f"  SA PM2.5: {result['values'][2]}")
                print(f"  SA CO2: {result['values'][3]} ppm")
                print(f"  TVOC: {result['values'][4]}")
                print(f"  甲醛: {result['values'][5]}")

        # 测试 12: 关闭总开关
        print(f"\n[测试 12] 关闭总开关 (写寄存器 0x1000 = 0)")
        request = build_write_single_register_request(DEVICE_ADDRESS, HR_MAIN_SWITCH, 0)
        print(f"  请求: {request.hex().upper()}")

        ser.write(request)
        time.sleep(0.1)

        response = ser.read(100)
        if response:
            print(f"  响应: {response.hex().upper()}")
            result = parse_modbus_response(response)
            if result and 'register_value' in result:
                print(f"  确认写入: 地址=0x{result['register_address']:04X}, 值={result['register_value']}")

        ser.close()
        print("\n" + "="*60)
        print("测试完成!")
        print("="*60)

    except serial.SerialException as e:
        print(f"串口错误: {e}")
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()


# ========== 主程序 ==========

def main():
    if '--list' in sys.argv or '-l' in sys.argv:
        list_ports()
        return

    if '--help' in sys.argv or '-h' in sys.argv:
        print("用法: python test_modbus_rtu.py [选项]")
        print("选项:")
        print("  --list, -l    列出可用串口")
        print("  --help, -h    显示帮助信息")
        print("\n示例:")
        print("  python test_modbus_rtu.py           # 使用默认 COM1")
        print("  python test_modbus_rtu.py COM5      # 使用 COM5")
        print("  python test_modbus_rtu.py COM5 19200 # 使用 COM5, 19200 波特率")
        return

    # 获取串口参数
    port = sys.argv[1] if len(sys.argv) > 1 else 'COM1'
    baudrate = int(sys.argv[2]) if len(sys.argv) > 2 else 9600

    test_modbus_rtu(port, baudrate)


if __name__ == '__main__':
    main()
