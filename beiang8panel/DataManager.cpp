/**
 * DataManager 实现
 */

#include "DataManager.h"
#include "history/HistoryRecorder.h"
#include "memwatch/MemoryWatchModule.h"
#include "common/ProtocolBitWords.h"
#include "common/GlobalFunction.h"
#include "common/LogManager.h"
#include <cstring>
#include <hv/json.hpp>
#include <fstream>
#include <cstdio>
#include <iostream>
#include <sstream>
#include <unistd.h>
#include <utility>

using namespace std;
using json = nlohmann::json;

namespace {

bool setConfigError(string& error, const string& message)
{
    error = message;
    return false;
}

bool validateStringField(
    const json& object,
    const char* name,
    string& error,
    bool requireNonEmpty = false)
{
    const auto it = object.find(name);
    if (it == object.end() || !it->is_string()) {
        return setConfigError(error, string("field '") + name + "' must be a string");
    }
    if (requireNonEmpty && it->get<string>().empty()) {
        return setConfigError(error, string("field '") + name + "' must not be empty");
    }
    return true;
}

bool validateIntField(
    const json& object,
    const char* name,
    int minimum,
    int maximum,
    string& error)
{
    const auto it = object.find(name);
    if (it == object.end() || !it->is_number_integer()) {
        return setConfigError(error, string("field '") + name + "' must be an integer");
    }
    try {
        const int value = it->get<int>();
        if (value < minimum || value > maximum) {
            return setConfigError(error, string("field '") + name + "' is out of range");
        }
    } catch (const json::exception&) {
        return setConfigError(error, string("field '") + name + "' is out of range");
    }
    return true;
}

bool validateOptionalStringField(
    const json& object,
    const char* name,
    string& error,
    bool requireNonEmpty = false)
{
    const auto it = object.find(name);
    if (it == object.end()) {
        return true;
    }
    if (!it->is_string()) {
        return setConfigError(error, string("field '") + name + "' must be a string");
    }
    if (requireNonEmpty && it->get<string>().empty()) {
        return setConfigError(error, string("field '") + name + "' must not be empty");
    }
    return true;
}

bool validateOptionalBoolField(
    const json& object,
    const char* name,
    string& error)
{
    const auto it = object.find(name);
    if (it != object.end() && !it->is_boolean()) {
        return setConfigError(error, string("field '") + name + "' must be boolean");
    }
    return true;
}

bool validateSerialFields(
    const json& object,
    const char* endpointName,
    string& endpoint,
    string& error)
{
    if (!validateStringField(object, endpointName, error, true)
        || !validateIntField(object, "baudRate", 1, 10000000, error)
        || !validateIntField(object, "dataBits", 5, 8, error)
        || !validateIntField(object, "stopBits", 1, 2, error)
        || !validateStringField(object, "parity", error)
        || !validateIntField(object, "timeout", 0, 60000, error)) {
        return false;
    }

    const string parity = object.at("parity").get<string>();
    if (parity.size() != 1
        || (parity[0] != 'N' && parity[0] != 'O' && parity[0] != 'E')) {
        return setConfigError(error, "field 'parity' must be N, O or E");
    }
    endpoint = object.at(endpointName).get<string>();
    return true;
}

bool validateOptionalSections(const json& doc, string& error)
{
    const auto device = doc.find("device");
    if (device != doc.end()) {
        if (!device->is_object()) {
            return setConfigError(error, "section 'device' must be an object");
        }
        if (device->contains("address")
            && !validateIntField(*device, "address", 1, 247, error)) {
            return false;
        }
        if (!validateOptionalStringField(*device, "model", error)
            || !validateOptionalStringField(*device, "protocolVersion", error)
            || !validateOptionalStringField(*device, "name", error)) {
            return false;
        }
    }

    const auto dataAcquisition = doc.find("dataAcquisition");
    if (dataAcquisition != doc.end()) {
        if (!dataAcquisition->is_object()) {
            return setConfigError(error, "section 'dataAcquisition' must be an object");
        }
        if ((dataAcquisition->contains("interval")
                && !validateIntField(*dataAcquisition, "interval", 100, 600000, error))
            || (dataAcquisition->contains("maxRetryCount")
                && !validateIntField(*dataAcquisition, "maxRetryCount", 0, 1000, error))
            || !validateOptionalBoolField(*dataAcquisition, "autoReconnect", error)) {
            return false;
        }
    }

    const auto weather = doc.find("weather");
    if (weather != doc.end()) {
        if (!weather->is_object()
            || !validateOptionalStringField(*weather, "apiHost", error)
            || !validateOptionalStringField(*weather, "apiKey", error)) {
            return weather->is_object()
                ? false
                : setConfigError(error, "section 'weather' must be an object");
        }
    }

    const auto radar = doc.find("radar");
    if (radar != doc.end()) {
        if (!radar->is_object()
            || !validateOptionalStringField(*radar, "statusFile", error, true)
            || !validateOptionalStringField(*radar, "commandFile", error, true)) {
            return radar->is_object()
                ? false
                : setConfigError(error, "section 'radar' must be an object");
        }
    }

    const auto ota = doc.find("ota");
    if (ota != doc.end()) {
        if (!ota->is_object()) {
            return setConfigError(error, "section 'ota' must be an object");
        }
        if (!validateOptionalBoolField(*ota, "enabled", error)
            || !validateOptionalStringField(*ota, "serialPort", error, true)
            || !validateOptionalStringField(*ota, "workDir", error, true)) {
            return false;
        }
        if (ota->contains("baudRate")
            && !validateIntField(*ota, "baudRate", 1, 10000000, error)) {
            return false;
        }
    }

    const auto history = doc.find("history");
    if (history != doc.end()) {
        if (!history->is_object()) {
            return setConfigError(error, "section 'history' must be an object");
        }
        if (!validateOptionalBoolField(*history, "enabled", error)
            || !validateOptionalStringField(*history, "dataDir", error, true)) {
            return false;
        }
        if ((history->contains("sampleIntervalSec")
                && !validateIntField(*history, "sampleIntervalSec", 1, 86400, error))
            || (history->contains("retentionDays")
                && !validateIntField(*history, "retentionDays", 1, 3650, error))) {
            return false;
        }
    }

    const auto memwatch = doc.find("memwatch");
    if (memwatch != doc.end()) {
        if (!memwatch->is_object()) {
            return setConfigError(error, "section 'memwatch' must be an object");
        }
        if (!validateOptionalBoolField(*memwatch, "enabled", error)) {
            return false;
        }
        const pair<const char*, pair<int, int>> integerFields[] = {
            {"checkIntervalSec", {1, 86400}},
            {"warnThresholdMB", {1, 1048576}},
            {"restartAppThresholdMB", {1, 1048576}},
            {"rebootThresholdMB", {1, 1048576}},
            {"sustainedChecks", {1, 1000}},
            {"actionCooldownSec", {1, 86400 * 30}}
        };
        for (const auto& field : integerFields) {
            if (memwatch->contains(field.first)
                && !validateIntField(*memwatch, field.first,
                    field.second.first, field.second.second, error)) {
                return false;
            }
        }
    }

    return true;
}

bool readAndValidateConfig(
    const string& configPath,
    json& doc,
    DataManager::ConfigFileInfo& info,
    string& error)
{
    ifstream file(configPath);
    if (!file.is_open()) {
        return setConfigError(error, "cannot open config file");
    }

    try {
        file >> doc;
    } catch (const json::exception& exception) {
        return setConfigError(error, string("invalid JSON: ") + exception.what());
    }
    if (!doc.is_object()) {
        return setConfigError(error, "root must be an object");
    }

    const auto transport = doc.find("transport");
    const auto serial = doc.find("serial");
    if (transport != doc.end() && serial != doc.end()) {
        return setConfigError(error, "sections 'transport' and 'serial' cannot both be present");
    }
    if (transport == doc.end() && serial == doc.end()) {
        return setConfigError(error, "missing communication section 'transport' or 'serial'");
    }

    info.transportType = "serial";
    if (transport != doc.end()) {
        if (!transport->is_object()) {
            return setConfigError(error, "section 'transport' must be an object");
        }
        if (!validateStringField(*transport, "type", error, true)) {
            return false;
        }
        info.transportType = transport->at("type").get<string>();
        const auto endpoint = transport->find("endpoint");
        if (endpoint == transport->end()) {
            return setConfigError(error, "field 'endpoint' is required");
        }
        if (endpoint->is_null()) {
            info.disabled = true;
            return true;
        }
        if (!endpoint->is_string() || endpoint->get<string>().empty()) {
            return setConfigError(error, "field 'endpoint' must be a non-empty string or null");
        }
        info.endpoint = endpoint->get<string>();
        // 只有当前已实现的 serial 传输才校验串口专属字段；其它介质保留
        // 通用 endpoint，待对应通道实现后再增加介质自己的字段校验。
        if (info.transportType == "serial"
            && !validateSerialFields(*transport, "endpoint", info.endpoint, error)) {
            return false;
        }
    } else {
        if (!serial->is_object()) {
            return setConfigError(error, "section 'serial' must be an object");
        }
        if (!validateSerialFields(*serial, "port", info.endpoint, error)) {
            return false;
        }
    }

    const auto network = doc.find("network");
    if (network == doc.end() || !network->is_object()) {
        return setConfigError(error, "section 'network' must be an object");
    }
    if (!validateStringField(*network, "httpHost", error, true)
        || !validateIntField(*network, "httpPort", 1, 65535, error)) {
        return false;
    }
    info.httpPort = network->at("httpPort").get<int>();

    if (!validateOptionalSections(doc, error)) {
        return false;
    }
    return true;
}

}

