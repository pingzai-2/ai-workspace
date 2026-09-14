/**
 * Configuration 实现
 */

#include "Configuration.h"
#include "common/LogManager.h"
#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// ========== SerialConfig 实现 ==========

bool Configuration::SerialConfig::isValid() const
{
    if (port.empty()) return false;
    if (baudRate <= 0) return false;
    if (dataBits < 5 || dataBits > 8) return false;
    if (stopBits < 1 || stopBits > 2) return false;
    if (parity != 'N' && parity != 'E' && parity != 'O') return false;
    if (timeout < 0) return false;
    return true;
}

// ========== NetworkConfig 实现 ==========

bool Configuration::NetworkConfig::isValid() const
{
    if (httpHost.empty()) return false;
    if (httpPort < 1 || httpPort > 65535) return false;
    return true;
}

// ========== DeviceConfig 实现 ==========

bool Configuration::DeviceConfig::isValid() const
{
    if (address < 1 || address > 247) return false; // Modbus地址范围
    return true;
}

// ========== DataAcquisitionConfig 实现 ==========

bool Configuration::DataAcquisitionConfig::isValid() const
{
    if (interval < 100) return false; // 最小100ms
    if (maxRetryCount < 0) return false;
    return true;
}

// ========== LogConfig 实现 ==========

bool Configuration::LogConfig::isValid() const
{
    if (logFileName.empty()) return false;
    if (maxFileSize < 1024) return false; // 最小1KB
    if (maxFiles < 1) return false;
    return true;
}

// ========== Configuration 实现 ==========

Configuration::Configuration()
{
    // 默认构造函数已在结构体定义中设置默认值
}

bool Configuration::load(const std::string& path)
{
    std::ifstream file(path);
    if (!file.is_open()) {
        std::cerr << "[Configuration] Cannot open config file: " << path << std::endl;
        return false;
    }

    try {
        json doc = json::parse(file);
        file.close();

        // 解析设备配置
        if (doc.contains("device") && doc["device"].is_object()) {
            if (doc["device"].contains("address")) {
                m_device.address = doc["device"]["address"].get<int>();
            }
        }

        // 解析串口配置
        if (doc.contains("serial") && doc["serial"].is_object()) {
            const auto& serial = doc["serial"];
            if (serial.contains("port")) {
                m_serial.port = serial["port"].get<std::string>();
            }
            if (serial.contains("baudRate")) {
                m_serial.baudRate = serial["baudRate"].get<int>();
            }
            if (serial.contains("dataBits")) {
                m_serial.dataBits = serial["dataBits"].get<int>();
            }
            if (serial.contains("stopBits")) {
                m_serial.stopBits = serial["stopBits"].get<int>();
            }
            if (serial.contains("parity")) {
                std::string parityStr = serial["parity"].get<std::string>();
                m_serial.parity = parityStr.empty() ? 'N' : parityStr[0];
            }
            if (serial.contains("timeout")) {
                m_serial.timeout = serial["timeout"].get<int>();
            }
        }

        // 解析网络配置
        if (doc.contains("network") && doc["network"].is_object()) {
            const auto& network = doc["network"];
            if (network.contains("httpHost")) {
                m_network.httpHost = network["httpHost"].get<std::string>();
            }
            if (network.contains("httpPort")) {
                m_network.httpPort = network["httpPort"].get<int>();
            }
        }

        // 解析数据采集配置
        if (doc.contains("dataAcquisition") && doc["dataAcquisition"].is_object()) {
            const auto& dataAcq = doc["dataAcquisition"];
            if (dataAcq.contains("interval")) {
                m_dataAcquisition.interval = dataAcq["interval"].get<int>();
            }
            if (dataAcq.contains("maxRetryCount")) {
                m_dataAcquisition.maxRetryCount = dataAcq["maxRetryCount"].get<int>();
            }
            if (dataAcq.contains("autoReconnect")) {
                m_dataAcquisition.autoReconnect = dataAcq["autoReconnect"].get<bool>();
            }
        }

        // 解析日志配置
        if (doc.contains("logging") && doc["logging"].is_object()) {
            const auto& logging = doc["logging"];
            if (logging.contains("logDir")) {
                m_log.logDir = logging["logDir"].get<std::string>();
            }
            if (logging.contains("logFileName")) {
                m_log.logFileName = logging["logFileName"].get<std::string>();
            }
            if (logging.contains("logLevel")) {
                m_log.logLevel = logging["logLevel"].get<std::string>();
            }
            if (logging.contains("consoleEnabled")) {
                m_log.consoleEnabled = logging["consoleEnabled"].get<bool>();
            }
            if (logging.contains("maxFileSize")) {
                m_log.maxFileSize = logging["maxFileSize"].get<int>();
            }
            if (logging.contains("maxFiles")) {
                m_log.maxFiles = logging["maxFiles"].get<int>();
            }
        }

        std::cout << "[Configuration] Config loaded from: " << path << std::endl;
        return true;

    } catch (const json::exception& e) {
        std::cerr << "[Configuration] JSON parse error: " << e.what() << std::endl;
        return false;
    }
}

