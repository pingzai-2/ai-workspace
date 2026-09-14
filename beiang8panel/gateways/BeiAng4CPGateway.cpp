/**
 * 贝昂4CP设备网关实现（使用 libmodbus）
 *
 * 根据协议文档v1.22实现 Modbus 寄存器读写。
 */

#include "BeiAng4CPGateway.h"
#include "common/ProtocolBitWords.h"
#include <algorithm>
#include <chrono>
#include <cstring>
#include <iostream>
#include <spdlog/fmt/ostr.h>
#include <spdlog/spdlog.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <thread>
#include <utility>

using namespace std;
using namespace BeiAng4CPRegisters;

BeiAng4CPGateway::BeiAng4CPGateway(std::unique_ptr<CommunicationScheduler> scheduler,
    const string& port, int baudRate,
    char parity, int dataBits, int stopBits, int responseTimeoutMs)
    : m_scheduler(std::move(scheduler))
    , m_modbus(nullptr)
    , m_isConnected(false)
    , m_deviceStatus(DeviceStatus::Offline)
    , m_slaveId(0xD1) // 默认地址209（0xD1）按协议文档v1.22，4CP默认209
    , m_port(port)
    , m_baudRate(baudRate)
    , m_parity(parity)
    , m_dataBits(dataBits)
    , m_stopBits(stopBits)
    , m_responseTimeoutMs(responseTimeoutMs > 0
          ? responseTimeoutMs
          : MODBUS_RESPONSE_TIMEOUT_MS)
    , m_maxRetryCount(2) // 单个事务最大尝试次数：首次尝试 + 1 次重试
{
}

BeiAng4CPGateway::~BeiAng4CPGateway()
{
    shutdown();
}

void BeiAng4CPGateway::setCommunicationSuccessCallback(
    std::function<void()> callback)
{
    m_communicationSuccessCallback = std::move(callback);
}

bool BeiAng4CPGateway::initialize()
{
    if (!m_scheduler) {
        m_lastError = "Communication scheduler is not configured";
        return false;
    }
    if (!connectDirect()) {
        return false;
    }
    if (!m_scheduler->start()) {
        m_lastError = "Failed to start Modbus master scheduler";
        disconnectDirect();
        return false;
    }
    return true;
}

void BeiAng4CPGateway::shutdown()
{
    if (m_scheduler) {
        m_scheduler->stop();
    }
    disconnectDirect();
}

bool BeiAng4CPGateway::connect()
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        return connectDirect();
    }
    return m_scheduler->executeControl([this]() { return connectDirect(); });
}

bool BeiAng4CPGateway::connectDirect()
{

    if (m_isConnected) {
        return true;
    }

    // 创建 RTU Modbus 上下文 - 使用配置文件中的参数
    m_modbus = modbus_new_rtu(m_port.c_str(), m_baudRate, m_parity, m_dataBits, m_stopBits);
    if (!m_modbus) {
        m_lastError = "Failed to create modbus context";
        spdlog::error("[BeiAng4CPGateway] {}", m_lastError);
        return false;
    }

    // 设置从站地址（协议文档v1.22：4CP默认地址209/0xD1H，全热新风默认193/0xC1H）
    if (modbus_set_slave(m_modbus, m_slaveId) < 0) {
        m_lastError = "Failed to set slave ID";
        spdlog::error("[BeiAng4CPGateway] {}", m_lastError);
        modbus_free(m_modbus);
        m_modbus = nullptr;
        return false;
    }

    // 所有读写共用同一通信脉搏：响应/帧内字节等待由配置控制，
    // 每次实际 Modbus 尝试结束后再由 scheduler 保持 250ms 命令间隔。
    const uint32_t timeoutSeconds = static_cast<uint32_t>(m_responseTimeoutMs / 1000);
    const uint32_t timeoutMicroseconds =
        static_cast<uint32_t>((m_responseTimeoutMs % 1000) * 1000);
    if (modbus_set_response_timeout(m_modbus, timeoutSeconds, timeoutMicroseconds) < 0 ||
        modbus_set_byte_timeout(m_modbus, timeoutSeconds, timeoutMicroseconds) < 0) {
        m_lastError = "Failed to configure Modbus timeout";
        spdlog::error("[BeiAng4CPGateway] {}: {}", m_lastError, modbus_strerror(errno));
        modbus_free(m_modbus);
        m_modbus = nullptr;
        return false;
    }

    // 连接前延迟，确保串口就绪
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    // 连接设备
    if (modbus_connect(m_modbus) < 0) {
        // 记录失败 errno（libmodbus 的 open() 失败会将 errno 原样保留），
        // 供上层区分"串口节点消失"与"设备无响应"两类失败，决定重连策略
        m_lastConnectErrno = errno;
        m_lastError = string("Modbus connect failed: ") + modbus_strerror(m_lastConnectErrno);
        spdlog::error("[BeiAng4CPGateway] {}", m_lastError);
        modbus_free(m_modbus);
        m_modbus = nullptr;
        return false;
    }

#ifdef TIOCEXCL
    // 与通用串口通道保持同一轻量独占边界，避免两路进程同时持有该端点。
    const int serialFd = modbus_get_socket(m_modbus);
    if (serialFd < 0 || ioctl(serialFd, TIOCEXCL) != 0) {
        m_lastConnectErrno = errno;
        m_lastError = string("Failed to exclusively claim Modbus endpoint: ")
            + modbus_strerror(m_lastConnectErrno);
        spdlog::error("[BeiAng4CPGateway] {}", m_lastError);
        modbus_close(m_modbus);
        modbus_free(m_modbus);
        m_modbus = nullptr;
        return false;
    }
#endif

    // 连接后延迟，等待设备稳定
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    m_isConnected = true;
    m_lastConnectErrno = 0; // 连接成功，复位失败原因
    m_deviceStatus = DeviceStatus::Online;
    spdlog::info("[BeiAng4CPGateway] Connected to device at {} ({} baud)", m_port, m_baudRate);
    return true;
}

void BeiAng4CPGateway::disconnect()
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        disconnectDirect();
        return;
    }
    m_scheduler->executeControl([this]() {
        disconnectDirect();
        return true;
    });
}

void BeiAng4CPGateway::disconnectDirect()
{

    if (m_isConnected && m_modbus) {
        // 断开前延迟，确保最后的数据传输完成
        std::this_thread::sleep_for(std::chrono::milliseconds(50));

        modbus_close(m_modbus);
        modbus_free(m_modbus);
        m_modbus = nullptr;
        m_isConnected = false;
        m_deviceStatus = DeviceStatus::Offline;
        spdlog::info("[BeiAng4CPGateway] Disconnected from device");
    }
}

bool BeiAng4CPGateway::reconnect()
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        disconnectDirect();
        return connectDirect();
    }
    return m_scheduler->executeControl([this]() {
        disconnectDirect();
        return connectDirect();
    });
}

bool BeiAng4CPGateway::readDeviceData(GatewayGeneralDataStructure& data,
                                      RawRegisterCache* rawCache)
{
    RawRegisterCache snapshot;
    if (!readRawDeviceData(snapshot)) {
        return false;
    }
    if (rawCache) {
        *rawCache = snapshot;
    }
    return parseRawDeviceData(snapshot, data);
}