DataManager::DataManager(const string& configPath,
    CommunicationSchedulerType communicationSchedulerType)
    : m_configPath(configPath)
    , m_communicationSchedulerType(communicationSchedulerType)
    , m_httpPort(8080)
    , m_httpHost("0.0.0.0")
    , m_serialPort(DEFAULT_SERIAL_PORT)
    , m_transportType("serial")
    , m_serialBaudRate(9600)
    , m_serialDataBits(8)
    , m_serialStopBits(1)
    , m_serialParity('N')
    , m_serialTimeout(MODBUS_RESPONSE_TIMEOUT_MS)
    , m_deviceAddress(209)
    , m_dataAcquisitionInterval(1000)
    , m_weatherApiHost("https://p64nmvptj5.re.qweatherapi.com")
    , m_radarStatusFile("/mnt/UDISK/beiang8panel/radar_status.json")
    , m_radarCommandFile("/tmp/trmk222_cmd")
    , m_otaEnabled(true)
    , m_otaSerialPort("/dev/ttyS1")
    , m_otaSerialBaudRate(115200)
    , m_otaWorkDir("/mnt/UDISK/beiang8panel/ota")
{
}

DataManager::~DataManager()
{
    shutdown();
}

bool DataManager::initialize()
{
    // 加载配置文件
    if (!loadConfig(m_configPath)) {
        LOG_ERROR("Failed to load config; this process will not start: {}", m_configPath);
        return false;
    }

    // 创建历史趋势采样器(线程由 Application 在采集模块启动后 start)
    HistoryRecorder::Config historyConfig;
    historyConfig.enabled = m_historyEnabled;
    historyConfig.dataDir = m_historyDataDir;
    historyConfig.sampleIntervalSec = m_historySampleIntervalSec;
    historyConfig.retentionDays = m_historyRetentionDays;
    m_historyRecorder = std::make_unique<HistoryRecorder>(this, historyConfig);

    // 创建内存水位监控模块(线程由 Application 启停)
    MemoryWatchConfig memWatchConfig;
    memWatchConfig.enabled = m_memWatchEnabled;
    memWatchConfig.checkIntervalSec = m_memWatchCheckIntervalSec;
    memWatchConfig.warnThresholdKB = m_memWatchWarnThresholdMB * 1024;
    memWatchConfig.restartAppThresholdKB = m_memWatchRestartAppThresholdMB * 1024;
    memWatchConfig.rebootThresholdKB = m_memWatchRebootThresholdMB * 1024;
    memWatchConfig.sustainedChecks = m_memWatchSustainedChecks;
    memWatchConfig.actionCooldownSec = m_memWatchActionCooldownSec;
    m_memoryWatch = std::make_unique<MemoryWatchModule>(this, memWatchConfig);

    return true;
}

