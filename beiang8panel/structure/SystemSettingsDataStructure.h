/**
 * 系统设置数据结构类
 */

#ifndef SYSTEMSETTINGSDATASTRUCTURE_H
#define SYSTEMSETTINGSDATASTRUCTURE_H

#include <string>
#include "common/GlobalDefine.h"

// 网络配置
struct NetworkConfig {
    std::string wifiSSID;           // WiFi SSID
    std::string wifiPassword;       // WiFi密码
    std::string ipAddress;          // IP地址
    std::string netmask;            // 子网掩码
    std::string gateway;            // 网关
    bool useDHCP;                   // 使用DHCP

    NetworkConfig()
        : wifiSSID("")
        , wifiPassword("")
        , ipAddress("192.168.1.100")
        , netmask("255.255.255.0")
        , gateway("192.168.1.1")
        , useDHCP(true)
    {}
};

// 显示设置
struct DisplayConfig {
    int brightness;                 // 亮度 (0-100)
    int screenSaverTime;           // 屏幕保护时间 (秒)
    bool autoSleep;                // 自动休眠
    int autoSleepTime;             // 自动休眠时间 (秒)

    DisplayConfig()
        : brightness(80)
        , screenSaverTime(300)
        , autoSleep(true)
        , autoSleepTime(600)
    {}
};

// 系统设置数据结构类
class SystemSettingsDataStructure {
public:
    SystemSettingsDataStructure();
    ~SystemSettingsDataStructure() = default;

    // 网络配置
    NetworkConfig& getNetworkConfig() { return m_networkConfig; }
    const NetworkConfig& getNetworkConfig() const { return m_networkConfig; }

    // 显示配置
    DisplayConfig& getDisplayConfig() { return m_displayConfig; }
    const DisplayConfig& getDisplayConfig() const { return m_displayConfig; }

    // 系统语言
    std::string getLanguage() const { return m_language; }
    void setLanguage(const std::string& lang) { m_language = lang; }

    // 系统时区
    std::string getTimezone() const { return m_timezone; }
    void setTimezone(const std::string& tz) { m_timezone = tz; }

    // 数据序列化
    std::string toJson() const;
    bool fromJson(const std::string& json);

private:
    NetworkConfig m_networkConfig;
    DisplayConfig m_displayConfig;
    std::string m_language;         // 系统语言
    std::string m_timezone;        // 系统时区
};

#endif // SYSTEMSETTINGSDATASTRUCTURE_H
