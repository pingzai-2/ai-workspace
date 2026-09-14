/**
 * 系统设置数据结构实现
 */

#include "SystemSettingsDataStructure.h"
#include <hv/json.hpp>

using json = nlohmann::json;
using namespace std;

SystemSettingsDataStructure::SystemSettingsDataStructure()
    : m_language("zh-CN")
    , m_timezone("Asia/Shanghai")
{
    // 初始化默认值
}

string SystemSettingsDataStructure::toJson() const {
    json doc;
    doc["language"] = m_language;
    doc["timezone"] = m_timezone;

    // 网络配置
    doc["networkConfig"]["wifiSSID"] = m_networkConfig.wifiSSID;
    doc["networkConfig"]["wifiPassword"] = m_networkConfig.wifiPassword;
    doc["networkConfig"]["ipAddress"] = m_networkConfig.ipAddress;
    doc["networkConfig"]["netmask"] = m_networkConfig.netmask;
    doc["networkConfig"]["gateway"] = m_networkConfig.gateway;
    doc["networkConfig"]["useDHCP"] = m_networkConfig.useDHCP;

    // 显示配置
    doc["displayConfig"]["brightness"] = m_displayConfig.brightness;
    doc["displayConfig"]["screenSaverTime"] = m_displayConfig.screenSaverTime;
    doc["displayConfig"]["autoSleep"] = m_displayConfig.autoSleep;
    doc["displayConfig"]["autoSleepTime"] = m_displayConfig.autoSleepTime;

    return doc.dump();
}

bool SystemSettingsDataStructure::fromJson(const string& jsonStr) {
    try {
        json doc = json::parse(jsonStr);

        // 解析系统设置
        if (doc.contains("language"))
            m_language = doc["language"].get<string>();

        if (doc.contains("timezone"))
            m_timezone = doc["timezone"].get<string>();

        // 解析网络配置
        if (doc.contains("networkConfig") && doc["networkConfig"].is_object()) {
            const auto& networkConfig = doc["networkConfig"];
            if (networkConfig.contains("wifiSSID"))
                m_networkConfig.wifiSSID = networkConfig["wifiSSID"].get<string>();
            if (networkConfig.contains("wifiPassword"))
                m_networkConfig.wifiPassword = networkConfig["wifiPassword"].get<string>();
            if (networkConfig.contains("ipAddress"))
                m_networkConfig.ipAddress = networkConfig["ipAddress"].get<string>();
            if (networkConfig.contains("netmask"))
                m_networkConfig.netmask = networkConfig["netmask"].get<string>();
            if (networkConfig.contains("gateway"))
                m_networkConfig.gateway = networkConfig["gateway"].get<string>();
            if (networkConfig.contains("useDHCP"))
                m_networkConfig.useDHCP = networkConfig["useDHCP"].get<bool>();
        }

        // 解析显示配置
        if (doc.contains("displayConfig") && doc["displayConfig"].is_object()) {
            const auto& displayConfig = doc["displayConfig"];
            if (displayConfig.contains("brightness"))
                m_displayConfig.brightness = displayConfig["brightness"].get<int>();
            if (displayConfig.contains("screenSaverTime"))
                m_displayConfig.screenSaverTime = displayConfig["screenSaverTime"].get<int>();
            if (displayConfig.contains("autoSleep"))
                m_displayConfig.autoSleep = displayConfig["autoSleep"].get<bool>();
            if (displayConfig.contains("autoSleepTime"))
                m_displayConfig.autoSleepTime = displayConfig["autoSleepTime"].get<int>();
        }

        return true;
    } catch (const json::exception& e) {
        return false;
    }
}
