/**
 * 本机设备运行数据。
 *
 * 这里只保存 R818/R528 本机能力的最新快照，不保存 Modbus 寄存器数据，
 * 也不负责配置落盘。
 */

#ifndef LOCALDEVICEDATASTRUCTURE_H
#define LOCALDEVICEDATASTRUCTURE_H

#include <cstdint>
#include <string>
#include <vector>

struct WifiNetworkData {
    std::string ssid;
    int rssi = 0;
    bool secured = false;
};

struct WifiRuntimeData {
    bool available = false;
    bool enabled = false;
    bool connected = false;
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string state = "disabled";
    std::string targetSsid;
    std::string connectedSsid;
    std::string ipAddress;
    int rssi = 0;
    std::string lastError;
    std::vector<WifiNetworkData> scanResults;
    int64_t timestamp = 0;
};

/**
 * 归一化一份即将发布的 WiFi 事务快照。
 *
 * WiFi 的开关、连接、SSID、IP 和扫描列表属于同一组状态，不能分别
 * 发布。这里仅消除组内不可能同时成立的组合，不执行任何系统命令。
 */
inline void normalizeWifiRuntimeData(WifiRuntimeData& data)
{
    if (!data.available) {
        data.enabled = false;
        data.connected = false;
        data.commandPending = false;
        data.state = "disabled";
        data.targetSsid.clear();
        data.scanResults.clear();
    } else if (!data.enabled) {
        data.connected = false;
        data.scanResults.clear();
        if (!data.commandPending) {
            data.state = "disabled";
            data.targetSsid.clear();
        }
    }

    if (data.connectedSsid.empty()) {
        data.connected = false;
    }
    if (!data.connected) {
        data.connectedSsid.clear();
        data.ipAddress.clear();
        data.rssi = 0;
        if (data.state == "connected") {
            data.state = data.enabled ? "idle" : "disabled";
        }
    }
}

struct ScreenRuntimeData {
    bool brightnessAvailable = false;
    int minBrightness = 0;
    int maxBrightness = 255;
    int currentBrightness = 128;
    bool sleepStateAvailable = false;
    bool sleeping = false;
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string lastError;
};

struct TemperatureHumidityRuntimeData {
    bool temperatureAvailable = false;
    bool humidityAvailable = false;
    bool serialAvailable = false;
    float temperature = 25.5f;
    float humidity = 60.0f;
    std::string serial;
    int64_t timestamp = 0;
};

struct RadarRuntimeData {
    bool enable = false;
    bool online = false;
    int distance = 0;
    int velocity = 0;
    int signal = 0;
    int gesture = 0;
    bool approach = false;
    bool depart = false;
    std::string direction = "unknown";
    int64_t timestamp = 0;
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string lastError;
};

struct AqiLedRuntimeData {
    bool stateAvailable = false;
    int level = 0;
    std::string color = "000000";
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string lastError;
};

struct SpeakerRuntimeData {
    bool available = false;
    bool enabled = false;
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string lastError;
};

struct OtaRuntimeData {
    bool available = false;
    bool updateAvailable = false;
    std::string currentVersion;
    std::string targetVersion;
    uint64_t fwSize = 0;
    std::string fwMd5;
    std::string state = "idle";
    int percent = 0;
    uint64_t downloadedBytes = 0;
    bool commandPending = false;
    bool lastCommandSuccess = false;
    std::string lastError;
    int64_t timestamp = 0;
};

struct LocalDeviceDataStructure {
    WifiRuntimeData wifi;
    ScreenRuntimeData screen;
    TemperatureHumidityRuntimeData temperatureHumidity;
    RadarRuntimeData radar;
    AqiLedRuntimeData aqiLed;
    SpeakerRuntimeData speaker;
    OtaRuntimeData ota;
    int64_t timestamp = 0;
};

#endif // LOCALDEVICEDATASTRUCTURE_H
