#include "ModbusCommandModule.h"
#include "ModbusCommandPolicy.h"

#include "DataManager.h"
#include "common/LogManager.h"
#include "gateways/BeiAng4CPGateway.h"

#include <utility>

namespace {

void queueHoldingReadback(
    BeiAng4CPGateway* gateway,
    DataManager* dataManager,
    uint16_t startAddress,
    uint16_t count,
    const std::string& name)
{
    if (!gateway || !dataManager || count == 0 || count > 50) {
        return;
    }

    const bool queued = gateway->submitHoldingRegisterRead(
        startAddress,
        count,
        [dataManager, startAddress, count, name](
            bool success,
            const std::vector<uint16_t>& values) {
            if (!success || values.size() != count
                || !dataManager->publishHoldingReadback(
                    startAddress, values.data(), count)) {
                LOG_ERROR("[ModbusCommand] Readback failed: {}, address={:#06x}, count={}",
                    name, startAddress, count);
                return;
            }

            LOG_INFO("[ModbusCommand] Readback published: {}, address={:#06x}, count={}",
                name, startAddress, count);
        });
    if (!queued) {
        LOG_ERROR("[ModbusCommand] Readback not queued: {}, address={:#06x}, count={}",
            name, startAddress, count);
    }
}

ModbusCommandSubmitResult acceptedResult()
{
    return {ModbusCommandSubmitStatus::Accepted, ""};
}

ModbusCommandSubmitResult rejectedResult(const std::string& message)
{
    return {ModbusCommandSubmitStatus::Rejected, message};
}

ModbusCommandSubmitResult unavailableResult(const std::string& message)
{
    return {ModbusCommandSubmitStatus::Unavailable, message};
}

} // namespace

ModbusCommandModule::ModbusCommandModule(DataManager* dataManager)
    : m_dataManager(dataManager)
    , m_gateway(nullptr)
    , m_running(false)
{
}

ModbusCommandModule::~ModbusCommandModule()
{
    stop();
}

bool ModbusCommandModule::start()
{
    if (m_running) {
        return true;
    }
    if (!m_dataManager) {
        return false;
    }

    m_gateway = m_dataManager->getGateway();
    if (!m_gateway) {
        LOG_ERROR("[ModbusCommand] Gateway is unavailable");
        return false;
    }

    m_running = true;
    LOG_INFO("[ModbusCommand] Adapter started; writes use the TTY scheduler queue");
    return true;
}

void ModbusCommandModule::stop()
{
    if (!m_running) {
        return;
    }
    m_running = false;
    m_gateway = nullptr;
    LOG_INFO("[ModbusCommand] Adapter stopped");
}

bool ModbusCommandModule::submitSingleWrite(
    uint16_t address, uint16_t value, const std::string& name)
{
    if (!m_running || !m_gateway) {
        return false;
    }
    BeiAng4CPGateway* const gateway = m_gateway;
    DataManager* const dataManager = m_dataManager;
    const bool queued = gateway->submitHoldingRegisterWrite(
        address,
        value,
        [gateway, dataManager, name, address](bool success) {
            if (success) {
                LOG_INFO("[ModbusCommand] Completed: {}, address={:#06x}, count=1",
                    name, address);
                queueHoldingReadback(gateway, dataManager, address, 1, name);
            } else {
                LOG_ERROR("[ModbusCommand] Failed: {}, address={:#06x}, count=1",
                    name, address);
            }
        });
    return queued;
}

bool ModbusCommandModule::submitMultipleWrite(
    uint16_t startAddress, std::vector<uint16_t> values, const std::string& name)
{
    if (!m_running || !m_gateway || values.empty() || values.size() > 50) {
        return false;
    }
    const std::size_t count = values.size();
    BeiAng4CPGateway* const gateway = m_gateway;
    DataManager* const dataManager = m_dataManager;
    const bool queued = gateway->submitMultipleRegisterWrite(
        startAddress,
        std::move(values),
        [gateway, dataManager, name, startAddress, count](bool success) {
            if (success) {
                LOG_INFO("[ModbusCommand] Completed: {}, address={:#06x}, count={}",
                    name, startAddress, count);
                queueHoldingReadback(
                    gateway,
                    dataManager,
                    startAddress,
                    static_cast<uint16_t>(count),
                    name);
            } else {
                LOG_ERROR("[ModbusCommand] Failed: {}, address={:#06x}, count={}",
                    name, startAddress, count);
            }
        });
    return queued;
}

std::size_t ModbusCommandModule::pendingCount() const
{
    return m_gateway ? m_gateway->pendingWriteCount() : 0;
}