bool BeiAng4CPGateway::readRawDeviceData(RawRegisterCache& rawCache)
{
    rawCache = RawRegisterCache();
    const uint16_t readBatchSize = 50;

    for (uint16_t offset = 0; offset < HOLDING_READ_COUNT;) {
        const uint16_t batch = std::min<uint16_t>(readBatchSize, HOLDING_READ_COUNT - offset);
        if (!executeRead([this, offset, batch, &rawCache]() {
                return readHoldingRegisters(
                    HOLDING_READ_START + offset, batch, rawCache.holdingRegs + offset);
            })) {
            return false;
        }
        offset += batch;
    }
    rawCache.holdingValid = true;

    for (uint16_t offset = 0; offset < INPUT_READ_COUNT;) {
        const uint16_t batch = std::min<uint16_t>(readBatchSize, INPUT_READ_COUNT - offset);
        if (!executeRead([this, offset, batch, &rawCache]() {
                return readInputRegistersInternal(
                    INPUT_READ_START + offset, batch, rawCache.inputRegs + offset);
            })) {
            return false;
        }
        offset += batch;
    }
    rawCache.inputValid = true;

    struct DiscreteSegment {
        uint16_t address;
        uint16_t bitOffset;
        uint16_t count;
    };
    const DiscreteSegment segments[] = {
        {DISCRET_CAPABILITY_START, 0, 8},
        {static_cast<uint16_t>(DISCRETE_READ_START + 32), 32, 6},
        {static_cast<uint16_t>(DISCRETE_READ_START + 64), 64, 13},
    };

    bool allDiscreteSegmentsValid = true;
    for (const DiscreteSegment& segment : segments) {
        const bool segmentValid = executeRead([this, &rawCache, segment]() {
            return readDiscreteInputsInternal(
                segment.address,
                segment.count,
                rawCache.discreteInputs + segment.bitOffset);
        });
        allDiscreteSegmentsValid = segmentValid && allDiscreteSegmentsValid;
    }
    rawCache.discreteValid = allDiscreteSegmentsValid;
    if (rawCache.discreteValid) {
        for (uint16_t bit = 0; bit < RawRegisterCache::DISCRETE_COUNT; ++bit) {
            ProtocolData::bit_word_set(
                rawCache.discreteWords, bit, rawCache.discreteInputs[bit]);
        }
    }
    return true;
}

bool BeiAng4CPGateway::parseRawDeviceData(
    const RawRegisterCache& rawCache,
    GatewayGeneralDataStructure& data)
{
    if (!rawCache.holdingValid || !rawCache.inputValid) {
        m_lastError = "Raw register snapshot is incomplete";
        return false;
    }

    applyHoldingRegisterData(rawCache.holdingRegs, data);

    const uint16_t* inputRegs = rawCache.inputRegs;
    auto& ctrlStatus = data.getControlStatus();
    auto& deviceInfo = data.getDeviceInfo();

    // 基础设备信息（2000H-2004H）
    char flag[3] = {
        static_cast<char>((inputRegs[0] >> 8) & 0xFF),
        static_cast<char>(inputRegs[0] & 0xFF),
        '\0'
    };
    deviceInfo.factoryFlag = string(flag);                                  // 2000H 工厂标志
    deviceInfo.deviceModelRaw = inputRegs[1];                               // 2001H 机型
    deviceInfo.deviceModel = inputRegs[1] == 0
        ? "4CP"
        : (inputRegs[1] == 1 ? "全热新风" : std::to_string(inputRegs[1]));
    deviceInfo.versionRaw = inputRegs[2];                                   // 2002H 版本原值
    {
        // 版本号 = 寄存器值÷100（例：0101→1.01），保留两位小数展示
        char versionBuf[16];
        snprintf(versionBuf, sizeof(versionBuf), "%.2f", inputRegs[2] / 100.0);
        deviceInfo.version = versionBuf;
    }
    ctrlStatus.fanMaxGear = inputRegs[3];                                   // 2003H 新风模式最大档位
    ctrlStatus.fanMaxGearRecirc = inputRegs[4];                             // 2004H 内循环/混风最大档位
    // 风机档位（2005H-2008H）
    data.getFanGears().fan1Gear = inputRegs[5];
    data.getFanGears().fan2Gear = inputRegs[6];
    data.getFanGears().fan3Gear = inputRegs[7];
    data.getFanGears().fan4Gear = inputRegs[8];
    // 风机RPM（2009H-200CH）
    data.getFanRPM().fan1RPM = inputRegs[9];
    data.getFanRPM().fan2RPM = inputRegs[10];
    data.getFanRPM().fan3RPM = inputRegs[11];
    data.getFanRPM().fan4RPM = inputRegs[12];
    // RA1传感器（200DH-2010H）
    data.getRA1Sensor().temperature = temperatureFromRegister(inputRegs[13]);
    data.getRA1Sensor().humidity = inputRegs[14];
    data.getRA1Sensor().pm25 = inputRegs[15];
    data.getRA1Sensor().co2 = inputRegs[16];
    // OA传感器（2011H-2014H）
    data.getOASensor().temperature = temperatureFromRegister(inputRegs[17]);
    data.getOASensor().humidity = inputRegs[18];
    data.getOASensor().pm25 = inputRegs[19];
    data.getOASensor().co2 = inputRegs[20];
    // SA传感器（2015H-2018H）
    data.getSASensor().temperature = temperatureFromRegister(inputRegs[21]);
    data.getSASensor().humidity = inputRegs[22];
    data.getSASensor().pm25 = inputRegs[23];
    data.getSASensor().co2 = inputRegs[24];
    // 空气质量（2019H-201AH，实际数值/100）
    data.getAirQuality().tvoc = RAW_TO_TVOC(inputRegs[25]);
    data.getAirQuality().formaldehyde = RAW_TO_TVOC(inputRegs[26]);
    // 系统状态（201BH-2023H）
    data.getCompressorStatus().operationFrequency = inputRegs[27];          // 201BH 压缩机运行频率
    ctrlStatus.auxHeat = static_cast<AuxHeatMode>(inputRegs[28]);           // 201CH 电辅热状态
    ctrlStatus.autoCirculationDisplay = inputRegs[29];                      // 201DH 自动模式时内外循环显示
    // 进风口/出风口（201EH-2021H）
    data.getInletAirSensor().temperature = temperatureFromRegister(inputRegs[30]);
    data.getInletAirSensor().humidity = inputRegs[31];
    data.getOutletAirSensor().temperature = temperatureFromRegister(inputRegs[32]);  // 2020H 预留
    data.getOutletAirSensor().humidity = inputRegs[33];                               // 2021H 预留
    // 高低压压力（2022H-2023H，bar，实际值/100）
    data.getCompressorStatus().highPressure = RAW_TO_PRESSURE(inputRegs[34]);
    data.getCompressorStatus().lowPressure = RAW_TO_PRESSURE(inputRegs[35]);
    // 加湿浮子状态（2024H-2025H）
    data.getDrainageSystem().inletFloatRaw = inputRegs[36];                 // 2024H 原值
    data.getDrainageSystem().drainFloatRaw = inputRegs[37];                 // 2025H 原值
    // 运行时间（2026H-202AH）
    data.getRuntimeStatistics().systemRuntimeDays = inputRegs[38];          // 2026H 系统运行时间(天)
    data.getRuntimeStatistics().fan1Runtime = inputRegs[39];                // 2027H FAN1累计
    data.getRuntimeStatistics().fan2Runtime = inputRegs[40];                // 2028H FAN2累计
    data.getRuntimeStatistics().fan3Runtime = inputRegs[41];                // 2029H FAN3累计
    data.getRuntimeStatistics().fan4Runtime = inputRegs[42];                // 202AH FAN4累计
    // 压缩机温度与电压（202BH-202FH）
    data.getCompressorStatus().dischargeTemperature = temperatureFromRegister(inputRegs[43]); // 202BH 排气温度
    data.getCompressorStatus().suctionTemperature = temperatureFromRegister(inputRegs[44]);   // 202CH 吸气温度
    data.getCompressorStatus().evaporatorTemperature = temperatureFromRegister(inputRegs[45]); // 202DH 蒸发器盘管温度
    data.getCompressorStatus().reservedTemperatureRaw = inputRegs[46];      // 202EH 预留温度原值
    data.getCompressorStatus().acVoltageRaw = inputRegs[47];                // 202FH 交流电压检测值
    // 主控板版本时间字符串（2030H-203BH，Char[24]）
    {
        char versionChars[25] = {0};
        for (int i = 0; i < 12; i++) {
            versionChars[i * 2] = static_cast<char>((inputRegs[48 + i] >> 8) & 0xFF);
            versionChars[i * 2 + 1] = static_cast<char>(inputRegs[48 + i] & 0xFF);
        }
        deviceInfo.controllerVersionTime = string(versionChars);
    }

    if (rawCache.discreteValid) {
        const uint8_t* flags = rawCache.discreteInputs;
        auto& caps = data.getCapabilityFlags();
        caps.hasHumidificationModule = (flags[DISCRET_CAPABILITY_HUMIDITY_MODULE] != 0);
        caps.hasDehumidification = (flags[DISCRET_CAPABILITY_DEHUMIDIFICATION] != 0);
        caps.hasBypassMode = (flags[DISCRET_CAPABILITY_BYPASS_MODE] != 0);
        caps.hasIefPurification = (flags[DISCRET_CAPABILITY_IEF] != 0);
        caps.hasDisinfectModule = (flags[DISCRET_CAPABILITY_DISINFECT] != 0);
        caps.hasElectricHeating = (flags[DISCRET_CAPABILITY_ELECTRIC_HEATING] != 0);
        caps.hasFrostProtection = (flags[DISCRET_CAPABILITY_FROST_PROTECTION] != 0);
        caps.hasFormaldehydeHcho = (flags[DISCRET_CAPABILITY_HCHO] != 0);

        data.getCirculationPump().pumpStatus =
            (flags[DISCRET_HUMIDIFICATION_PUMP_STATUS] != 0);
        data.getDrainageSystem().waterInletValve =
            (flags[DISCRET_WATER_INLET_VALVE_STATUS] != 0);
        data.getDrainageSystem().drainValveStatus =
            (flags[DISCRET_DRAIN_PUMP_STATUS] != 0);
        data.getCompressorStatus().compressorStatus =
            flags[DISCRET_COMPRESSOR_STATUS] != 0 ? 1 : 0;
        data.getCompressorStatus().defrosting =
            (flags[DISCRET_DEFROSTING] != 0);
        data.getDrainageSystem().offAirQualityDetecting =
            (flags[DISCRET_OFF_AIR_QUALITY_DETECTING] != 0);
    }

    return true;
}

