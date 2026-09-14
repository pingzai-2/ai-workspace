#include "4CP_Protocol.h"
#include "Logger.h"
#include <algorithm>
#include <cstring>
#include <iostream>
#include <ios>

namespace _4CP {

// ========== CRC16计算 (Modbus标准) ==========

uint16_t CalculateCRC16(const uint8_t* data, size_t length) {
    uint16_t crc = 0xFFFF;

    for (size_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            if (crc & 0x0001) {
                crc = (crc >> 1) ^ 0xA001;
            } else {
                crc >>= 1;
            }
        }
    }

    return crc;
}

// ========== Modbus 协议构建 ==========

std::vector<uint8_t> ModbusProtocol::BuildReadHoldingRegistersRequest(
    uint8_t deviceAddress,
    uint16_t startAddress,
    uint16_t registerCount
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS));

    // 起始地址 (大端序)
    frame.push_back((startAddress >> 8) & 0xFF);
    frame.push_back(startAddress & 0xFF);

    // 寄存器数量 (大端序)
    frame.push_back((registerCount >> 8) & 0xFF);
    frame.push_back(registerCount & 0xFF);

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);         // CRC 低字节
    frame.push_back((crc >> 8) & 0xFF);  // CRC 高字节

    return frame;
}

std::vector<uint8_t> ModbusProtocol::BuildReadHoldingRegistersResponse(
    uint8_t deviceAddress,
    const std::vector<uint16_t>& registerValues
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS));

    // 字节数
    uint8_t byteCount = static_cast<uint8_t>(registerValues.size() * 2);
    frame.push_back(byteCount);

    // 寄存器值 (大端序)
    for (uint16_t value : registerValues) {
        frame.push_back((value >> 8) & 0xFF);
        frame.push_back(value & 0xFF);
    }

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

std::vector<uint8_t> ModbusProtocol::BuildWriteSingleRegisterRequest(
    uint8_t deviceAddress,
    uint16_t registerAddress,
    uint16_t registerValue
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::WRITE_SINGLE_REGISTER));

    // 寄存器地址 (大端序)
    frame.push_back((registerAddress >> 8) & 0xFF);
    frame.push_back(registerAddress & 0xFF);

    // 寄存器值 (大端序)
    frame.push_back((registerValue >> 8) & 0xFF);
    frame.push_back(registerValue & 0xFF);

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

std::vector<uint8_t> ModbusProtocol::BuildWriteSingleRegisterResponse(
    uint8_t deviceAddress,
    uint16_t registerAddress,
    uint16_t registerValue
) {
    // 响应与请求相同
    return BuildWriteSingleRegisterRequest(deviceAddress, registerAddress, registerValue);
}

std::vector<uint8_t> ModbusProtocol::BuildWriteMultipleRegistersRequest(
    uint8_t deviceAddress,
    uint16_t startAddress,
    const std::vector<uint16_t>& registerValues
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS));

    // 起始地址 (大端序)
    frame.push_back((startAddress >> 8) & 0xFF);
    frame.push_back(startAddress & 0xFF);

    // 寄存器数量 (大端序)
    uint16_t registerCount = static_cast<uint16_t>(registerValues.size());
    frame.push_back((registerCount >> 8) & 0xFF);
    frame.push_back(registerCount & 0xFF);

    // 字节数
    uint8_t byteCount = static_cast<uint8_t>(registerValues.size() * 2);
    frame.push_back(byteCount);

    // 寄存器值 (大端序)
    for (uint16_t value : registerValues) {
        frame.push_back((value >> 8) & 0xFF);
        frame.push_back(value & 0xFF);
    }

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

std::vector<uint8_t> ModbusProtocol::BuildWriteMultipleRegistersResponse(
    uint8_t deviceAddress,
    uint16_t startAddress,
    uint16_t registerCount
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS));

    // 起始地址 (大端序)
    frame.push_back((startAddress >> 8) & 0xFF);
    frame.push_back(startAddress & 0xFF);

    // 寄存器数量 (大端序)
    frame.push_back((registerCount >> 8) & 0xFF);
    frame.push_back(registerCount & 0xFF);

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

