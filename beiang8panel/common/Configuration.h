/**
 * Configuration - 统一配置管理类
 *
 * 集中管理所有配置项，支持从JSON文件加载和保存
 * 消除硬编码配置值散布各处的问题
 */

#ifndef CONFIGURATION_H
#define CONFIGURATION_H

#include <string>

class Configuration {
public:
    // ========== 串口配置 ==========
    struct SerialConfig {
        std::string port = "/dev/ttyS0";
        int baudRate = 9600;
        int dataBits = 8;
        int stopBits = 1;
        char parity = 'N';
        int timeout = 500; // 毫秒

        // 验证配置有效性
        bool isValid() const;
    };

    // ========== 网络配置 ==========
    struct NetworkConfig {
        std::string httpHost = "0.0.0.0";
        int httpPort = 8080;

        bool isValid() const;
    };

    // ========== 设备配置 ==========
    struct DeviceConfig {
        int address = 209; // Modbus从站地址（0xD1）

        bool isValid() const;
    };

    // ========== 数据采集配置 ==========
    struct DataAcquisitionConfig {
        int interval = 1000; // 毫秒
        int maxRetryCount = 5;
        bool autoReconnect = true;

        bool isValid() const;
    };

    // ========== 日志配置 ==========
    struct LogConfig {
        std::string logDir = "logs";
        std::string logFileName = "beiang8panel";
        std::string logLevel = "INFO"; // DEBUG, INFO, WARNING, ERROR, FATAL
        bool consoleEnabled = true;
        int maxFileSize = 10485760; // 10MB
        int maxFiles = 5;

        bool isValid() const;
    };

public:
    Configuration();

    /**
     * @brief 从JSON文件加载配置
     * @param path 配置文件路径
     * @return true 加载成功
     */
    bool load(const std::string& path);

    /**
     * @brief 保存配置到JSON文件
     * @param path 配置文件路径
     * @return true 保存成功
     */
    bool save(const std::string& path) const;

    /**
     * @brief 验证所有配置项
     * @return true 所有配置有效
     */
    bool validate() const;

    /**
     * @brief 重置为默认值
     */
    void resetToDefaults();

    // ========== 配置访问接口 ==========
    SerialConfig& serial() { return m_serial; }
    const SerialConfig& serial() const { return m_serial; }

    NetworkConfig& network() { return m_network; }
    const NetworkConfig& network() const { return m_network; }

    DeviceConfig& device() { return m_device; }
    const DeviceConfig& device() const { return m_device; }

    DataAcquisitionConfig& dataAcquisition() { return m_dataAcquisition; }
    const DataAcquisitionConfig& dataAcquisition() const { return m_dataAcquisition; }

    LogConfig& log() { return m_log; }
    const LogConfig& log() const { return m_log; }

private:
    SerialConfig m_serial;
    NetworkConfig m_network;
    DeviceConfig m_device;
    DataAcquisitionConfig m_dataAcquisition;
    LogConfig m_log;
};

#endif // CONFIGURATION_H