void DataManager::shutdown()
{
    // 先停内存监控(会杀 Flutter/重启设备,关闭期不应再动作)
    if (m_memoryWatch) {
        m_memoryWatch->stop();
    }
    // 再停历史采样线程(读寄存器缓存)
    if (m_historyRecorder) {
        m_historyRecorder->stop();
    }
    // 当前配置只在进程启动时读取，运行期间没有 JSON 配置变更入口。
    // 只有未来运行时确实通过受控接口改变配置，才在变更成功后显式调用 saveConfig()；
    // 退出时不自动回写。
    // 避免异常或不完整配置在关闭阶段被覆盖。
    // saveConfig(m_configPath);
}

bool DataManager::inspectConfigFile(
    const string& configPath,
    ConfigFileInfo& info,
    string& error)
{
    json doc;
    info = ConfigFileInfo();
    if (!readAndValidateConfig(configPath, doc, info, error)) {
        return false;
    }
    return true;
}

bool DataManager::loadConfig(const string& configPath)
{
    json doc;
    ConfigFileInfo info;
    string error;
    if (!readAndValidateConfig(configPath, doc, info, error)) {
        LOG_ERROR("Config rejected: {} ({})", configPath, error);
        return false;
    }
    if (info.disabled) {
        LOG_WARN("Config explicitly disables this process: {}", configPath);
        return false;
    }

    // 所有值先写入局部变量；完整校验通过后才一次性提交到运行态成员。
    int httpPort = m_httpPort;
    string httpHost = m_httpHost;
    string serialPort = m_serialPort;
    string transportType = m_transportType;
    int serialBaudRate = m_serialBaudRate;
    int serialDataBits = m_serialDataBits;
    int serialStopBits = m_serialStopBits;
    char serialParity = m_serialParity;
    int serialTimeout = m_serialTimeout;
    int deviceAddress = m_deviceAddress;
    int dataAcquisitionInterval = m_dataAcquisitionInterval;
    string weatherApiKey = m_weatherApiKey;
    string weatherApiHost = m_weatherApiHost;
    string radarStatusFile = m_radarStatusFile;
    string radarCommandFile = m_radarCommandFile;
    bool otaEnabled = m_otaEnabled;
    string otaSerialPort = m_otaSerialPort;
    int otaSerialBaudRate = m_otaSerialBaudRate;
    string otaWorkDir = m_otaWorkDir;
    bool historyEnabled = m_historyEnabled;
    string historyDataDir = m_historyDataDir;
    int historySampleIntervalSec = m_historySampleIntervalSec;
    int historyRetentionDays = m_historyRetentionDays;
    bool memWatchEnabled = m_memWatchEnabled;
    int memWatchCheckIntervalSec = m_memWatchCheckIntervalSec;
    int memWatchWarnThresholdMB = m_memWatchWarnThresholdMB;
    int memWatchRestartAppThresholdMB = m_memWatchRestartAppThresholdMB;
    int memWatchRebootThresholdMB = m_memWatchRebootThresholdMB;
    int memWatchSustainedChecks = m_memWatchSustainedChecks;
    int memWatchActionCooldownSec = m_memWatchActionCooldownSec;

    const auto device = doc.find("device");
    if (device != doc.end() && device->contains("address")) {
        deviceAddress = device->at("address").get<int>();
    }

    const auto transport = doc.find("transport");
    if (transport != doc.end()) {
        transportType = transport->at("type").get<string>();
        serialPort = transport->at("endpoint").get<string>();
        if (transportType == "serial") {
            serialBaudRate = transport->at("baudRate").get<int>();
            serialDataBits = transport->at("dataBits").get<int>();
            serialStopBits = transport->at("stopBits").get<int>();
            serialParity = transport->at("parity").get<string>()[0];
            serialTimeout = transport->at("timeout").get<int>();
        }
    } else {
        const auto& serial = doc.at("serial");
        transportType = "serial";
        serialPort = serial.at("port").get<string>();
        serialBaudRate = serial.at("baudRate").get<int>();
        serialDataBits = serial.at("dataBits").get<int>();
        serialStopBits = serial.at("stopBits").get<int>();
        serialParity = serial.at("parity").get<string>()[0];
        serialTimeout = serial.at("timeout").get<int>();
    }

    const auto& network = doc.at("network");
    httpHost = network.at("httpHost").get<string>();
    httpPort = network.at("httpPort").get<int>();

    const auto dataAcquisition = doc.find("dataAcquisition");
    if (dataAcquisition != doc.end() && dataAcquisition->contains("interval")) {
        dataAcquisitionInterval = dataAcquisition->at("interval").get<int>();
    }

    const auto weather = doc.find("weather");
    if (weather != doc.end()) {
        if (weather->contains("apiKey")) {
            weatherApiKey = weather->at("apiKey").get<string>();
        }
        if (weather->contains("apiHost")) {
            weatherApiHost = weather->at("apiHost").get<string>();
        }
    }

    const auto radar = doc.find("radar");
    if (radar != doc.end()) {
        if (radar->contains("statusFile")) {
            radarStatusFile = radar->at("statusFile").get<string>();
        }
        if (radar->contains("commandFile")) {
            radarCommandFile = radar->at("commandFile").get<string>();
        }
    }

    const auto ota = doc.find("ota");
    if (ota != doc.end()) {
        if (ota->contains("enabled")) {
            otaEnabled = ota->at("enabled").get<bool>();
        }
        if (ota->contains("serialPort")) {
            otaSerialPort = ota->at("serialPort").get<string>();
        }
        if (ota->contains("baudRate")) {
            otaSerialBaudRate = ota->at("baudRate").get<int>();
        }
        if (ota->contains("workDir")) {
            otaWorkDir = ota->at("workDir").get<string>();
        }
    }

    const auto history = doc.find("history");
    if (history != doc.end()) {
        if (history->contains("enabled")) {
            historyEnabled = history->at("enabled").get<bool>();
        }
        if (history->contains("dataDir")) {
            historyDataDir = history->at("dataDir").get<string>();
        }
        if (history->contains("sampleIntervalSec")) {
            historySampleIntervalSec = history->at("sampleIntervalSec").get<int>();
        }
        if (history->contains("retentionDays")) {
            historyRetentionDays = history->at("retentionDays").get<int>();
        }
    }

    const auto memwatch = doc.find("memwatch");
    if (memwatch != doc.end()) {
        if (memwatch->contains("enabled")) {
            memWatchEnabled = memwatch->at("enabled").get<bool>();
        }
        if (memwatch->contains("checkIntervalSec")) {
            memWatchCheckIntervalSec = memwatch->at("checkIntervalSec").get<int>();
        }
        if (memwatch->contains("warnThresholdMB")) {
            memWatchWarnThresholdMB = memwatch->at("warnThresholdMB").get<int>();
        }
        if (memwatch->contains("restartAppThresholdMB")) {
            memWatchRestartAppThresholdMB = memwatch->at("restartAppThresholdMB").get<int>();
        }
        if (memwatch->contains("rebootThresholdMB")) {
            memWatchRebootThresholdMB = memwatch->at("rebootThresholdMB").get<int>();
        }
        if (memwatch->contains("sustainedChecks")) {
            memWatchSustainedChecks = memwatch->at("sustainedChecks").get<int>();
        }
        if (memwatch->contains("actionCooldownSec")) {
            memWatchActionCooldownSec = memwatch->at("actionCooldownSec").get<int>();
        }
    }

    m_httpPort = httpPort;
    m_httpHost = std::move(httpHost);
    m_serialPort = std::move(serialPort);
    m_transportType = std::move(transportType);
    m_serialBaudRate = serialBaudRate;
    m_serialDataBits = serialDataBits;
    m_serialStopBits = serialStopBits;
    m_serialParity = serialParity;
    m_serialTimeout = serialTimeout;
    m_deviceAddress = deviceAddress;
    m_dataAcquisitionInterval = dataAcquisitionInterval;
    m_weatherApiKey = std::move(weatherApiKey);
    m_weatherApiHost = std::move(weatherApiHost);
    m_radarStatusFile = std::move(radarStatusFile);
    m_radarCommandFile = std::move(radarCommandFile);
    m_otaEnabled = otaEnabled;
    m_otaSerialPort = std::move(otaSerialPort);
    m_otaSerialBaudRate = otaSerialBaudRate;
    m_otaWorkDir = std::move(otaWorkDir);
    m_historyEnabled = historyEnabled;
    m_historyDataDir = std::move(historyDataDir);
    m_historySampleIntervalSec = historySampleIntervalSec;
    m_historyRetentionDays = historyRetentionDays;
    m_memWatchEnabled = memWatchEnabled;
    m_memWatchCheckIntervalSec = memWatchCheckIntervalSec;
    m_memWatchWarnThresholdMB = memWatchWarnThresholdMB;
    m_memWatchRestartAppThresholdMB = memWatchRestartAppThresholdMB;
    m_memWatchRebootThresholdMB = memWatchRebootThresholdMB;
    m_memWatchSustainedChecks = memWatchSustainedChecks;
    m_memWatchActionCooldownSec = memWatchActionCooldownSec;

    LOG_INFO("Config loaded successfully from: {}", configPath);
    return true;
}