void BeiAng4CPGateway::applyHoldingRegisterData(
    const uint16_t* holdingRegs,
    GatewayGeneralDataStructure& data)
{
    if (!holdingRegs) {
        return;
    }
    auto& ctrlStatus = data.getControlStatus();
    auto& deviceInfo = data.getDeviceInfo();
    auto& envSettings = data.getEnvironmentSettings();
    auto& rtcTime = data.getRtcTime();
    auto& dcParams = data.getDeviceControlParams();
    auto& timing = data.getTimingSettings();
    auto& filter = data.getFilterMaintenance();
    auto& factory = data.getFactoryTestSettings();
    auto& fanFlow = data.getFanFlow();
    auto& dampers = data.getDamperControl();
    auto& valves = data.getValveStatus();

    // 总开关与模块开关（1000H-1005H）。这里解析的是设备实际读回，
    // 即使 1001H..1003H 不符合后端写入互斥规则，也必须逐项原样发布。
    // 互斥整合只属于 ModbusCommandPolicy 的写命令组装职责。
    ctrlStatus.switchOn = (holdingRegs[0] != 0);                            // 1000H 总开关
    ctrlStatus.freshAirModuleOn = (holdingRegs[1] != 0);                    // 1001H 新风模块开关
    ctrlStatus.superPureOn = (holdingRegs[2] != 0);                         // 1002H 超净模式开关
    ctrlStatus.humidityModuleOn = (holdingRegs[3] != 0);                    // 1003H 调湿模块开关
    ctrlStatus.humidificationOn = (holdingRegs[4] != 0);                    // 1004H 加湿开关
    ctrlStatus.dehumidificationOn = (holdingRegs[5] != 0);                  // 1005H 除湿开关
    // 新风模块控制（1006H-1008H）
    ctrlStatus.leaveHomeOn = (holdingRegs[6] != 0);                         // 1006H 一键离家开关
    ctrlStatus.runMode = static_cast<AirCirculationMode>(holdingRegs[7]);   // 1007H 运行模式(0-5)
    ctrlStatus.fanGear = holdingRegs[8];                                    // 1008H 风量档位
    // 排风档位（1009H，预留）与整机运行模式（100AH）
    dcParams.exhaustFanGear = holdingRegs[9];                               // 1009H 排风档位
    ctrlStatus.wholeUnitRunMode = holdingRegs[10];                          // 100AH 整机运行模式
    // 无极风量控制（100BH-100EH）
    ctrlStatus.steplessFanSwitch = (holdingRegs[11] != 0);                  // 100BH 无极风量开关
    ctrlStatus.freshFanDutyCycle = holdingRegs[12];                         // 100CH 新风占空比(供状态接口)
    dcParams.freshAirDutyCycle = holdingRegs[12];                           // 100CH 新风占空比
    dcParams.exhaustAirDutyCycle = holdingRegs[13];                         // 100DH 排风占空比
    dcParams.boostFanDutyCycle = holdingRegs[14];                           // 100EH 增压占空比
    // 环境目标设定（100FH-1015H）
    envSettings.targetHumidity = holdingRegs[15];                           // 100FH 目标湿度
    envSettings.targetTemperature = holdingRegs[16];                        // 1010H 目标温度(实际×10)
    ctrlStatus.plasmaDisinfectOn = (holdingRegs[17] != 0);                  // 1011H 等离子消毒
    ctrlStatus.iefPurification = (holdingRegs[18] != 0);                    // 1012H IEF开关
    dcParams.auxHeatSetting = holdingRegs[19];                              // 1013H 电辅热选择设定（运行状态在输入寄存器201CH解析）
    envSettings.humidityIntensity = static_cast<HumidityIntensity>(holdingRegs[20]); // 1014H 强度
    envSettings.saFanRatio = holdingRegs[21] / 10.0f;                       // 1015H SA比例(实际值×10)
    // 1016H-101AH 预留
    // RTC时间（101BH-101FH，结构体打包：年16位，其余字节两两拼字）
    rtcTime.year = holdingRegs[27];                                         // 101BH 年
    rtcTime.month = static_cast<uint8_t>(holdingRegs[28] >> 8);             // 101CH 月(高字节)
    rtcTime.day = static_cast<uint8_t>(holdingRegs[28] & 0xFF);             // 101CH 日(低字节)
    rtcTime.hour = static_cast<uint8_t>(holdingRegs[29] >> 8);              // 101DH 时(高字节，bit7=PM)
    rtcTime.minute = static_cast<uint8_t>(holdingRegs[29] & 0xFF);          // 101DH 分(低字节)
    rtcTime.second = static_cast<uint8_t>(holdingRegs[30] >> 8);            // 101EH 秒(高字节)
    rtcTime.week = static_cast<uint8_t>(holdingRegs[30] & 0xFF);            // 101EH 周(低字节)
    rtcTime.format = static_cast<uint8_t>(holdingRegs[31] >> 8);            // 101FH 格式(高字节)
    // 定时/延时参数（1020H-1023H）
    timing.fanDelayOffTime = holdingRegs[32];                               // 1020H 延时关风机
    timing.circPumpOnTime = holdingRegs[33];                                // 1021H 循环泵开时间
    timing.circPumpOffTime = holdingRegs[34];                               // 1022H 循环泵关时间
    timing.drainOnTime = holdingRegs[35];                                   // 1023H 排水开时间
    data.getCirculationPump().pumpOnTime = holdingRegs[33];
    data.getCirculationPump().pumpOffTime = holdingRegs[34];
    data.getDrainageSystem().drainOnTime = holdingRegs[35];
    // 1024H 设备地址
    deviceInfo.deviceAddress = holdingRegs[36];                             // 1024H 设备地址
    // 关机状态下空气品质检测（1025H-1027H）
    timing.offModeAqSwitch = holdingRegs[37];                               // 1025H 检测开关
    timing.offModeAqInterval = holdingRegs[38];                             // 1026H 检测间隔
    timing.offModeAqRuntime = holdingRegs[39];                              // 1027H 检测运行时间
    // 压缩机与高低压开关（1028H-102CH）
    dcParams.compressorEEVOpening = holdingRegs[40];                        // 1028H 电子膨胀阀开度
    dcParams.compressorFrequencySet = holdingRegs[41];                      // 1029H 运行频率设定值
    dcParams.compressorFrequencyMax = holdingRegs[42];                      // 102AH 频率上限设定值
    factory.highPressureSwitchOn = (holdingRegs[43] != 0);                  // 102BH 高压开关
    factory.lowPressureSwitchOn = (holdingRegs[44] != 0);                   // 102CH 低压开关
    // 102DH-102FH 预留
    // 1030H 厂测模式（100:测试模式；其他均为正常运行模式）
    deviceInfo.factoryTestMode = holdingRegs[48];
    deviceInfo.factoryTestActive = (holdingRegs[48] == FACTORY_TEST_MODE_VALUE);
    // 滤网/保养剩余时间（1031H-1036H）
    filter.filter1Remaining = holdingRegs[49];                              // 1031H 初效滤网1
    filter.filter2Remaining = holdingRegs[50];                              // 1032H 中效滤网2
    filter.filter3Remaining = holdingRegs[51];                              // 1033H 高效滤网3
    filter.humidityFilterRemaining = holdingRegs[52];                       // 1034H 加湿模块
    filter.iefCleanRemaining = holdingRegs[53];                             // 1035H IEF需清洗
    filter.wholeUnitMaintenance = holdingRegs[54];                          // 1036H 整机保养
    // 1037H 预留
    // 厂测设定（1038H-103EH，仅厂测模式可写，读回原样发布）
    factory.fan1CurrentSetting = holdingRegs[56];                           // 1038H FAN1风量设定值
    factory.fan2CurrentSetting = holdingRegs[57];                           // 1039H FAN2
    factory.fan3CurrentSetting = holdingRegs[58];                           // 103AH FAN3
    factory.fan4CurrentSetting = holdingRegs[59];                           // 103BH FAN4
    valves.valve1 = static_cast<ValveStatus>(holdingRegs[60]);              // 103CH 阀门1状态设定
    valves.valve2 = static_cast<ValveStatus>(holdingRegs[61]);              // 103DH 阀门2
    valves.valve3 = static_cast<ValveStatus>(holdingRegs[62]);              // 103EH 阀门3
    // 103FH 清除运行时间(只写)，1040H 恢复出厂(只写)
    // 风机内外循环各档风量设定（1041H-1070H，v1.22由输入寄存器移到保持寄存器）
    for (int i = 0; i < 6; i++) {
        fanFlow.fan1ExternalFlow[i] = holdingRegs[65 + i];   // 1041H-1046H FAN1外循环1-6档
        fanFlow.fan1InternalFlow[i] = holdingRegs[71 + i];   // 1047H-104CH FAN1内循环1-6档
        fanFlow.fan2ExternalFlow[i] = holdingRegs[77 + i];   // 104DH-1052H FAN2外循环
        fanFlow.fan2InternalFlow[i] = holdingRegs[83 + i];   // 1053H-1058H FAN2内循环
        fanFlow.fan3ExternalFlow[i] = holdingRegs[89 + i];   // 1059H-105EH FAN3外循环
        fanFlow.fan3InternalFlow[i] = holdingRegs[95 + i];   // 105FH-1064H FAN3内循环
        fanFlow.fan4ExternalFlow[i] = holdingRegs[101 + i];  // 1065H-106AH FAN4外循环
        fanFlow.fan4InternalFlow[i] = holdingRegs[107 + i];  // 106BH-1070H FAN4内循环
    }
    // 风阀设定（1071H-1076H，v1.22新增）
    dampers.damper1Direction = (holdingRegs[113] != 0);                     // 1071H 风阀1方向
    dampers.damper2Direction = (holdingRegs[114] != 0);                     // 1072H 风阀2方向
    dampers.damper3Direction = (holdingRegs[115] != 0);                     // 1073H 风阀3方向
    dampers.damper1Steps = holdingRegs[116];                                // 1074H 风阀1步数
    dampers.damper2Steps = holdingRegs[117];                                // 1075H 风阀2步数
    dampers.damper3Steps = holdingRegs[118];                                // 1076H 风阀3步数
}

