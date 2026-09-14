#include "LocalDeviceModule.h"

#include "DataManager.h"
#include "common/LogManager.h"
#include "structure/LocalDeviceDataStructure.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <glob.h>
#include <hv/json.hpp>
#include <sstream>
#include <sys/ioctl.h>
#include <unistd.h>
#include <utility>

using json = nlohmann::json;

namespace {

constexpr int LOCAL_DATA_INTERVAL_MS = 1000;

constexpr const char* DISP_DEV_NAME = "/dev/disp";
constexpr unsigned long DISP_LCD_SET_BRIGHTNESS = 0x102;
constexpr unsigned long DISP_LCD_GET_BRIGHTNESS = 0x103;
constexpr unsigned long DISP_OUT_SRC_SEL_LCD = 0x00;

constexpr const char* HWMON_TEMP_PATH = "/sys/class/hwmon/hwmon0/temp1_input";
constexpr const char* HWMON_HUMIDITY_PATH = "/sys/class/hwmon/hwmon0/humidity1_input";
constexpr const char* GXHTC3_SERIAL_PATH = "/sys/bus/i2c/devices/1-0070/gxhtc3/serial_id";
constexpr const char* AQI_LED_PATH = "/sys/class/led/multi_brightness";
constexpr const char* AQI_LED_FIFO_PATH = "/tmp/rgb_test_fifo";

int64_t nowMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

bool canReadPath(const std::string& path)
{
    return !path.empty() && access(path.c_str(), R_OK) == 0;
}

bool canWritePath(const std::string& path)
{
    return !path.empty() && access(path.c_str(), W_OK) == 0;
}

bool readIntegerFile(const char* path, int& value)
{
    if (!path || !canReadPath(path)) {
        return false;
    }

    FILE* file = fopen(path, "r");
    if (!file) {
        return false;
    }

    int result = 0;
    bool success = fscanf(file, "%d", &result) == 1;
    fclose(file);
    if (success) {
        value = result;
    }
    return success;
}

bool readStringFile(const char* path, std::string& value)
{
    if (!path || !canReadPath(path)) {
        return false;
    }

    FILE* file = fopen(path, "r");
    if (!file) {
        return false;
    }

    char buffer[128] = {0};
    if (!fgets(buffer, sizeof(buffer), file)) {
        fclose(file);
        return false;
    }
    fclose(file);

    size_t length = strlen(buffer);
    while (length > 0 && (buffer[length - 1] == '\n' || buffer[length - 1] == '\r')) {
        buffer[--length] = '\0';
    }
    value.assign(buffer);
    return true;
}

bool writeStringFile(const std::string& path, const std::string& value)
{
    // 只写已存在且当前可写的固定接口，不创建文件、不修改权限。
    if (!canWritePath(path)) {
        return false;
    }

    std::ofstream file(path, std::ios::trunc);
    if (!file.is_open()) {
        return false;
    }
    file << value;
    return file.good();
}

bool readBacklightSysfsPath(const std::string& brightnessPath, int& current, int& maximum)
{
    std::string maximumPath = brightnessPath.substr(
        0, brightnessPath.size() - strlen("brightness")) + "max_brightness";
    int candidateCurrent = 0;
    int candidateMaximum = 0;
    if (!readIntegerFile(brightnessPath.c_str(), candidateCurrent)
        || !readIntegerFile(maximumPath.c_str(), candidateMaximum)) {
        return false;
    }

    current = candidateCurrent;
    maximum = candidateMaximum;
    return true;
}

bool readBacklightFromSysfs(int& current, int& maximum)
{
    glob_t paths;
    if (glob("/sys/class/backlight/*/brightness", GLOB_NOSORT, nullptr, &paths) != 0) {
        return false;
    }

    bool found = false;
    for (size_t i = 0; i < paths.gl_pathc && !found; ++i) {
        std::string brightnessPath = paths.gl_pathv[i];
        found = readBacklightSysfsPath(brightnessPath, current, maximum);
    }

    globfree(&paths);
    return found;
}

bool writeBacklightToSysfs(int value, std::string& writtenPath)
{
    glob_t paths;
    if (glob("/sys/class/backlight/*/brightness", GLOB_NOSORT, nullptr, &paths) != 0) {
        return false;
    }

    bool written = false;
    for (size_t i = 0; i < paths.gl_pathc && !written; ++i) {
        const char* path = paths.gl_pathv[i];
        if (!canWritePath(path)) {
            continue;
        }

        FILE* file = fopen(path, "w");
        if (file) {
            written = fprintf(file, "%d", value) > 0;
            fclose(file);
            if (written) {
                writtenPath = path;
            }
        }
    }

    globfree(&paths);
    return written;
}

bool readBrightnessFromDisp(int& value)
{
    if (access(DISP_DEV_NAME, R_OK | W_OK) != 0) {
        return false;
    }

    int file = open(DISP_DEV_NAME, O_RDWR);
    if (file < 0) {
        return false;
    }

    unsigned long parameters[4] = {DISP_OUT_SRC_SEL_LCD, 0, 0, 0};
    int result = ioctl(file, DISP_LCD_GET_BRIGHTNESS, parameters);
    close(file);
    if (result < 0) {
        return false;
    }
    value = result;	/* 驱动返回 0-255 原始亮度 */
    return true;
}

bool writeBrightnessToDisp(int value)
{
    if (access(DISP_DEV_NAME, R_OK | W_OK) != 0) {
        return false;
    }

    int file = open(DISP_DEV_NAME, O_RDWR);
    if (file < 0) {
        return false;
    }

    /* DISP_LCD_SET_BRIGHTNESS 的取值域是 0-255(dev_disp.c 直传, 驱动内钳位 255),
     * 不能换算成 0-100, 否则满亮度只到 39% 亮度档(PWM 正占空比 60% 而非 0%) */
    int displayValue = std::max(0, std::min(value, 255));
    unsigned long parameters[4] = {
        DISP_OUT_SRC_SEL_LCD,
        static_cast<unsigned long>(displayValue),
        0,
        0
    };
    int result = ioctl(file, DISP_LCD_SET_BRIGHTNESS, parameters);
    close(file);
    return result >= 0;
}

const char* aqiLedColor(int level)
{
    // PM2.5 分级: L1 优(<=35) L2 良(35~75] L3 中度污染(75~150] L4 重度污染(>150)
    // L5 为严重故障告警: 红色快速呼吸(pm25 自动分级不会产生, 仅 level=5 显式指定)
    static const char* colors[] = {
        "000000", "05DF72", "C2DF05", "F59E0B", "EF4444", "EF4444"
    };
    return colors[level];
}

} // namespace