bool DataManager::saveConfig(const string& configPath)
{
    try {
        // 显式保存也必须以当前有效配置为基底；文件缺失或损坏时拒绝写回，
        // 不自动重建、更不覆盖异常原文件。
        json doc;
        ConfigFileInfo info;
        string error;
        if (!readAndValidateConfig(configPath, doc, info, error)) {
            LOG_ERROR("Config save rejected: {} ({})", configPath, error);
            return false;
        }
        if (info.disabled) {
            LOG_WARN("Config save skipped for disabled endpoint: {}", configPath);
            return false;
        }

        // 叠加受管配置（仅更新原配置中已有的字段，未知字段保持不变）。
        // 新通信进程使用 transport；进程 1 的 serial/device 结构继续兼容。
        if (doc.contains("device") && doc["device"].is_object()) {
            doc["device"]["address"] = m_deviceAddress;
        }

        string parityStr(1, m_serialParity);
        if (doc.contains("transport") && doc["transport"].is_object()) {
            doc["transport"]["type"] = m_transportType;
            doc["transport"]["endpoint"] = m_serialPort;
            if (m_transportType == "serial") {
                doc["transport"]["baudRate"] = m_serialBaudRate;
                doc["transport"]["dataBits"] = m_serialDataBits;
                doc["transport"]["stopBits"] = m_serialStopBits;
                doc["transport"]["parity"] = parityStr;
                doc["transport"]["timeout"] = m_serialTimeout;
            }
        } else if (doc.contains("serial") && doc["serial"].is_object()) {
            doc["serial"]["port"] = m_serialPort;
            doc["serial"]["baudRate"] = m_serialBaudRate;
            doc["serial"]["dataBits"] = m_serialDataBits;
            doc["serial"]["stopBits"] = m_serialStopBits;
            doc["serial"]["parity"] = parityStr;
            doc["serial"]["timeout"] = m_serialTimeout;
        }

        // 网络配置
        if (doc.contains("network") && doc["network"].is_object()) {
            doc["network"]["httpHost"] = m_httpHost;
            doc["network"]["httpPort"] = m_httpPort;
        }

        // 数据采集配置
        if (doc.contains("dataAcquisition") && doc["dataAcquisition"].is_object()) {
            doc["dataAcquisition"]["interval"] = m_dataAcquisitionInterval;
            doc["dataAcquisition"]["maxRetryCount"] = 5;
            doc["dataAcquisition"]["autoReconnect"] = true;
        }

        // OTA 配置
        if (doc.contains("ota") && doc["ota"].is_object()) {
            doc["ota"]["enabled"] = m_otaEnabled;
            doc["ota"]["serialPort"] = m_otaSerialPort;
            doc["ota"]["baudRate"] = m_otaSerialBaudRate;
            doc["ota"]["workDir"] = m_otaWorkDir;
        }

        // 历史趋势采样配置
        if (doc.contains("history") && doc["history"].is_object()) {
            doc["history"]["enabled"] = m_historyEnabled;
            doc["history"]["dataDir"] = m_historyDataDir;
            doc["history"]["sampleIntervalSec"] = m_historySampleIntervalSec;
            doc["history"]["retentionDays"] = m_historyRetentionDays;
        }

        // 内存水位监控配置
        if (doc.contains("memwatch") && doc["memwatch"].is_object()) {
            doc["memwatch"]["enabled"] = m_memWatchEnabled;
            doc["memwatch"]["checkIntervalSec"] = m_memWatchCheckIntervalSec;
            doc["memwatch"]["warnThresholdMB"] = m_memWatchWarnThresholdMB;
            doc["memwatch"]["restartAppThresholdMB"] = m_memWatchRestartAppThresholdMB;
            doc["memwatch"]["rebootThresholdMB"] = m_memWatchRebootThresholdMB;
            doc["memwatch"]["sustainedChecks"] = m_memWatchSustainedChecks;
            doc["memwatch"]["actionCooldownSec"] = m_memWatchActionCooldownSec;
        }

        // 生成格式化的 JSON 字符串
        string jsonStr = doc.dump(4);

        // 先写同目录临时文件，再原子替换目标；进程异常不会留下半份配置。
        const string tempPath = configPath + ".tmp." + std::to_string(static_cast<long>(getpid()));
        std::ofstream file(tempPath, std::ios::trunc);
        if (!file.is_open()) {
            LOG_ERROR("Cannot create temporary config file: {}", tempPath);
            return false;
        }

        file << jsonStr;
        if (!file.good()) {
            file.close();
            std::remove(tempPath.c_str());
            LOG_ERROR("Failed to write temporary config file: {}", tempPath);
            return false;
        }
        file.close();

        if (std::rename(tempPath.c_str(), configPath.c_str()) != 0) {
            std::remove(tempPath.c_str());
            LOG_ERROR("Failed to atomically replace config file: {}", configPath);
            return false;
        }

        json readback;
        ConfigFileInfo readbackInfo;
        string readbackError;
        if (!readAndValidateConfig(configPath, readback, readbackInfo, readbackError)) {
            LOG_ERROR("Config readback validation failed: {} ({})", configPath, readbackError);
            return false;
        }

        LOG_INFO("Config saved to: {}", configPath);
        return true;
    } catch (const json::exception& e) {
        LOG_ERROR("JSON serialization error: {}", e.what());
        return false;
    }
}

