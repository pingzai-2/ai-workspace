#include "ModbusSlaveScheduler.h"
#include "Logger.h"
#include <chrono>
#include <cstdio>
#include <iomanip>

namespace _4CP {

static void PrintCompletedRequest(
    uint8_t deviceAddress,
    uint8_t functionCode,
    int requestLength,
    int replyLength,
    std::chrono::microseconds replyDelay) {
    LOG("[MODBUS RTU] Addr=0x" << std::hex
        << static_cast<int>(deviceAddress)
        << ", FC=0x" << static_cast<int>(functionCode)
        << std::dec << ", RX=" << requestLength
        << " bytes, TX=" << replyLength
        << " bytes, reply=" << replyDelay.count() << " us");
}

ModbusSlaveScheduler::ModbusSlaveScheduler()
    : deviceAddress_(0)
    , dataWorkerRunning_(false) {
}

ModbusSlaveScheduler::~ModbusSlaveScheduler() {
    Stop();
}

bool ModbusSlaveScheduler::Start(
    const SerialConfig& serialConfig,
    uint8_t deviceAddress) {
    if (simulator_.IsRunning()) {
        return false;
    }

    deviceAddress_ = deviceAddress;
    device_ = DeviceFactory::CreateDevice(deviceAddress_);
    if (!simulator_.AddDevice(deviceAddress_, device_)) {
        device_.reset();
        return false;
    }

    simulator_.SetRequestCompletedCallback(PrintCompletedRequest);

    if (!simulator_.Start(serialConfig)) {
        simulator_.RemoveDevice(deviceAddress_);
        device_.reset();
        return false;
    }

    dataWorkerRunning_ = true;
    dataWorker_ = std::thread(
        &ModbusSlaveScheduler::DataProcessingLoop, this);

    LOG("[SCHEDULER] ModbusSlaveResponse started");
    return true;
}

void ModbusSlaveScheduler::Stop() {
    dataWorkerRunning_ = false;
    if (dataWorker_.joinable()) {
        dataWorker_.join();
    }

    simulator_.Stop();

    if (device_) {
        simulator_.RemoveDevice(deviceAddress_);
        device_.reset();
    }
}

bool ModbusSlaveScheduler::IsRunning() const {
    return simulator_.IsRunning();
}

void ModbusSlaveScheduler::DataProcessingLoop() {
    LOG("[DATA] Device data processing thread started");

    while (dataWorkerRunning_) {
        // 通信线程只负责 Modbus 收发和控制寄存器镜像更新；
        // 传感器、运行时间、故障和维护通知等模拟数据在独立线程变化。
        // UpdateSimulation 不修改 1001H/1002H/1003H，控制开关仍以写请求为准。
        simulator_.UpdateAllDevices();
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    LOG("[DATA] Device data processing thread stopped");
}

} // namespace _4CP