LocalDeviceModule::LocalDeviceModule(DataManager* dataManager)
    : m_dataManager(dataManager)
    , m_running(false)
    , m_stopRequested(false)
{
}

LocalDeviceModule::~LocalDeviceModule()
{
    stop();
}

bool LocalDeviceModule::start()
{
    if (m_running.load()) {
        return true;
    }
    if (!m_dataManager) {
        return false;
    }

    collectLocalData();
    m_stopRequested = false;
    m_running = true;
    m_worker = std::thread(&LocalDeviceModule::workerLoop, this);
    LOG_INFO("[LocalDevice] Worker started");
    return true;
}

void LocalDeviceModule::stop()
{
    if (!m_running.load()) {
        return;
    }

    {
        std::lock_guard<std::mutex> lock(m_queueMutex);
        m_stopRequested = true;
    }
    m_queueCondition.notify_all();
    if (m_worker.joinable()) {
        m_worker.join();
    }
    m_running = false;
    LOG_INFO("[LocalDevice] Worker stopped");
}

bool LocalDeviceModule::submitCommand(LocalDeviceCommand command)
{
    std::lock_guard<std::mutex> lock(m_queueMutex);
    if (!m_running.load() || m_stopRequested) {
        return false;
    }
    markCommandPending(command);
    m_commands.push_back(std::move(command));
    m_queueCondition.notify_one();
    return true;
}