std::vector<uint8_t> ModbusProtocol::BuildExceptionResponse(
    uint8_t deviceAddress,
    uint8_t functionCode,
    ModbusExceptionCode exceptionCode
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码 + 0x80 (异常标志)
    frame.push_back(functionCode | 0x80);

    // 异常码
    frame.push_back(static_cast<uint8_t>(exceptionCode));

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

// ========== v1.22 功能码实现 (02H/04H) ==========

// 构建 02H - 读离散输入请求
std::vector<uint8_t> ModbusProtocol::BuildReadDiscreteInputsRequest(
    uint8_t deviceAddress,
    uint16_t startAddress,
    uint16_t inputCount
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS));

    // 起始地址 (大端序)
    frame.push_back((startAddress >> 8) & 0xFF);
    frame.push_back(startAddress & 0xFF);

    // 输入数量 (大端序)
    frame.push_back((inputCount >> 8) & 0xFF);
    frame.push_back(inputCount & 0xFF);

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

// 构建 02H - 读离散输入响应
std::vector<uint8_t> ModbusProtocol::BuildReadDiscreteInputsResponse(
    uint8_t deviceAddress,
    const std::vector<uint8_t>& inputValues
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS));

    // 字节数
    uint8_t byteCount = static_cast<uint8_t>(inputValues.size());
    frame.push_back(byteCount);

    // 输入值
    for (uint8_t value : inputValues) {
        frame.push_back(value);
    }

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

// 构建 04H - 读输入寄存器请求
std::vector<uint8_t> ModbusProtocol::BuildReadInputRegistersRequest(
    uint8_t deviceAddress,
    uint16_t startAddress,
    uint16_t registerCount
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS));

    // 起始地址 (大端序)
    frame.push_back((startAddress >> 8) & 0xFF);
    frame.push_back(startAddress & 0xFF);

    // 寄存器数量 (大端序)
    frame.push_back((registerCount >> 8) & 0xFF);
    frame.push_back(registerCount & 0xFF);

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

// 构建 04H - 读输入寄存器响应
std::vector<uint8_t> ModbusProtocol::BuildReadInputRegistersResponse(
    uint8_t deviceAddress,
    const std::vector<uint16_t>& registerValues
) {
    std::vector<uint8_t> frame;

    // 设备地址
    frame.push_back(deviceAddress);

    // 功能码
    frame.push_back(static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS));

    // 字节数
    uint8_t byteCount = static_cast<uint8_t>(registerValues.size() * 2);
    frame.push_back(byteCount);

    // 寄存器值 (大端序)
    for (uint16_t value : registerValues) {
        frame.push_back((value >> 8) & 0xFF);
        frame.push_back(value & 0xFF);
    }

    // 计算并添加 CRC (小端序)
    uint16_t crc = CalculateCRC16(frame.data(), frame.size());
    frame.push_back(crc & 0xFF);
    frame.push_back((crc >> 8) & 0xFF);

    return frame;
}

// ========== Modbus 协议解析 ==========

