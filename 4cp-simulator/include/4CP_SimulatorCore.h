#pragma once

#include "DeviceSimulator.h"
#include "SerialConfig.h"
#include "modbus.h"
#include <map>
#include <memory>
#include <mutex>
#include <functional>
#include <atomic>
#include <chrono>
#include <thread>

namespace _4CP {

// 通信核心：libmodbus 收包、校验、解析并立即回包。
class SimulatorCore {
public:
    SimulatorCore();
    ~SimulatorCore();

    // 启动模拟器
    bool Start(const SerialConfig& config);

    // 停止模拟器
    void Stop();

    // 添加模拟设备
    bool AddDevice(uint8_t addr, std::shared_ptr<ModbusRegisterDevice> device);

    // 移除设备
    void RemoveDevice(uint8_t addr);

    // 获取设备
    std::shared_ptr<ModbusRegisterDevice> GetDevice(uint8_t addr);

    // 运行状态
    bool IsRunning() const { return isRunning_; }

    // 获取设备数量
    size_t GetDeviceCount() const { return devices_.size(); }

    // 更新所有设备模拟
    void UpdateAllDevices();

    // 回包完成后再输出摘要，日志不阻塞通信快路径。
    using RequestCompletedCallback = std::function<void(
        uint8_t deviceAddress,
        uint8_t functionCode,
        int requestLength,
        int replyLength,
        std::chrono::microseconds replyDelay)>;
    void SetRequestCompletedCallback(RequestCompletedCallback callback);

private:
    modbus_t* context_;
    modbus_mapping_t* mapping_;
    bool connected_;

    // 设备列表
    std::map<uint8_t, std::shared_ptr<ModbusRegisterDevice>> devices_;
    std::mutex devicesMutex_;

    // 运行状态
    std::atomic<bool> isRunning_;

    RequestCompletedCallback requestCompletedCallback_;

    void CommunicationLoop();
    bool CreateMapping();
    void DestroyModbus();
    void CopyDeviceToMapping(const std::shared_ptr<ModbusRegisterDevice>& device);
    void ApplyHoldingWrite(
        const std::shared_ptr<ModbusRegisterDevice>& device,
        const uint8_t* request,
        int requestLength);
    bool ValidateHoldingWriteRequest(
        const std::shared_ptr<ModbusRegisterDevice>& device,
        const uint8_t* request,
        int requestLength) const;
    bool ExceedsProductLimit(const uint8_t* request, int requestLength) const;
    std::thread communicationThread_;
#ifdef _WIN32
    std::atomic<unsigned long> communicationThreadId_;
#endif
};

} // namespace _4CP