void DataManager::lockData()
{
    m_dataMutex.lock();
}

void DataManager::unlockData()
{
    m_dataMutex.unlock();
}

LocalDeviceDataStructure DataManager::getLocalDeviceDataSnapshot() const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    return m_localDeviceData;
}

void DataManager::updateLocalDeviceData(const LocalDeviceDataStructure& data)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    m_localDeviceData = data;
}

void DataManager::updateWifiData(const WifiRuntimeData& data)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    WifiRuntimeData normalized = data;
    normalizeWifiRuntimeData(normalized);
    m_localDeviceData.wifi = std::move(normalized);
    m_localDeviceData.timestamp = data.timestamp;
}

void DataManager::updateLocalHardwareData(const LocalDeviceDataStructure& data)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    m_localDeviceData.screen = data.screen;
    m_localDeviceData.temperatureHumidity = data.temperatureHumidity;
    m_localDeviceData.radar = data.radar;
    m_localDeviceData.aqiLed = data.aqiLed;
    m_localDeviceData.speaker = data.speaker;
    m_localDeviceData.timestamp = data.timestamp;
}

void DataManager::updateOtaData(const OtaRuntimeData& data)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    m_localDeviceData.ota = data;
}

BackendRuntimeSnapshot DataManager::getBackendRuntimeSnapshot() const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    BackendRuntimeSnapshot snapshot;
    snapshot.gatewayData = m_gatewayData;
    snapshot.environmentData = m_environmentData;
    snapshot.localDeviceData = m_localDeviceData;
    snapshot.registerCache = m_registerCache;
    snapshot.dataFresh = m_modbusFreshness.isFresh();
    return snapshot;
}