bool BeiAng4CPGateway::readManualModeData(ManualModeDataStructure& data)
{
    // Manual mode data is included in the general data structure
    // For now, return true as stub
    return true;
}

bool BeiAng4CPGateway::readSmartModeData(SmartModeDataStructure& data)
{
    // Smart mode data is included in the general data structure
    // For now, return true as stub
    return true;
}

// ========== 设备控制（根据协议文档v1.22） ==========

bool BeiAng4CPGateway::setPowerOn(bool on)
{
    return setSwitchControl(on);
}

bool BeiAng4CPGateway::setFanSpeed(int level)
{
    return setFanGear(level);
}

bool BeiAng4CPGateway::setSwitchControl(bool on)
{
    return writeSingleRegister(SWITCH_CONTROL, on ? 1 : 0); // 1000H 总开关
}

bool BeiAng4CPGateway::setFreshAirModuleSwitch(bool on)
{
    return writeSingleRegister(FRESH_AIR_MODULE_SWITCH, on ? 1 : 0); // 1001H 新风模块开关
}

bool BeiAng4CPGateway::setSuperPureModeSwitch(bool on)
{
    return writeSingleRegister(SUPER_PURE_MODE_SWITCH, on ? 1 : 0); // 1002H 超净模式开关
}

bool BeiAng4CPGateway::setHumidityModuleSwitch(bool on)
{
    return writeSingleRegister(HUMIDITY_MODULE_SWITCH, on ? 1 : 0); // 1003H 调湿模块开关
}

bool BeiAng4CPGateway::setHumidification(bool on)
{
    return writeSingleRegister(HUMIDIFICATION_SWITCH, on ? 1 : 0); // 1004H 加湿开关
}

bool BeiAng4CPGateway::setDehumidification(bool on)
{
    return writeSingleRegister(DEHUMIDIFICATION_SWITCH, on ? 1 : 0); // 1005H 除湿开关
}

bool BeiAng4CPGateway::setLeaveHomeSwitch(bool on)
{
    return writeSingleRegister(LEAVE_HOME_SWITCH, on ? 1 : 0); // 1006H 一键离家开关
}

bool BeiAng4CPGateway::setHumidityControlSwitch(bool on)
{
    return setHumidityModuleSwitch(on); // 映射到1003H调湿模块开关
}

bool BeiAng4CPGateway::setRunMode(AirCirculationMode mode)
{
    // 运行模式（0:内循环, 1:内循环/混风, 2:全热新风/节能新风, 3:自动, 4:旁通/换气, 5:睡眠）
    if (static_cast<uint16_t>(mode) > 5) {
        m_lastError = "Invalid run mode";
        return false;
    }
    return writeSingleRegister(FRESH_AIR_RUN_MODE, static_cast<uint16_t>(mode)); // 1007H
}