void LocalDeviceModule::markCommandPending(const LocalDeviceCommand& command)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    switch (command.type) {
    case LocalDeviceCommandType::SetScreenSleep:
    case LocalDeviceCommandType::SetScreenBrightness:
        data.screen.commandPending = true;
        data.screen.lastCommandSuccess = false;
        data.screen.lastError.clear();
        break;
    case LocalDeviceCommandType::SetRadarEnabled:
        data.radar.commandPending = true;
        data.radar.lastCommandSuccess = false;
        data.radar.lastError.clear();
        break;
    case LocalDeviceCommandType::SetAqiLedLevel:
        data.aqiLed.commandPending = true;
        data.aqiLed.lastCommandSuccess = false;
        data.aqiLed.lastError.clear();
        break;
    case LocalDeviceCommandType::SetSpeakerEnabled:
        data.speaker.commandPending = true;
        data.speaker.lastCommandSuccess = false;
        data.speaker.lastError.clear();
        break;
    }
    data.timestamp = nowMilliseconds();
    m_dataManager->updateLocalHardwareData(data);
}

void LocalDeviceModule::workerLoop()
{
    auto nextCollection = std::chrono::steady_clock::now()
        + std::chrono::milliseconds(LOCAL_DATA_INTERVAL_MS);

    while (true) {
        LocalDeviceCommand command;
        bool hasCommand = false;
        {
            std::unique_lock<std::mutex> lock(m_queueMutex);
            m_queueCondition.wait_until(lock, nextCollection, [this]() {
                return m_stopRequested || !m_commands.empty();
            });

            if (m_stopRequested) {
                break;
            }
            if (!m_commands.empty()) {
                command = std::move(m_commands.front());
                m_commands.pop_front();
                hasCommand = true;
            }
        }

        if (hasCommand) {
            processCommand(command);
        }

        if (std::chrono::steady_clock::now() >= nextCollection) {
            collectLocalData();
            nextCollection = std::chrono::steady_clock::now()
                + std::chrono::milliseconds(LOCAL_DATA_INTERVAL_MS);
        }
    }
}

void LocalDeviceModule::collectLocalData()
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    bool dataChanged = false;

    int currentBrightness = data.screen.currentBrightness;
    int maximumBrightness = data.screen.maxBrightness;
    if (readBacklightFromSysfs(currentBrightness, maximumBrightness)) {
        data.screen.brightnessAvailable = true;
        data.screen.currentBrightness = currentBrightness;
        data.screen.maxBrightness = maximumBrightness;
        dataChanged = true;
    } else {
        int displayBrightness = 0;
        if (readBrightnessFromDisp(displayBrightness)) {
            data.screen.brightnessAvailable = true;
            data.screen.currentBrightness = displayBrightness;
            data.screen.maxBrightness = 255;
            dataChanged = true;
        }
    }

    bool sensorChanged = false;
    int temperatureRaw = 0;
    if (readIntegerFile(HWMON_TEMP_PATH, temperatureRaw)) {
        data.temperatureHumidity.temperatureAvailable = true;
        data.temperatureHumidity.temperature = temperatureRaw / 1000.0f;
        sensorChanged = true;
    }

    int humidityRaw = 0;
    if (readIntegerFile(HWMON_HUMIDITY_PATH, humidityRaw)) {
        data.temperatureHumidity.humidityAvailable = true;
        data.temperatureHumidity.humidity = humidityRaw / 1000.0f;
        sensorChanged = true;
    }

    std::string serial;
    if (readStringFile(GXHTC3_SERIAL_PATH, serial) && !serial.empty()) {
        data.temperatureHumidity.serial = std::move(serial);
        data.temperatureHumidity.serialAvailable = true;
        sensorChanged = true;
    }
    if (sensorChanged) {
        data.temperatureHumidity.timestamp = nowMilliseconds();
        dataChanged = true;
    }

    const std::string statusFile = m_dataManager->getRadarStatusFile();
    if (canReadPath(statusFile)) {
        std::ifstream input(statusFile);
        std::stringstream buffer;
        buffer << input.rdbuf();
        try {
            json document = json::parse(buffer.str());
            RadarRuntimeData radar = data.radar;
            radar.enable = document.value("enable", false);
            radar.online = document.value("online", false);
            radar.distance = document.value("distance", 0);
            radar.velocity = document.value("velocity", 0);
            radar.signal = document.value("signal", 0);
            radar.gesture = document.value("gesture", 0);
            radar.approach = document.value("approach", false);
            radar.depart = document.value("depart", false);
            radar.direction = document.value("direction", "unknown");
            radar.timestamp = document.value("timestamp", 0LL);
            data.radar = std::move(radar);
            dataChanged = true;
        } catch (const json::exception&) {
            // 无效快照不覆盖上一次有效数据。
        }
    }
    if (dataChanged) {
        data.timestamp = nowMilliseconds();
        m_dataManager->updateLocalHardwareData(data);
    }
}