void DataManager::publishModbusSnapshot(
    const GatewayGeneralDataStructure& gatewayData,
    const BeiAng4CPGateway::RawRegisterCache& rawCache,
    int64_t timestamp)
{
    // 不完整快照不覆盖业务缓存；通信新鲜度由 Gateway 在每个成功
    // Modbus 事务完成时单独刷新，不依赖整轮快照是否完整。
    if (!rawCache.holdingValid
        || !rawCache.inputValid
        || !rawCache.discreteValid) {
        return;
    }

    EnvironmentDataStructure environmentData;
    const AirSensorData& ra = gatewayData.getRA1Sensor();
    const AirSensorData& oa = gatewayData.getOASensor();
    const AirSensorData& sa = gatewayData.getSASensor();
    const AirQualityData& airQuality = gatewayData.getAirQuality();

    environmentData.getIndoorReturnAir().ra1.temperature = ra.temperature;
    environmentData.getIndoorReturnAir().ra1.humidity = ra.humidity;
    environmentData.getIndoorReturnAir().ra1.pm25 = ra.pm25;
    environmentData.getIndoorReturnAir().ra1.co2 = ra.co2;
    environmentData.getOutdoorAir().oa.temperature = oa.temperature;
    environmentData.getOutdoorAir().oa.humidity = oa.humidity;
    environmentData.getOutdoorAir().oa.pm25 = oa.pm25;
    environmentData.getOutdoorAir().oa.co2 = oa.co2;
    environmentData.getSupplyAir().sa.temperature = sa.temperature;
    environmentData.getSupplyAir().sa.humidity = sa.humidity;
    environmentData.getSupplyAir().sa.pm25 = sa.pm25;
    environmentData.getSupplyAir().sa.co2 = sa.co2;
    environmentData.getAirQualityMetrics().tvoc = airQuality.tvoc;
    environmentData.getAirQualityMetrics().formaldehyde = airQuality.formaldehyde;

    std::lock_guard<std::mutex> lock(m_dataMutex);
    m_gatewayData = gatewayData;
    m_environmentData = environmentData;

    memcpy(m_registerCache.holdingRegs, rawCache.holdingRegs,
        ModbusRegisterCache::HOLDING_COUNT * sizeof(uint16_t));
    m_registerCache.holdingValid = rawCache.holdingValid;
    memcpy(m_registerCache.inputRegs, rawCache.inputRegs,
        ModbusRegisterCache::INPUT_COUNT * sizeof(uint16_t));
    m_registerCache.inputValid = rawCache.inputValid;
    memcpy(m_registerCache.discreteInputs, rawCache.discreteInputs,
        ModbusRegisterCache::DISCRETE_COUNT * sizeof(uint8_t));
    memcpy(m_registerCache.discreteWords, rawCache.discreteWords,
        ModbusRegisterCache::DISCRETE_WORD_COUNT * sizeof(uint16_t));
    m_registerCache.discreteValid = rawCache.discreteValid;
    m_registerCache.timestamp = timestamp;
}