bool BeiAng4CPGateway::setFanGear(int gear)
{
    if (gear < 0 || gear > 6) {
        m_lastError = "Invalid fan gear";
        return false;
    }
    return writeSingleRegister(FAN_GEAR, static_cast<uint16_t>(gear)); // 1008H 风量档位
}

bool BeiAng4CPGateway::setExhaustFanGear(int gear)
{
    if (gear < 0 || gear > 6) {
        m_lastError = "Invalid exhaust fan gear";
        return false;
    }
    return writeSingleRegister(EXHAUST_FAN_GEAR, static_cast<uint16_t>(gear)); // 1009H 排风档位(预留)
}

bool BeiAng4CPGateway::setWholeUnitRunMode(int mode)
{
    // 整机运行模式（0:无/手动 1:标准 2:会客 3:干爽 4:温润 5:旅行）
    if (mode < 0 || mode > 5) {
        m_lastError = "Invalid whole unit run mode";
        return false;
    }
    return writeSingleRegister(WHOLE_UNIT_RUN_MODE, static_cast<uint16_t>(mode)); // 100AH
}

bool BeiAng4CPGateway::setSteplessFanControl(bool on)
{
    return writeSingleRegister(STEPLESS_FAN_CONTROL, on ? 1 : 0); // 100BH 无极风量开关
}

bool BeiAng4CPGateway::setFreshFanDutyCycle(int duty)
{
    return writeSingleRegister(FRESH_FAN_DUTY_CYCLE, dutyCycleToRegister(duty)); // 100CH 新风占空比
}

bool BeiAng4CPGateway::setExhaustFanDutyCycle(int duty)
{
    return writeSingleRegister(EXHAUST_FAN_DUTY_CYCLE, dutyCycleToRegister(duty)); // 100DH 排风占空比
}

bool BeiAng4CPGateway::setBoostFanDutyCycle(int duty)
{
    return writeSingleRegister(BOOST_FAN_DUTY_CYCLE, dutyCycleToRegister(duty)); // 100EH 增压占空比
}

bool BeiAng4CPGateway::setTargetHumidity(int humidity)
{
    if (humidity < 30 || humidity > 70) {
        m_lastError = "Invalid target humidity";
        return false;
    }
    return writeSingleRegister(TARGET_HUMIDITY, static_cast<uint16_t>(humidity)); // 100FH 目标湿度
}

bool BeiAng4CPGateway::setTargetTemperature(int tempX10)
{
    // 目标温度设定：范围160~310（实际设定温度×10）
    if (tempX10 < 160 || tempX10 > 310) {
        m_lastError = "Invalid target temperature";
        return false;
    }
    return writeSingleRegister(TARGET_TEMPERATURE, static_cast<uint16_t>(tempX10)); // 1010H
}

bool BeiAng4CPGateway::setPlasmaDisinfectSwitch(bool on)
{
    return writeSingleRegister(PLASMA_DISINFECT_SWITCH, on ? 1 : 0); // 1011H 等离子消毒开关
}

bool BeiAng4CPGateway::setIEFPurification(bool on)
{
    return writeSingleRegister(IEF_SWITCH, on ? 1 : 0); // 1012H IEF开关
}

bool BeiAng4CPGateway::setAuxHeat(AuxHeatMode mode)
{
    return writeSingleRegister(AUX_HEAT, static_cast<uint16_t>(mode)); // 1013H 电辅热选择
}

bool BeiAng4CPGateway::setHumidityIntensity(HumidityIntensity intensity)
{
    return writeSingleRegister(HUMIDITY_INTENSITY, static_cast<uint16_t>(intensity)); // 1014H 强度
}

bool BeiAng4CPGateway::setSAFanRatio(float ratio)
{
    return writeSingleRegister(SA_FAN_RATIO, static_cast<uint16_t>(ratio * 10)); // 1015H SA比例
}

bool BeiAng4CPGateway::setFanDelayOffTime(int minutes)
{
    return writeSingleRegister(FAN_DELAY_OFF_TIME, static_cast<uint16_t>(minutes)); // 1020H
}

bool BeiAng4CPGateway::setHumidificationPumpOnTime(int seconds)
{
    return writeSingleRegister(HUMIDIFICATION_PUMP_ON_TIME, static_cast<uint16_t>(seconds)); // 1021H
}

bool BeiAng4CPGateway::setHumidificationPumpOffTime(int seconds)
{
    return writeSingleRegister(HUMIDIFICATION_PUMP_OFF_TIME, static_cast<uint16_t>(seconds)); // 1022H
}

bool BeiAng4CPGateway::setHumidificationDrainOnTime(int seconds)
{
    return writeSingleRegister(HUMIDIFICATION_DRAIN_ON_TIME, static_cast<uint16_t>(seconds)); // 1023H
}

bool BeiAng4CPGateway::setDeviceAddress(uint8_t address)
{
    // v1.22：设备地址范围 0-254
    if (address > 254) {
        m_lastError = "Invalid device address";
        return false;
    }
    return writeSingleRegister(DEVICE_ADDRESS, static_cast<uint16_t>(address)); // 1024H 设备地址
}

bool BeiAng4CPGateway::setOffAirQualityDetectSwitch(bool on)
{
    return writeSingleRegister(OFF_AIR_QUALITY_DETECT_SWITCH, on ? 1 : 0); // 1025H
}

bool BeiAng4CPGateway::setOffAirQualityDetectInterval(int minutes)
{
    return writeSingleRegister(OFF_AIR_QUALITY_DETECT_INTERVAL, static_cast<uint16_t>(minutes)); // 1026H
}

bool BeiAng4CPGateway::setOffAirQualityDetectRuntime(int minutes)
{
    return writeSingleRegister(OFF_AIR_QUALITY_DETECT_RUNTIME, static_cast<uint16_t>(minutes)); // 1027H
}

bool BeiAng4CPGateway::setCompressorEEVOpening(int opening)
{
    // v1.22：电子膨胀阀开度范围 0-500
    if (opening < 0 || opening > 500) {
        m_lastError = "Invalid compressor EEV opening";
        return false;
    }
    return writeSingleRegister(COMPRESSOR_EEV_OPENING, static_cast<uint16_t>(opening)); // 1028H
}

bool BeiAng4CPGateway::setCompressorFrequencySet(int freq)
{
    // v1.22：运行频率设定值范围 0-90 Hz
    if (freq < 0 || freq > 90) {
        m_lastError = "Invalid compressor frequency set";
        return false;
    }
    return writeSingleRegister(COMPRESSOR_FREQUENCY_SET, static_cast<uint16_t>(freq)); // 1029H
}

bool BeiAng4CPGateway::setCompressorFrequencyMax(int freq)
{
    // v1.22：频率上限设定值范围 60-95 Hz
    if (freq < 60 || freq > 95) {
        m_lastError = "Invalid compressor frequency max";
        return false;
    }
    return writeSingleRegister(COMPRESSOR_FREQUENCY_MAX, static_cast<uint16_t>(freq)); // 102AH
}

bool BeiAng4CPGateway::setHighPressureSwitch(bool on)
{
    // 仅厂测模式时可写（1030H=100），由调用方保证前置条件
    return writeSingleRegister(HIGH_PRESSURE_SWITCH, on ? 1 : 0); // 102BH 高压开关
}

bool BeiAng4CPGateway::setLowPressureSwitch(bool on)
{
    // 仅厂测模式时可写（1030H=100），由调用方保证前置条件
    return writeSingleRegister(LOW_PRESSURE_SWITCH, on ? 1 : 0); // 102CH 低压开关
}

// 滤网保养时间设置实现
bool BeiAng4CPGateway::setFactoryTestMode(bool testMode)
{
    // v1.22：100=测试模式；其他均为正常运行模式（这里退出时写0）
    return writeSingleRegister(
        FACTORY_TEST_MODE,
        testMode ? FACTORY_TEST_MODE_VALUE : 0); // 1030H 厂测模式
}

