/**
 * 本机设备模块。
 *
 * 一个工作线程串行执行本机命令，并周期采集 sysfs、状态文件等本机数据。
 * HTTP 线程只投递命令和读取 DataManager 快照。
 */

#ifndef LOCALDEVICEMODULE_H
#define LOCALDEVICEMODULE_H

#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

class DataManager;

enum class LocalDeviceCommandType {
    SetScreenSleep,
    SetScreenBrightness,
    SetRadarEnabled,
    SetAqiLedLevel,
    SetSpeakerEnabled
};

struct LocalDeviceCommand {
    LocalDeviceCommandType type = LocalDeviceCommandType::SetScreenBrightness;
    bool boolValue = false;
    int intValue = 0;
    std::string textValue;
    std::string secretValue;
};

class LocalDeviceModule {
public:
    explicit LocalDeviceModule(DataManager* dataManager);
    ~LocalDeviceModule();

    bool start();
    void stop();
    bool submitCommand(LocalDeviceCommand command);

    // PM2.5(ug/m3) -> AQI 灯等级: <=35→1 优, <=75→2 良, <=150→3 中度, >150→4 重度
    static int pm25ToAqiLevel(int pm25);
    bool isRunning() const { return m_running.load(); }

private:
    void workerLoop();
    void collectLocalData();
    void processCommand(const LocalDeviceCommand& command);
    void markCommandPending(const LocalDeviceCommand& command);

    void processScreenSleep(bool sleep);
    void processScreenBrightness(int brightness);
    void processRadarEnabled(bool enable);
    void processAqiLedLevel(int level, const std::string& colorOverride = std::string());
    void processSpeakerEnabled(bool enable);

    DataManager* m_dataManager;
    std::thread m_worker;
    std::atomic<bool> m_running;
    bool m_stopRequested;
    std::mutex m_queueMutex;
    std::condition_variable m_queueCondition;
    std::deque<LocalDeviceCommand> m_commands;
};

#endif // LOCALDEVICEMODULE_H