ModbusCommandSubmitResult ModbusCommandModule::submitModuleSwitch(
    uint16_t address, bool enabled, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    if (address != ModbusCommandPolicy::FRESH_SWITCH
        && address != ModbusCommandPolicy::PURE_SWITCH
        && address != ModbusCommandPolicy::HUMIDITY_SWITCH) {
        return rejectedResult("不支持的模块开关地址");
    }

    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    // 互斥联动（开新风→设备关超净；开超净→设备关新风/调湿；开调湿→设备
    // 关超净）由 4CP 设备端自动执行，屏只下发本条开关命令，读回反映联动结果。
    if (!submitSingleWrite(address, enabled ? 1 : 0, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}

ModbusCommandSubmitResult ModbusCommandModule::submitModuleState(
    bool fresh, bool pure, bool humidity, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    if (!fresh && !pure && !humidity) {
        // 关机 = 三个模块全关（关闭不触发设备互斥联动，需逐个下发）。
        if (!submitMultipleWrite(
                ModbusCommandPolicy::FRESH_SWITCH, {0, 0, 0}, name)) {
            return unavailableResult("Modbus命令队列不可用或已满");
        }
        return acceptedResult();
    }

    // 开机 = 单写要开的模块开关；互斥模块的联动关闭由设备端自动执行。
    const uint16_t address = fresh
        ? ModbusCommandPolicy::FRESH_SWITCH
        : pure ? ModbusCommandPolicy::PURE_SWITCH
               : ModbusCommandPolicy::HUMIDITY_SWITCH;
    if (!submitSingleWrite(address, 1, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}

ModbusCommandSubmitResult ModbusCommandModule::submitFreshControl(
    uint16_t address, uint16_t value, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    const ControlStatus& control = snapshot.gatewayData.getControlStatus();
    ModbusCommandPolicy::FreshControlState state;
    state.freshOn = control.freshAirModuleOn;
    state.runMode = static_cast<uint16_t>(control.runMode);
    state.freshModeMaxGear = static_cast<uint16_t>(control.fanMaxGear);
    state.recirculationMaxGear =
        static_cast<uint16_t>(control.fanMaxGearRecirc);

    const ModbusCommandPolicy::Decision decision =
        ModbusCommandPolicy::validateFreshControl(state, address, value);
    if (decision != ModbusCommandPolicy::Decision::Allow) {
        return rejectedResult(
            ModbusCommandPolicy::decisionMessage(decision));
    }
    if (!submitSingleWrite(address, value, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}

ModbusCommandSubmitResult ModbusCommandModule::submitHumiditySwitch(
    uint16_t address, bool enabled, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    ModbusCommandPolicy::HumidityControlState state;
    state.humidityModuleOn =
        snapshot.gatewayData.getControlStatus().humidityModuleOn;
    const ModbusCommandPolicy::Decision decision =
        ModbusCommandPolicy::validateHumiditySwitch(state, address);
    if (decision != ModbusCommandPolicy::Decision::Allow) {
        return rejectedResult(ModbusCommandPolicy::decisionMessage(decision));
    }
    if (!submitSingleWrite(address, enabled ? 1 : 0, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}

ModbusCommandSubmitResult ModbusCommandModule::submitFactoryWrite(
    uint16_t address, uint16_t value, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    ModbusCommandPolicy::FactoryControlState state;
    state.factoryTestActive =
        snapshot.gatewayData.getDeviceInfo().factoryTestActive;
    const ModbusCommandPolicy::Decision decision =
        ModbusCommandPolicy::validateFactoryWrite(state, address);
    if (decision != ModbusCommandPolicy::Decision::Allow) {
        return rejectedResult(ModbusCommandPolicy::decisionMessage(decision));
    }
    if (!submitSingleWrite(address, value, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}

ModbusCommandSubmitResult ModbusCommandModule::submitFreshRunMode(
    uint16_t runMode, const std::string& name)
{
    if (!m_running || !m_gateway || !m_dataManager) {
        return unavailableResult("Modbus命令队列不可用");
    }
    const BackendRuntimeSnapshot snapshot =
        m_dataManager->getBackendRuntimeSnapshot();
    if (!snapshot.registerCache.holdingValid) {
        return unavailableResult("保持寄存器缓存尚未建立");
    }

    const ControlStatus& control = snapshot.gatewayData.getControlStatus();
    ModbusCommandPolicy::FreshControlState state;
    state.freshOn = control.freshAirModuleOn;
    const ModbusCommandPolicy::Decision decision =
        ModbusCommandPolicy::validateFreshMode(state, runMode);
    if (decision != ModbusCommandPolicy::Decision::Allow) {
        return rejectedResult(ModbusCommandPolicy::decisionMessage(decision));
    }

    // v1.22：运行模式是 1007H 的单值写入（3=自动模式），
    // 不再组合写 1006H（该寄存器已改为一键离家开关）。
    if (!submitSingleWrite(ModbusCommandPolicy::FRESH_RUN_MODE, runMode, name)) {
        return unavailableResult("Modbus命令队列不可用或已满");
    }
    return acceptedResult();
}