bool BeiAng4CPGateway::setFilter1RemainingTime(int hours)
{
    return writeSingleRegister(FILTER1_REMAINING_TIME, static_cast<uint16_t>(hours)); // 1031H
}

bool BeiAng4CPGateway::setFilter2RemainingTime(int hours)
{
    return writeSingleRegister(FILTER2_REMAINING_TIME, static_cast<uint16_t>(hours)); // 1032H
}

bool BeiAng4CPGateway::setFilter3RemainingTime(int hours)
{
    return writeSingleRegister(FILTER3_REMAINING_TIME, static_cast<uint16_t>(hours)); // 1033H
}

bool BeiAng4CPGateway::setHumidityFilterRemainingTime(int hours)
{
    return writeSingleRegister(HUMIDITY_FILTER_REMAINING_TIME, static_cast<uint16_t>(hours)); // 1034H
}

bool BeiAng4CPGateway::setIEFCleanRemainingTime(int hours)
{
    return writeSingleRegister(IEF_CLEAN_REMAINING_TIME, static_cast<uint16_t>(hours)); // 1035H
}

bool BeiAng4CPGateway::setWholeUnitMaintenanceTime(int days)
{
    return writeSingleRegister(WHOLE_UNIT_MAINTENANCE_TIME, static_cast<uint16_t>(days)); // 1036H
}

// 厂测设定实现（1038H-103EH，设备侧仅厂测模式接受写入）
bool BeiAng4CPGateway::setFanCurrentSetting(int fanIndex, uint16_t value)
{
    if (fanIndex < 1 || fanIndex > 4) {
        m_lastError = "Invalid fan index";
        return false;
    }
    const uint16_t address =
        static_cast<uint16_t>(FAN1_CURRENT_SETTING + (fanIndex - 1));
    return writeSingleRegister(address, value);
}

bool BeiAng4CPGateway::setValveStatusSetting(int valveIndex, ValveStatus status)
{
    if (valveIndex < 1 || valveIndex > 3) {
        m_lastError = "Invalid valve index";
        return false;
    }
    const uint16_t address =
        static_cast<uint16_t>(VALVE1_STATUS_SETTING + (valveIndex - 1));
    return writeSingleRegister(address, static_cast<uint16_t>(status));
}

// 风机内外循环各档风量设定实现（1041H-1070H）
bool BeiAng4CPGateway::setFanGearFlowSetting(int fanIndex, bool external, int gear, uint16_t value)
{
    if (fanIndex < 1 || fanIndex > 4 || gear < 1 || gear > 6) {
        m_lastError = "Invalid fan flow setting arguments";
        return false;
    }
    const uint16_t fanBase[4] = {
        FAN1_EXTERNAL_GEAR_FLOW,
        FAN2_EXTERNAL_GEAR_FLOW,
        FAN3_EXTERNAL_GEAR_FLOW,
        FAN4_EXTERNAL_GEAR_FLOW
    };
    const uint16_t base = fanBase[fanIndex - 1];
    const uint16_t address = static_cast<uint16_t>(
        base + (external ? 0 : 6) + (gear - 1));
    return writeSingleRegister(address, value);
}

// 风阀设定实现（1071H-1076H）
bool BeiAng4CPGateway::setDamperDirectionSetting(int damperIndex, uint16_t direction)
{
    if (damperIndex < 1 || damperIndex > 3 || direction > 1) {
        m_lastError = "Invalid damper direction setting";
        return false;
    }
    const uint16_t address =
        static_cast<uint16_t>(DAMPER1_DIRECTION_SETTING + (damperIndex - 1));
    return writeSingleRegister(address, direction);
}

bool BeiAng4CPGateway::setDamperStepsSetting(int damperIndex, uint16_t steps)
{
    if (damperIndex < 1 || damperIndex > 3) {
        m_lastError = "Invalid damper index";
        return false;
    }
    const uint16_t address =
        static_cast<uint16_t>(DAMPER1_STEPS_SETTING + (damperIndex - 1));
    return writeSingleRegister(address, steps);
}

// 维护操作实现
bool BeiAng4CPGateway::clearAllFanRuntime()
{
    return writeSingleRegister(CLEAR_ALL_FAN_RUNTIME, 0x0001); // 103FH 清除所有风机累计运转时间
}

bool BeiAng4CPGateway::restoreFactorySettings()
{
    return writeSingleRegister(RESTORE_FACTORY, 0x0001); // 1040H 恢复出厂
}

// ========== 设备能力检测方法实现 ==========
bool BeiAng4CPGateway::hasHumidificationModule()
{
    uint8_t capabilityFlags[16];
    if (!readCapabilityFlags(capabilityFlags)) {
        return false;
    }
    return capabilityFlags[DISCRET_CAPABILITY_HUMIDITY_MODULE] != 0;
}

bool BeiAng4CPGateway::hasDehumidification()
{
    uint8_t capabilityFlags[16];
    if (!readCapabilityFlags(capabilityFlags)) {
        return false;
    }
    return capabilityFlags[DISCRET_CAPABILITY_DEHUMIDIFICATION] != 0;
}

bool BeiAng4CPGateway::hasBypassMode()
{
    uint8_t capabilityFlags[16];
    if (!readCapabilityFlags(capabilityFlags)) {
        return false;
    }
    return capabilityFlags[DISCRET_CAPABILITY_BYPASS_MODE] != 0;
}

bool BeiAng4CPGateway::hasIEFPurification()
{
    uint8_t capabilityFlags[16];
    if (!readCapabilityFlags(capabilityFlags)) {
        return false;
    }
    return capabilityFlags[DISCRET_CAPABILITY_IEF] != 0;
}

bool BeiAng4CPGateway::hasFormaldehydeSensor()
{
    uint8_t capabilityFlags[16];
    if (!readCapabilityFlags(capabilityFlags)) {
        return false;
    }
    return capabilityFlags[DISCRET_CAPABILITY_HCHO] != 0;
}

// ========== 故障检查方法实现 ==========
bool BeiAng4CPGateway::checkFreshAirFanFault()
{
    uint8_t faultCodes[DISCRET_FAULT_COUNT];
    if (!readFaultCodes(faultCodes)) {
        return false;
    }
    return faultCodes[0] != 0; // 新风机异常（偏移64，在数组中索引0）
}

bool BeiAng4CPGateway::checkExhaustFanFault()
{
    uint8_t faultCodes[DISCRET_FAULT_COUNT];
    if (!readFaultCodes(faultCodes)) {
        return false;
    }
    return faultCodes[1] != 0; // 排风机异常（偏移65，在数组中索引1）
}

bool BeiAng4CPGateway::checkBoostFanFault()
{
    uint8_t faultCodes[DISCRET_FAULT_COUNT];
    if (!readFaultCodes(faultCodes)) {
        return false;
    }
    return faultCodes[2] != 0; // 增压风机异常（偏移66，在数组中索引2）
}

std::vector<std::string> BeiAng4CPGateway::getAllFaults()
{
    std::vector<std::string> faults;
    uint8_t faultCodes[DISCRET_FAULT_COUNT];

    if (!readFaultCodes(faultCodes)) {
        faults.push_back("无法读取故障码");
        return faults;
    }

    // 根据协议文档v1.22故障码表检查所有故障（偏移64-76）
    if (faultCodes[0] != 0) faults.push_back("新风机异常");
    if (faultCodes[1] != 0) faults.push_back("排风机异常");
    if (faultCodes[2] != 0) faults.push_back("增压风机异常");
    // faultCodes[3] 待补充
    if (faultCodes[4] != 0) faults.push_back("加湿机通讯失联");
    if (faultCodes[5] != 0) faults.push_back("加湿进水槽浮子警报");
    if (faultCodes[6] != 0) faults.push_back("加湿排水槽浮子警报");
    if (faultCodes[7] != 0) faults.push_back("加湿排水槽水位浮子排水后不下降");
    if (faultCodes[8] != 0) faults.push_back("加湿进水槽缺水");
    if (faultCodes[9] != 0) faults.push_back("加湿电辅热1过流/过压保护");
    if (faultCodes[10] != 0) faults.push_back("加湿电辅热2过流/过压保护");
    if (faultCodes[11] != 0) faults.push_back("加湿进水槽浮子有异常");
    if (faultCodes[12] != 0) faults.push_back("加湿排水槽浮子有异常");

    return faults;
}

