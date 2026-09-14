#pragma once

#include "4CP_SimulatorCore.h"
#include "CommunicationScheduler.h"
#include "DeviceSimulator.h"
#include <atomic>
#include <memory>
#include <thread>

namespace _4CP {

class ModbusSlaveScheduler : public CommunicationScheduler {
public:
    ModbusSlaveScheduler();
    ~ModbusSlaveScheduler() override;

    bool Start(
        const SerialConfig& serialConfig,
        uint8_t deviceAddress) override;
    void Stop() override;
    bool IsRunning() const override;

private:
    void DataProcessingLoop();

    SimulatorCore simulator_;
    std::shared_ptr<ModbusRegisterDevice> device_;
    uint8_t deviceAddress_;
    std::atomic<bool> dataWorkerRunning_;
    std::thread dataWorker_;
};

} // namespace _4CP