void LocalDeviceModule::processCommand(const LocalDeviceCommand& command)
{
    switch (command.type) {
    case LocalDeviceCommandType::SetScreenSleep:
        processScreenSleep(command.boolValue);
        break;
    case LocalDeviceCommandType::SetScreenBrightness:
        processScreenBrightness(command.intValue);
        break;
    case LocalDeviceCommandType::SetRadarEnabled:
        processRadarEnabled(command.boolValue);
        break;
    case LocalDeviceCommandType::SetAqiLedLevel:
        processAqiLedLevel(command.intValue, command.textValue);
        break;
    case LocalDeviceCommandType::SetSpeakerEnabled:
        processSpeakerEnabled(command.boolValue);
        break;
    }
}

void LocalDeviceModule::processScreenSleep(bool sleep)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    data.screen.commandPending = true;
    data.screen.lastError.clear();
    m_dataManager->updateLocalHardwareData(data);

    const std::string commandPath = "/sys/kernel/debug/dispdbg/command";
    const std::string namePath = "/sys/kernel/debug/dispdbg/name";
    const std::string startPath = "/sys/kernel/debug/dispdbg/start";
    bool success = canWritePath(commandPath)
        && canWritePath(namePath)
        && canWritePath(startPath)
        && writeStringFile(commandPath, sleep ? "suspend" : "resume")
        && writeStringFile(namePath, "disp0")
        && writeStringFile(startPath, "1");

    data.screen.commandPending = false;
    data.screen.lastCommandSuccess = success;
    data.screen.lastError = success ? "" : "screen control interface is unavailable";
    if (success) {
        // 接口只返回写入成功时，按接口契约采用请求值。
        data.screen.sleepStateAvailable = true;
        data.screen.sleeping = sleep;
    }
    m_dataManager->updateLocalHardwareData(data);
}

void LocalDeviceModule::processScreenBrightness(int brightness)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    data.screen.commandPending = true;
    data.screen.lastError.clear();
    m_dataManager->updateLocalHardwareData(data);

    std::string writtenSysfsPath;
    bool usedSysfs = writeBacklightToSysfs(brightness, writtenSysfsPath);
    int requestedBrightness = brightness;
    if (!usedSysfs) {
        requestedBrightness = std::max(0, std::min(brightness, 255));
    }
    bool writeSuccess = usedSysfs || writeBrightnessToDisp(requestedBrightness);

    data.screen.commandPending = false;
    data.screen.lastCommandSuccess = false;
    data.screen.lastError = writeSuccess
        ? "backlight write completed but readback failed"
        : "backlight device is unavailable";
    if (writeSuccess) {
        int actual = 0;
        int actualMaximum = data.screen.maxBrightness;
        bool hasActualValue = usedSysfs
            ? readBacklightSysfsPath(writtenSysfsPath, actual, actualMaximum)
            : readBrightnessFromDisp(actual);
        if (hasActualValue) {
            data.screen.lastCommandSuccess = true;
            data.screen.lastError.clear();
            data.screen.brightnessAvailable = true;
            data.screen.currentBrightness = actual;
            data.screen.maxBrightness = usedSysfs ? actualMaximum : 255;
        }
    }
    m_dataManager->updateLocalHardwareData(data);
}

