#pragma once

#include "4CP_Protocol.h"
#include <array>
#include <cstddef>
#include <map>
#include <vector>
#include <memory>
#include <random>
#include <mutex>

namespace _4CP {

// ========== 寄存器设备模拟器 ==========

class ModbusRegisterDevice {
public:
    explicit ModbusRegisterDevice(
        uint8_t deviceAddress = DEVICE_ADDRESS,
        uint32_t randomSeed = 0);

    // 处理 Modbus 帧并生成响应
    std::vector<uint8_t> ProcessFrame(const ModbusFrame& frame);

    // 更新模拟值 (温度、湿度、转速等)
    void UpdateSimulation();

    // 获取寄存器值
    uint16_t GetRegister(uint16_t address) const;
    void SetRegister(uint16_t address, uint16_t value);
    uint8_t GetDiscreteInput(uint16_t bit) const;
    bool SetDiscreteInput(uint16_t bit, bool value);

    // 把当前数据镜像一次性填入 Modbus 映射，通信线程只负责快进快出。
    void CopyDataImage(
        uint16_t* holdingRegisters,
        uint16_t* inputRegisters,
        uint8_t* discreteInputs) const;

    // 把 libmodbus 已确认的保持寄存器写入同步回数据镜像。
    bool ApplyHoldingWrite(
        uint16_t startAddress,
        size_t registerCount,
        const uint16_t* values);

    // 通信线程在应答前只做轻量校验；真正的数据变更仍由 ApplyHoldingWrite 完成。
    bool ValidateHoldingWrite(
        uint16_t startAddress,
        size_t registerCount,
        const uint16_t* values) const;

    // 获取设备地址
    uint8_t GetDeviceAddress() const { return deviceAddress_; }

    // 初始化寄存器默认值
    void InitializeRegisters();

private:
    // 处理各种功能码
    std::vector<uint8_t> HandleReadHoldingRegisters(const ModbusFrame& frame);
    std::vector<uint8_t> HandleReadInputRegisters(const ModbusFrame& frame);      // v1.20: 04H
    std::vector<uint8_t> HandleReadDiscreteInputs(const ModbusFrame& frame);     // v1.20: 02H
    std::vector<uint8_t> HandleWriteSingleRegister(const ModbusFrame& frame);
    std::vector<uint8_t> HandleWriteMultipleRegisters(const ModbusFrame& frame);

    // 生成模拟数据
    void GenerateSensorData();
    void UpdateAlertSimulation();
    bool ValidateHoldingWriteLocked(
        uint16_t startAddress,
        size_t registerCount,
        const uint16_t* values) const;
    void ApplyModuleInterlockLocked(
        uint16_t writtenStartAddress,
        size_t writtenRegisterCount);

    uint8_t deviceAddress_;
    RegisterMap registers_;  // 寄存器映射表
    std::array<uint16_t, DISCRETE_WORD_COUNT> discreteWords_;
    mutable std::mutex registerMutex_;

    // 模拟数据生成器
    std::mt19937 rng_;
    std::uniform_real_distribution<float> tempDist_;
    std::uniform_real_distribution<float> humidityDist_;
    std::uniform_real_distribution<float> pm25Dist_;
    std::uniform_real_distribution<float> co2Dist_;
    unsigned int runtimeCounter_ = 0;
    unsigned int alertUpdateCounter_ = 0;
};

// ========== 设备工厂 ==========

class DeviceFactory {
public:
    // 创建默认 Modbus 设备 (地址 0xD1)
    static std::shared_ptr<ModbusRegisterDevice> CreateDefaultDevice();

    // 创建自定义地址设备
    static std::shared_ptr<ModbusRegisterDevice> CreateDevice(uint8_t address);
};

} // namespace _4CP
