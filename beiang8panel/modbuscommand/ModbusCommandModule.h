/**
 * Modbus 写命令模块。
 *
 * HTTP 线程只负责校验并投递命令；唯一 TTY 调度器线程负责实际执行。
 * 命令投递和写成功都不伪造实际状态；写帧成功后，只回读本次写入的
 * 连续寄存器并原子发布确认值，正常周期采集仍持续校准完整设备状态。
 */

#ifndef MODBUSCOMMANDMODULE_H
#define MODBUSCOMMANDMODULE_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

class BeiAng4CPGateway;
class DataManager;

enum class ModbusCommandSubmitStatus {
    Accepted,
    Rejected,
    Unavailable
};

struct ModbusCommandSubmitResult {
    ModbusCommandSubmitStatus status = ModbusCommandSubmitStatus::Unavailable;
    std::string message;

    bool accepted() const
    {
        return status == ModbusCommandSubmitStatus::Accepted;
    }
};

class ModbusCommandModule {
public:
    explicit ModbusCommandModule(DataManager* dataManager);
    ~ModbusCommandModule();

    bool start();
    void stop();

    bool submitSingleWrite(uint16_t address, uint16_t value, const std::string& name);
    bool submitMultipleWrite(uint16_t startAddress,
        std::vector<uint16_t> values,
        const std::string& name);

    // 模块开关单写：互斥联动（开新风→设备关超净；开超净→设备关新风/调湿；
    // 开调湿→设备关超净）由 4CP 设备端自动执行，屏只下发本条命令。
    ModbusCommandSubmitResult submitModuleSwitch(
        uint16_t address, bool enabled, const std::string& name);
    // 一键开/关机：开机=单写要开的模块开关（联动关闭由设备端执行）；
    // 关机=1001H/1002H/1003H 全 0（关闭不触发设备联动，需逐个下发）。
    ModbusCommandSubmitResult submitModuleState(
        bool fresh, bool pure, bool humidity, const std::string& name);

    // 1007H/1008H 共用同一套缓存条件判断（v1.22：1006H改为一键离家开关，不再参与新风控制校验）。
    ModbusCommandSubmitResult submitFreshControl(
        uint16_t address, uint16_t value, const std::string& name);

    // 一个 UI 模式选择对应一次语义命令：只写 1007H（v1.22运行模式含自动=3）。
    ModbusCommandSubmitResult submitFreshRunMode(
        uint16_t runMode, const std::string& name);

    // 加湿(1004H)/除湿(1005H)开关：调湿模块(1003H)开启时只读。
    ModbusCommandSubmitResult submitHumiditySwitch(
        uint16_t address, bool enabled, const std::string& name);

    // 厂测寄存器（102BH/102CH/1038H-103EH）：仅厂测模式(1030H=100)时可写。
    ModbusCommandSubmitResult submitFactoryWrite(
        uint16_t address, uint16_t value, const std::string& name);

    bool isRunning() const { return m_running; }
    std::size_t pendingCount() const;

private:
    DataManager* m_dataManager;
    BeiAng4CPGateway* m_gateway;
    bool m_running;
};

#endif // MODBUSCOMMANDMODULE_H