bool DataManager::publishHoldingReadback(
    uint16_t startAddress,
    const uint16_t* values,
    uint16_t count)
{
    if (!values || count == 0
        || startAddress < ModbusRegisterCache::HOLDING_START) {
        return false;
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress) + count - 1u;
    const uint32_t cacheEnd = ModbusRegisterCache::HOLDING_START
        + ModbusRegisterCache::HOLDING_COUNT - 1u;
    if (endAddress > cacheEnd) {
        return false;
    }

    std::lock_guard<std::mutex> lock(m_dataMutex);
    if (!m_registerCache.holdingValid) {
        return false;
    }

    const uint16_t offset =
        startAddress - ModbusRegisterCache::HOLDING_START;
    memcpy(m_registerCache.holdingRegs + offset, values,
        count * sizeof(uint16_t));

    // 先整体替换 N 个原始字，再由同一份完整镜像重新生成业务字段；
    // 整个过程持有一把锁，对 HTTP 快照表现为一次原子发布。
    BeiAng4CPGateway::applyHoldingRegisterData(
        m_registerCache.holdingRegs, m_gatewayData);
    return true;
}

void DataManager::markModbusCommunicationSuccess()
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    m_modbusFreshness.markSuccess();
}

bool DataManager::isModbusDataFresh() const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    return m_modbusFreshness.isFresh();
}

// ========== Modbus Gateway 管理 ==========

BeiAng4CPGateway* DataManager::getGateway()
{
    std::lock_guard<std::mutex> lock(m_gatewayMutex);

    if (m_gatewayInitialized && m_gateway) {
        return m_gateway.get();
    }

    // 首次调用时创建 Gateway
    LOG_INFO("[DataManager] Creating shared Modbus Gateway: scheduler={}, port={}, baud={}, slave={:#04x}",
             communicationSchedulerTypeName(m_communicationSchedulerType),
             m_serialPort, m_serialBaudRate, m_deviceAddress);

    auto scheduler = createCommunicationScheduler(
        m_communicationSchedulerType,
        std::chrono::milliseconds(MODBUS_COMMAND_INTERVAL_MS));
    if (!scheduler) {
        LOG_ERROR("[DataManager] Unsupported communication scheduler: {}",
            communicationSchedulerTypeName(m_communicationSchedulerType));
        return nullptr;
    }

    m_gateway = std::make_unique<BeiAng4CPGateway>(
        std::move(scheduler),
        m_serialPort, m_serialBaudRate, m_serialParity,
        m_serialDataBits, m_serialStopBits, m_serialTimeout
    );
    m_gateway->setCommunicationSuccessCallback([this]() {
        markModbusCommunicationSuccess();
    });
    m_gateway->setSlaveId(static_cast<uint8_t>(m_deviceAddress));

    if (!m_gateway->initialize()) {
        LOG_ERROR("[DataManager] Failed to initialize shared Gateway: {}", m_gateway->getLastErrorMessage());
        m_gateway.reset();
        return nullptr;
    }

    m_gatewayInitialized = true;
    LOG_INFO("[DataManager] Shared Modbus Gateway initialized successfully");
    return m_gateway.get();
}