bool ModbusProtocol::ParseFrame(
    const std::vector<uint8_t>& buffer,
    ModbusFrame& frame,
    size_t& frameLen
) {
    // Modbus RTU 最小帧长度: 地址(1) + 功能码(1) + CRC(2) = 4 字节
    if (buffer.size() < 4) {
        return false;
    }

    // 尝试解析帧
    // Modbus RTU 没有帧头/帧尾，通过 CRC 校验来确定帧边界

    // 从缓冲区开头开始尝试
    for (size_t start = 0; start < buffer.size(); ++start) {
        // 至少需要 4 字节
        if (buffer.size() - start < 4) {
            break;
        }

        // 检查可能的帧长度
        // 根据功能码确定预期帧长度
        uint8_t functionCode = buffer[start + 1] & 0x7F;  // 去除异常位
        size_t expectedFrameLen = 0;

        switch (functionCode) {
            case 0x02: {  // 读离散输入请求 (v1.22)
                if (buffer.size() - start < 8) {
                    continue;  // 数据不完整
                }
                expectedFrameLen = 8;
                break;
            }
            case 0x03: {  // 读保持寄存器请求
                if (buffer.size() - start < 8) {
                    continue;  // 数据不完整
                }
                expectedFrameLen = 8;
                break;
            }
            case 0x04: {  // 读输入寄存器请求 (v1.22)
                if (buffer.size() - start < 8) {
                    continue;  // 数据不完整
                }
                expectedFrameLen = 8;
                break;
            }
            case 0x06: {  // 写单个寄存器
                if (buffer.size() - start < 8) {
                    continue;  // 数据不完整
                }
                expectedFrameLen = 8;
                break;
            }
            case 0x10: {  // 写多个寄存器请求
                if (buffer.size() - start < 9) {
                    continue;  // 数据不完整
                }
                // 字节数在位置 6
                uint8_t byteCount = buffer[start + 6];
                expectedFrameLen = 9 + byteCount;
                if (buffer.size() - start < expectedFrameLen) {
                    continue;  // 数据不完整
                }
                break;
            }
            default:
                // 未知功能码，尝试最小帧
                if (buffer.size() - start < 4) {
                    break;
                }
                expectedFrameLen = 4;
        }

        // 验证 CRC
        std::vector<uint8_t> frameData(buffer.begin() + start,
                                          buffer.begin() + start + expectedFrameLen);

        if (ValidateCRC(frameData)) {
            // CRC 校验通过，解析帧
            frame.deviceAddress = frameData[0];
            frame.functionCode = frameData[1];

            // 提取数据域 (不包括地址、功能码和 CRC)
            if (expectedFrameLen > 4) {
                frame.data.assign(frameData.begin() + 2,
                                  frameData.begin() + expectedFrameLen - 2);
            } else {
                frame.data.clear();
            }

            // 解析 CRC
            frame.crc = ReadLittleEndianUint16(&frameData[expectedFrameLen - 2]);

            frameLen = expectedFrameLen;

            LOG("[MODBUS] Frame parsed: Addr=0x" << std::hex
                      << static_cast<int>(frame.deviceAddress)
                      << ", FC=0x" << static_cast<int>(frame.functionCode)
                      << ", Len=" << std::dec << frameLen);

            return true;
        }
    }

    return false;
}

bool ModbusProtocol::ValidateCRC(const std::vector<uint8_t>& frame) {
    if (frame.size() < 4) {
        return false;
    }

    // 计算除 CRC 外的数据的 CRC
    uint16_t calculatedCRC = CalculateCRC16(frame.data(), frame.size() - 2);

    // 读取帧中的 CRC (小端序)
    uint16_t frameCRC = ReadLittleEndianUint16(&frame[frame.size() - 2]);

    bool valid = (calculatedCRC == frameCRC);

    if (!valid) {
        LOG("[MODBUS] CRC mismatch: calc=0x" << std::hex << calculatedCRC
                  << ", frame=0x" << frameCRC << std::dec);
    }

    return valid;
}

// ========== 寄存器权限检查 ==========

bool RegisterAccessChecker::IsWritable(uint16_t address) {
    // 可写寄存器列表 (根据 v1.22 协议规范)
    // 保持寄存器区域 1000H-1076H
    if (address >= HR_TOTAL_SWITCH && address <= HR_LAST_REGISTER) {
        // 只写寄存器: HR_FACTORY_RESET, HR_CLEAR_ALL_FAN_TIME
        if (address == HR_FACTORY_RESET || address == HR_CLEAR_ALL_FAN_TIME) {
            return true;  // 只写
        }
        // 其他都是读写
        return true;
    }
    // 输入寄存器 (2000H-203BH) 都是只读
    // 离散输入寄存器 (3000H-3004H) 都是只读
    return false;
}

bool RegisterAccessChecker::IsReadable(uint16_t address) {
    // 保持寄存器区域 (1000H-1076H) 可读
    if (address >= HR_TOTAL_SWITCH && address <= HR_LAST_REGISTER) {
        return true;
    }
    // 输入寄存器区域 (2000H-203BH) 可读
    if (address >= IR_FACTORY_ID && address <= IR_LAST_REGISTER) {
        return true;
    }
    // 离散输入寄存器区域 (3000H-3004H) 通过02H功能码读取，不在此处检查
    return false;
}

RegisterAccess RegisterAccessChecker::GetAccess(uint16_t address) {
    if (!IsReadable(address)) {
        return RegisterAccess::WRITE_ONLY;  // 不存在或不可读
    }
    if (IsWritable(address)) {
        // 只写寄存器
        if (address == HR_FACTORY_RESET || address == HR_CLEAR_ALL_FAN_TIME) {
            return RegisterAccess::WRITE_ONLY;
        }
        return RegisterAccess::READ_WRITE;
    }
    return RegisterAccess::READ_ONLY;
}

} // namespace _4CP