bool Configuration::save(const std::string& path) const
{
    try {
        json doc;

        // 添加设备配置
        doc["device"]["address"] = m_device.address;

        // 添加串口配置
        std::string parityStr(1, m_serial.parity);
        doc["serial"]["port"] = m_serial.port;
        doc["serial"]["baudRate"] = m_serial.baudRate;
        doc["serial"]["dataBits"] = m_serial.dataBits;
        doc["serial"]["stopBits"] = m_serial.stopBits;
        doc["serial"]["parity"] = parityStr;
        doc["serial"]["timeout"] = m_serial.timeout;

        // 添加网络配置
        doc["network"]["httpHost"] = m_network.httpHost;
        doc["network"]["httpPort"] = m_network.httpPort;

        // 添加数据采集配置
        doc["dataAcquisition"]["interval"] = m_dataAcquisition.interval;
        doc["dataAcquisition"]["maxRetryCount"] = m_dataAcquisition.maxRetryCount;
        doc["dataAcquisition"]["autoReconnect"] = m_dataAcquisition.autoReconnect;

        // 添加日志配置
        doc["logging"]["logDir"] = m_log.logDir;
        doc["logging"]["logFileName"] = m_log.logFileName;
        doc["logging"]["logLevel"] = m_log.logLevel;
        doc["logging"]["consoleEnabled"] = m_log.consoleEnabled;
        doc["logging"]["maxFileSize"] = m_log.maxFileSize;
        doc["logging"]["maxFiles"] = m_log.maxFiles;

        // 写入文件
        std::ofstream file(path);
        if (!file.is_open()) {
            std::cerr << "[Configuration] Cannot create config file: " << path << std::endl;
            return false;
        }

        file << doc.dump(4);
        file.close();

        std::cout << "[Configuration] Config saved to: " << path << std::endl;
        return true;

    } catch (const json::exception& e) {
        std::cerr << "[Configuration] JSON serialization error: " << e.what() << std::endl;
        return false;
    }
}

bool Configuration::validate() const
{
    if (!m_serial.isValid()) {
        std::cerr << "[Configuration] Invalid serial configuration" << std::endl;
        return false;
    }
    if (!m_network.isValid()) {
        std::cerr << "[Configuration] Invalid network configuration" << std::endl;
        return false;
    }
    if (!m_device.isValid()) {
        std::cerr << "[Configuration] Invalid device configuration" << std::endl;
        return false;
    }
    if (!m_dataAcquisition.isValid()) {
        std::cerr << "[Configuration] Invalid data acquisition configuration" << std::endl;
        return false;
    }
    if (!m_log.isValid()) {
        std::cerr << "[Configuration] Invalid log configuration" << std::endl;
        return false;
    }
    return true;
}

void Configuration::resetToDefaults()
{
    m_serial = SerialConfig();
    m_network = NetworkConfig();
    m_device = DeviceConfig();
    m_dataAcquisition = DataAcquisitionConfig();
    m_log = LogConfig();
}