// 02H功能码：离散输入读取实现
bool BeiAng4CPGateway::readDiscreteInputs(uint16_t startAddr, uint16_t count, uint8_t* values)
{
    return readDiscreteInput(startAddr, count, values);
}

bool BeiAng4CPGateway::readCapabilityFlags(uint8_t* values)
{
    // 读取设备能力标志（3000H+0-15，共16位，覆盖v1.22能力配置表偏移0-7）
    return readDiscreteInputs(DISCRET_CAPABILITY_START, 16, values);
}

bool BeiAng4CPGateway::readHumidificationStatus(uint8_t* values)
{
    // 读取设备状态（3000H+32-47，共16位，覆盖v1.22状态表偏移32-37）
    return readDiscreteInputs(DISCRET_HUMIDIFICATION_PUMP_STATUS, 16, values);
}

bool BeiAng4CPGateway::readFaultCodes(uint8_t* values)
{
    // 读取故障码（3000H+64-76，共13位）
    return readDiscreteInputs(DISCRET_FAULT_START, DISCRET_FAULT_COUNT, values);
}

// 04H功能码：输入寄存器读取实现
bool BeiAng4CPGateway::readInputRegisters(uint16_t startAddr, uint16_t count, uint16_t* registers)
{
    return readInputRegister(startAddr, count, registers);
}

bool BeiAng4CPGateway::readBasicDeviceInfo(uint16_t* registers)
{
    // 读取基础设备信息（2000H-2003H，共4个寄存器）
    return readInputRegisters(INPUT_FACTORY_FLAG, 4, registers);
}

bool BeiAng4CPGateway::readFanStatus(uint16_t* registers)
{
    // 读取风机档位状态（2004H-2008H，共5个寄存器：内循环/混风最大档位 + FAN1-4档位）
    return readInputRegisters(INPUT_MAX_FAN_GEAR_RECIRC, 5, registers);
}

bool BeiAng4CPGateway::readAllSensorData(uint16_t* registers)
{
    // 读取所有传感器数据（200DH-201AH，共14个寄存器）
    return readInputRegisters(INPUT_RA1_TEMPERATURE, 14, registers);
}

// 10H功能码：写多个寄存器实现
bool BeiAng4CPGateway::writeMultipleRegisters(uint16_t startAddr, uint16_t count, const uint16_t* values)
{
    return writeMultipleRegistersInternal(startAddr, count, values);
}

bool BeiAng4CPGateway::submitHoldingRegisterWrite(
    uint16_t address,
    uint16_t value,
    CommunicationScheduler::Completion completion)
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        m_lastError = "Modbus master scheduler is not running";
        return false;
    }
    return m_scheduler->submitWrite(
        notifyOnSuccess([this, address, value]() {
            return writeSingleRegisterDirect(address, value);
        }),
        std::move(completion),
        m_maxRetryCount);
}

bool BeiAng4CPGateway::submitMultipleRegisterWrite(
    uint16_t startAddr,
    std::vector<uint16_t> values,
    CommunicationScheduler::Completion completion)
{
    if (!m_scheduler || !m_scheduler->isRunning() || values.empty()) {
        m_lastError = "Modbus master scheduler is not running or values are empty";
        return false;
    }
    return m_scheduler->submitWrite(
        notifyOnSuccess([this, startAddr, values = std::move(values)]() {
            return writeMultipleRegistersDirect(
                startAddr,
                static_cast<uint16_t>(values.size()),
                values.data());
        }),
        std::move(completion),
        m_maxRetryCount);
}

bool BeiAng4CPGateway::submitHoldingRegisterRead(
    uint16_t startAddr,
    uint16_t count,
    HoldingReadCompletion completion)
{
    if (!m_scheduler || !m_scheduler->isRunning() || count == 0 || count > 50) {
        m_lastError = "Modbus master scheduler is not running or read range is invalid";
        return false;
    }

    auto values = std::make_shared<std::vector<uint16_t>>(count, 0);
    return m_scheduler->submitRead(
        notifyOnSuccess([this, startAddr, count, values]() {
            return readHoldingRegisters(startAddr, count, values->data());
        }),
        [values, completion = std::move(completion)](bool success) {
            if (completion) {
                completion(success, *values);
            }
        },
        m_maxRetryCount);
}

std::size_t BeiAng4CPGateway::pendingWriteCount() const
{
    return m_scheduler ? m_scheduler->pendingWriteCount() : 0;
}

// 通用寄存器读取方法（用于工程模式）
bool BeiAng4CPGateway::readHoldingRegister(uint16_t address, uint16_t count, uint16_t* values)
{
    if (count == 0 || !values) {
        m_lastError = "Invalid holding register read arguments";
        return false;
    }
    const uint16_t readBatchSize = 50;
    for (uint16_t offset = 0; offset < count;) {
        const uint16_t batch = std::min<uint16_t>(readBatchSize, count - offset);
        if (!executeRead([this, address, offset, batch, values]() {
                return readHoldingRegisters(address + offset, batch, values + offset);
            })) {
            return false;
        }
        offset += batch;
    }
    // 记录读取的寄存器值（调试用）
    if (count == 1) {
        spdlog::debug("[BeiAng4CPGateway] Read holding register {:#04x} = {:#04x} ({})",
                      address, values[0], values[0]);
    } else {
        spdlog::debug("[BeiAng4CPGateway] Read holding registers {:#04x}+{} = {}",
                      address, count, fmt::join(values, values + count, ","));
    }
    return true;
}

bool BeiAng4CPGateway::readInputRegister(uint16_t address, uint16_t count, uint16_t* values)
{
    if (count == 0 || !values) {
        m_lastError = "Invalid input register read arguments";
        return false;
    }
    const uint16_t readBatchSize = 50;
    for (uint16_t offset = 0; offset < count;) {
        const uint16_t batch = std::min<uint16_t>(readBatchSize, count - offset);
        if (!executeRead([this, address, offset, batch, values]() {
                return readInputRegistersInternal(address + offset, batch, values + offset);
            })) {
            return false;
        }
        offset += batch;
    }
    // 记录读取的寄存器值（调试用）
    if (count == 1) {
        spdlog::debug("[BeiAng4CPGateway] Read input register {:#04x} = {:#04x} ({})",
                      address, values[0], values[0]);
    } else {
        spdlog::debug("[BeiAng4CPGateway] Read input registers {:#04x}+{} = {}",
                      address, count, fmt::join(values, values + count, ","));
    }
    return true;
}

bool BeiAng4CPGateway::readDiscreteInput(uint16_t address, uint16_t count, uint8_t* values)
{
    if (count == 0 || !values) {
        m_lastError = "Invalid discrete input read arguments";
        return false;
    }
    if (!executeRead([this, address, count, values]() {
            return readDiscreteInputsInternal(address, count, values);
        })) {
        return false;
    }
    // 记录读取的离散输入值（调试用）
    spdlog::debug("[BeiAng4CPGateway] Read discrete inputs {:#04x}+{}", address, count);
    return true;
}