void LocalDeviceModule::processRadarEnabled(bool enable)
{
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    data.radar.commandPending = true;
    data.radar.lastError.clear();
    m_dataManager->updateLocalHardwareData(data);

    const std::string commandFile = m_dataManager->getRadarCommandFile();
    bool success = !commandFile.empty()
        && writeStringFile(commandFile, enable ? "on" : "off");

    data.radar.commandPending = false;
    data.radar.lastCommandSuccess = success;
    data.radar.lastError = success ? "" : "radar command file is unavailable";
    m_dataManager->updateLocalHardwareData(data);
}

int LocalDeviceModule::pm25ToAqiLevel(int pm25)
{
    if (pm25 < 0) {
        return 0;
    }
    if (pm25 <= 35) {
        return 1;
    }
    if (pm25 <= 75) {
        return 2;
    }
    if (pm25 <= 150) {
        return 3;
    }
    return 4;
}

void LocalDeviceModule::processAqiLedLevel(int level, const std::string& colorOverride)
{
    level = std::max(0, std::min(level, 5));
    std::string color = colorOverride.empty() ? aqiLedColor(level) : colorOverride;

    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    data.aqiLed.commandPending = true;
    data.aqiLed.lastError.clear();
    m_dataManager->updateLocalHardwareData(data);

    // 呼吸效果由 rgb_daemon 渲染(BREATHE 3秒周期, level=5 FAST_BREATHE 1秒周期, 三组同色)
    // 用 O_NONBLOCK 打开 FIFO 探测读端: daemon 不在(含 FIFO 残留文件)时 ENXIO,
    // 此时直接熄灭(multi_brightness 全黑), 不做常亮回退
    bool success = false;
    const int fifoFd = open(AQI_LED_FIFO_PATH, O_WRONLY | O_NONBLOCK);
    if (fifoFd >= 0) {
        const char* mode = "BREATHE";
        if (level == 0 && colorOverride.empty()) {
            mode = "STEADY";
            color = "000000";
        } else if (level == 5) {
            mode = "FAST_BREATHE";   // 严重故障: 红色快速呼吸(1秒周期)
        }
        std::string command = std::string(mode) + "," + color;
        for (int index = 1; index < 3; ++index) {
            command += std::string(",") + mode + "," + color;
        }
        const ssize_t written = ::write(fifoFd, command.c_str(), command.size());
        close(fifoFd);
        success = written == static_cast<ssize_t>(command.size());
    }
    if (!success) {
        std::string off;
        for (int index = 0; index < 9; ++index) {
            off += " 000000";
        }
        success = writeStringFile(AQI_LED_PATH, off.substr(1));
        if (success) {
            // daemon 不在: 已熄灭, 上报状态标记为关闭
            level = 0;
            color = "000000";
        }
    }
    data.aqiLed.commandPending = false;
    data.aqiLed.lastCommandSuccess = success;
    if (success) {
        // AQI 灯按只写接口处理；驱动回读不属于应用层状态契约。
        data.aqiLed.lastError.clear();
        data.aqiLed.stateAvailable = true;
        data.aqiLed.level = level;
        data.aqiLed.color = color;
    } else {
        data.aqiLed.lastError = "AQI LED interface is unavailable";
    }
    m_dataManager->updateLocalHardwareData(data);
}

void LocalDeviceModule::processSpeakerEnabled(bool enable)
{
    (void)enable;
    LocalDeviceDataStructure data = m_dataManager->getLocalDeviceDataSnapshot();
    data.speaker.commandPending = false;
    data.speaker.lastCommandSuccess = false;
    data.speaker.lastError = "speaker system adapter is not implemented";
    m_dataManager->updateLocalHardwareData(data);
}