void DataManager::lockGateway()
{
    m_gatewayMutex.lock();
}

void DataManager::unlockGateway()
{
    m_gatewayMutex.unlock();
}

// ========== Modbus 寄存器缓存实现 ==========

void DataManager::updateHoldingCache(const uint16_t* regs)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    memcpy(m_registerCache.holdingRegs, regs,
           ModbusRegisterCache::HOLDING_COUNT * sizeof(uint16_t));
    m_registerCache.holdingValid = true;
    m_registerCache.timestamp = TimeUtils::getCurrentTimestampMs();
}

void DataManager::updateInputCache(const uint16_t* regs)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    memcpy(m_registerCache.inputRegs, regs,
           ModbusRegisterCache::INPUT_COUNT * sizeof(uint16_t));
    m_registerCache.inputValid = true;
    m_registerCache.timestamp = TimeUtils::getCurrentTimestampMs();
}

void DataManager::updateDiscreteCache(const uint8_t* bits)
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    memcpy(m_registerCache.discreteInputs, bits,
           ModbusRegisterCache::DISCRETE_COUNT * sizeof(uint8_t));
    for (uint16_t bit = 0; bit < ModbusRegisterCache::DISCRETE_COUNT; ++bit) {
        ProtocolData::bit_word_set(
            m_registerCache.discreteWords, bit, bits[bit]);
    }
    m_registerCache.discreteValid = true;
    m_registerCache.timestamp = TimeUtils::getCurrentTimestampMs();
}

bool DataManager::readHoldingFromCache(uint16_t address, uint16_t count, uint16_t* out) const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    if (!m_registerCache.holdingValid || count == 0 || out == nullptr) {
        return false;
    }
    // 检查请求范围是否完全在缓存内
    if (address < ModbusRegisterCache::HOLDING_START) {
        return false;
    }
    const uint32_t endAddr = static_cast<uint32_t>(address) + count - 1u;
    const uint32_t cacheEnd = ModbusRegisterCache::HOLDING_START
        + ModbusRegisterCache::HOLDING_COUNT - 1u;
    if (endAddr > cacheEnd) {
        return false;
    }
    uint16_t offset = address - ModbusRegisterCache::HOLDING_START;
    memcpy(out, &m_registerCache.holdingRegs[offset], count * sizeof(uint16_t));
    return true;
}

bool DataManager::readInputFromCache(uint16_t address, uint16_t count, uint16_t* out) const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    if (!m_registerCache.inputValid || count == 0 || out == nullptr) {
        return false;
    }
    if (address < ModbusRegisterCache::INPUT_START) {
        return false;
    }
    const uint32_t endAddr = static_cast<uint32_t>(address) + count - 1u;
    const uint32_t cacheEnd = ModbusRegisterCache::INPUT_START
        + ModbusRegisterCache::INPUT_COUNT - 1u;
    if (endAddr > cacheEnd) {
        return false;
    }
    uint16_t offset = address - ModbusRegisterCache::INPUT_START;
    memcpy(out, &m_registerCache.inputRegs[offset], count * sizeof(uint16_t));
    return true;
}

bool DataManager::readDiscreteFromCache(uint16_t address, uint16_t count, uint8_t* out) const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    if (!m_registerCache.discreteValid || count == 0 || out == nullptr) {
        return false;
    }
    if (address < ModbusRegisterCache::DISCRETE_START) {
        return false;
    }
    const uint32_t endAddr = static_cast<uint32_t>(address) + count - 1u;
    const uint32_t cacheEnd = ModbusRegisterCache::DISCRETE_START
        + ModbusRegisterCache::DISCRETE_COUNT - 1u;
    if (endAddr > cacheEnd) {
        return false;
    }
    uint16_t offset = address - ModbusRegisterCache::DISCRETE_START;
    memcpy(out, &m_registerCache.discreteInputs[offset], count * sizeof(uint8_t));
    return true;
}

bool DataManager::isHoldingCacheValid() const
{
    std::lock_guard<std::mutex> lock(m_dataMutex);
    return m_registerCache.holdingValid;
}