bool BeiAng4CPGateway::writeHoldingRegister(uint16_t address, uint16_t value)
{
    if (!writeSingleRegister(address, value)) {
        return false;
    }
    spdlog::info("[BeiAng4CPGateway] Write holding register {:#04x} = {:#04x} ({}) success",
                 address, value, value);
    return true;
}

// 数据转换辅助函数实现

float BeiAng4CPGateway::temperatureFromRegister(uint16_t regValue)
{
    // 协议v1.22：温度为有符号整数，实际温度*10
    // 需要处理有符号16位整数
    int16_t signedValue = static_cast<int16_t>(regValue);
    return signedValue / 10.0f;
}

uint16_t BeiAng4CPGateway::temperatureToRegister(float temp)
{
    // 协议v1.20的OA温度写入格式：实际温度*10+2730（v1.21起已移除OA写入寄存器，保留转换函数兼容）
    return static_cast<uint16_t>(temp * 10.0f + 2730);
}

uint16_t BeiAng4CPGateway::dutyCycleToRegister(int duty)
{
    // 占空比直接使用百分比数值（0-100）
    if (duty < 0) duty = 0;
    if (duty > 100) duty = 100;
    return static_cast<uint16_t>(duty);
}

// Modbus通信实现（使用 libmodbus）

void BeiAng4CPGateway::prepareRtuTransaction()
{
    if (m_modbus) {
        // 每次实际尝试都从干净的 RTU 接收边界开始。
        // 调度器已保证尝试间隔，此处不重试、不睡眠。
        modbus_flush(m_modbus);
    }
}

void BeiAng4CPGateway::recoverRtuAfterFailure(int errorCode)
{
    if (m_modbus) {
        modbus_flush(m_modbus);
    }
    errno = errorCode;
}

bool BeiAng4CPGateway::readHoldingRegisters(uint16_t startAddr, uint16_t count, uint16_t* registers)
{
    if (!m_isConnected || !m_modbus) {
        m_lastError = "Device not connected";
        return false;
    }
    if (count == 0 || count > 50 || !registers) {
        m_lastError = "Holding register transaction must contain 1..50 registers";
        return false;
    }

    prepareRtuTransaction();
    const int rc = modbus_read_registers(m_modbus, startAddr, count, registers);
    if (rc != count) {
        const int errorCode = errno;
        m_lastError = rc < 0
            ? string("Modbus read failed: ") + modbus_strerror(errorCode)
            : string("Modbus read returned an incomplete register group");
        spdlog::error("[BeiAng4CPGateway] Read registers {:#04x}+{} failed: {}",
            startAddr, count, m_lastError);
        recoverRtuAfterFailure(errorCode);
        return false;
    }
    return true;
}

bool BeiAng4CPGateway::writeSingleRegister(uint16_t addr, uint16_t value)
{
    return executeWrite([this, addr, value]() {
        return writeSingleRegisterDirect(addr, value);
    });
}

bool BeiAng4CPGateway::writeSingleRegisterDirect(uint16_t addr, uint16_t value)
{
    if (!m_isConnected || !m_modbus) {
        m_lastError = "Device not connected";
        return false;
    }

    prepareRtuTransaction();
    const int rc = modbus_write_register(m_modbus, addr, value);
    if (rc == 1) {
        spdlog::debug("[BeiAng4CPGateway] Write register {:#04x}={:#04x} success", addr, value);
        return true;
    }

    const int errorCode = errno;
    m_lastError = string("Modbus write register failed: ") + modbus_strerror(errorCode);
    spdlog::error("[BeiAng4CPGateway] Write register {:#04x}={:#04x} failed: {}",
        addr, value, m_lastError);
    recoverRtuAfterFailure(errorCode);
    return false;
}

// 04H功能码：读取输入寄存器
bool BeiAng4CPGateway::readInputRegistersInternal(uint16_t startAddr, uint16_t count, uint16_t* registers)
{
    if (!m_isConnected || !m_modbus) {
        m_lastError = "Device not connected";
        return false;
    }
    if (count == 0 || count > 50 || !registers) {
        m_lastError = "Input register transaction must contain 1..50 registers";
        return false;
    }

    prepareRtuTransaction();
    const int rc = modbus_read_input_registers(m_modbus, startAddr, count, registers);
    if (rc == count) {
        return true;
    }

    const int errorCode = errno;
    m_lastError = string("Modbus read input registers failed: ") + modbus_strerror(errorCode);
    spdlog::error("[BeiAng4CPGateway] Read input registers {:#04x}+{} failed: {}",
        startAddr, count, m_lastError);
    recoverRtuAfterFailure(errorCode);
    return false;
}

// 02H功能码：读取离散输入
bool BeiAng4CPGateway::readDiscreteInputsInternal(uint16_t startAddr, uint16_t count, uint8_t* values)
{
    if (!m_isConnected || !m_modbus) {
        m_lastError = "Device not connected";
        return false;
    }

    prepareRtuTransaction();
    const int rc = modbus_read_input_bits(m_modbus, startAddr, count, values);
    if (rc == count) {
        return true;
    }

    const int errorCode = errno;
    m_lastError = string("Modbus read discrete inputs failed: ") + modbus_strerror(errorCode);
    spdlog::error("[BeiAng4CPGateway] Read discrete inputs {:#04x}+{} failed: {}",
        startAddr, count, m_lastError);
    recoverRtuAfterFailure(errorCode);
    return false;
}

// 10H功能码：写多个寄存器
bool BeiAng4CPGateway::writeMultipleRegistersInternal(uint16_t startAddr, uint16_t count, const uint16_t* values)
{
    if (count == 0 || !values) {
        m_lastError = "Invalid multiple-register write arguments";
        return false;
    }
    const std::vector<uint16_t> copiedValues(values, values + count);
    return executeWrite([this, startAddr, copiedValues]() {
        return writeMultipleRegistersDirect(
            startAddr,
            static_cast<uint16_t>(copiedValues.size()),
            copiedValues.data());
    });
}

bool BeiAng4CPGateway::writeMultipleRegistersDirect(
    uint16_t startAddr,
    uint16_t count,
    const uint16_t* values)
{
    if (!m_isConnected || !m_modbus) {
        m_lastError = "Device not connected";
        spdlog::warn("[BeiAng4CPGateway] Write multiple registers {:#04x}+{} skipped: {}",
                     startAddr, count, m_lastError);
        return false;
    }

    prepareRtuTransaction();
    const int rc = modbus_write_registers(m_modbus, startAddr, count, values);
    if (rc == count) {
        return true;
    }

    const int errorCode = errno;
    m_lastError = string("Modbus write multiple registers failed: ") + modbus_strerror(errorCode);
    spdlog::error("[BeiAng4CPGateway] Write multiple registers {:#04x}+{} failed: {}",
        startAddr, count, m_lastError);
    recoverRtuAfterFailure(errorCode);
    return false;
}

bool BeiAng4CPGateway::executeRead(CommunicationScheduler::Operation operation)
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        m_lastError = "Modbus master scheduler is not running";
        return false;
    }
    return m_scheduler->executeRead(
        notifyOnSuccess(std::move(operation)), m_maxRetryCount);
}

bool BeiAng4CPGateway::executeWrite(CommunicationScheduler::Operation operation)
{
    if (!m_scheduler || !m_scheduler->isRunning()) {
        m_lastError = "Modbus master scheduler is not running";
        return false;
    }
    return m_scheduler->executeWrite(
        notifyOnSuccess(std::move(operation)), m_maxRetryCount);
}

CommunicationScheduler::Operation BeiAng4CPGateway::notifyOnSuccess(
    CommunicationScheduler::Operation operation)
{
    return [this, operation = std::move(operation)]() mutable {
        const bool success = operation && operation();
        if (success && m_communicationSuccessCallback) {
            m_communicationSuccessCallback();
        }
        return success;
    };
}
