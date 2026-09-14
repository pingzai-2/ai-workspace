/**
 * HistoryRecorder 实现
 */

#include "HistoryRecorder.h"
#include "HistoryStorage.h"
#include "DataManager.h"
#include "common/LogManager.h"

#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstring>
#include <ctime>
#include <system_error>
#include <unistd.h>

#include <algorithm>

namespace {

// 输入寄存器 200DH-2014H: RA1(室内)温/湿/PM2.5/CO₂ + OA(室外)同样四项
constexpr uint16_t HISTORY_INPUT_START = 0x200D;
constexpr uint16_t HISTORY_INPUT_COUNT = 8;

int clampInterval(int seconds)
{
    if (seconds < 60) {
        return 60;
    }
    if (seconds > 86400) {
        return 86400;
    }
    return seconds;
}

// 桶序列 → JSON 数组;温度 1 位小数(原值×10 取整后 /10),其余取整,空桶 null
nlohmann::json seriesToJson(
    const std::vector<HistoryBucketAggregate>& buckets, int series, bool temperatureStyle)
{
    nlohmann::json array = nlohmann::json::array();
    for (const HistoryBucketAggregate& bucket : buckets) {
        if (bucket.count[series] <= 0) {
            array.push_back(nullptr);
            continue;
        }
        const double mean = bucket.sum[series] / bucket.count[series];
        if (temperatureStyle) {
            array.push_back(std::round(mean) / 10.0);
        } else {
            array.push_back(static_cast<int64_t>(std::llround(mean)));
        }
    }
    return array;
}

std::string formatDateTime(int64_t epochSec)
{
    char buf[24];
    time_t t = static_cast<time_t>(epochSec);
    tm value;
    localtime_r(&t, &value);
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &value);
    return std::string(buf);
}

} // namespace

HistoryRecorder::HistoryRecorder(DataManager* dataManager, const Config& config)
    : m_dataManager(dataManager)
    , m_config(config)
{
    m_config.sampleIntervalSec = clampInterval(m_config.sampleIntervalSec);
    if (m_config.retentionDays < 1) {
        m_config.retentionDays = 1;
    }
}

HistoryRecorder::~HistoryRecorder()
{
    stop();
}

bool HistoryRecorder::start()
{
    if (m_running.exchange(true)) {
        return true;
    }
    if (!m_config.enabled) {
        LOG_INFO("[HistoryRecorder] disabled by config, sampling skipped");
        return true;
    }
    try {
        m_thread = std::thread(&HistoryRecorder::samplingLoop, this);
    } catch (const std::system_error& e) {
        m_running = false;
        LOG_ERROR("[HistoryRecorder] failed to start thread: {}", e.what());
        return false;
    }
    LOG_INFO("[HistoryRecorder] started: dir={} interval={}s retention={}d",
        m_config.dataDir, m_config.sampleIntervalSec, m_config.retentionDays);
    return true;
}

void HistoryRecorder::stop()
{
    if (!m_running.exchange(false)) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(m_stopMutex);
    }
    m_stopCv.notify_all();
    if (m_thread.joinable()) {
        m_thread.join();
    }
    std::lock_guard<std::mutex> guard(m_mutex);
    closeFileLocked();
    LOG_INFO("[HistoryRecorder] stopped, samples appended this run: {}", m_totalSamples);
}

void HistoryRecorder::samplingLoop()
{
    while (m_running.load()) {
        const int interval = m_config.sampleIntervalSec;
        const int64_t now = static_cast<int64_t>(::time(nullptr));
        // 对齐到下一个采样边界;线程被停止请求唤醒时立即退出
        const int64_t next = (now / interval + 1) * interval;
        std::unique_lock<std::mutex> lock(m_stopMutex);
        m_stopCv.wait_until(lock,
            std::chrono::system_clock::from_time_t(static_cast<time_t>(next)),
            [this] { return !m_running.load(); });
        lock.unlock();
        if (!m_running.load()) {
            break;
        }
        // 以边界时刻为标称时间:线程晚醒(如系统挂起)仍保持时间对齐
        appendSampleAtTime(next);
    }
}

void HistoryRecorder::appendSampleAtTime(int64_t atEpochSec)
{
    uint16_t regs[HISTORY_INPUT_COUNT] = {0};
    // 只在缓存有效且 Modbus 通信新鲜时采样;不满足直接留空桶
    if (!m_dataManager->readInputFromCache(
            HISTORY_INPUT_START, HISTORY_INPUT_COUNT, regs)) {
        return;
    }
    if (!m_dataManager->isModbusDataFresh()) {
        return;
    }

    HistorySampleRecord record = {};
    time_t t = static_cast<time_t>(atEpochSec);
    tm localTime;
    localtime_r(&t, &localTime);
    record.minuteOfDay =
        static_cast<uint16_t>(localTime.tm_hour * 60 + localTime.tm_min);
    record.raTemperatureX10 = static_cast<int16_t>(regs[0]);
    record.raHumidity = regs[1];
    record.raPm25 = regs[2];
    record.raCo2 = regs[3];
    record.oaTemperatureX10 = static_cast<int16_t>(regs[4]);
    record.oaHumidity = regs[5];
    record.oaPm25 = regs[6];
    record.oaCo2 = regs[7];

    std::lock_guard<std::mutex> guard(m_mutex);
    const int dateInt = (localTime.tm_year + 1900) * 10000
        + (localTime.tm_mon + 1) * 100 + localTime.tm_mday;
    if (!ensureOpenForDate(dateInt)) {
        return;
    }
    // 同一分钟去重(对时回拨时丢弃重复样本)
    if (std::find(m_todayMinutes.begin(), m_todayMinutes.end(), record.minuteOfDay)
        != m_todayMinutes.end()) {
        return;
    }
    if (!HistoryStorage::appendSample(m_fileFd, record)) {
        m_storageError = std::string("append failed: ") + std::strerror(errno);
        LOG_ERROR("[HistoryRecorder] {}", m_storageError);
        closeFileLocked(); // 下个采样周期重开自愈
        return;
    }
    if (!m_storageError.empty()) {
        LOG_WARNING("[HistoryRecorder] storage recovered: {}", m_storageError);
        m_storageError.clear();
    }
    m_todayMinutes.push_back(record.minuteOfDay);
    m_lastSampleEpoch = atEpochSec;
    ++m_totalSamples;
}

bool HistoryRecorder::ensureOpenForDate(int dateInt)
{
    if (m_fileFd >= 0 && m_fileDate == dateInt) {
        return true;
    }

    closeFileLocked();

    if (!HistoryStorage::ensureDirectory(m_config.dataDir)) {
        m_storageError = "mkdir failed: " + m_config.dataDir + ": "
            + std::strerror(errno);
        LOG_ERROR("[HistoryRecorder] {}", m_storageError);
        return false;
    }

    // 启动与跨天时清理保留期外文件
    const int cutoffDate = dateIntAddDays(dateInt, -(m_config.retentionDays - 1));
    const int removed = HistoryStorage::pruneOldFiles(m_config.dataDir, cutoffDate);
    if (removed > 0) {
        LOG_INFO("[HistoryRecorder] pruned {} file(s) before {}", removed, cutoffDate);
    }

    m_fileFd = HistoryStorage::openAppendFile(m_config.dataDir, dateInt);
    if (m_fileFd < 0) {
        m_storageError = "open failed: "
            + HistoryStorage::sampleFilePath(m_config.dataDir, dateInt) + ": "
            + std::strerror(errno);
        LOG_ERROR("[HistoryRecorder] {}", m_storageError);
        return false;
    }
    m_fileDate = dateInt;

    // 重载当日已存样本分钟,用于重启/跨天后去重
    m_todayMinutes.clear();
    std::vector<HistoryRawSample> today;
    std::string loadError;
    if (HistoryStorage::loadDayFile(m_config.dataDir, dateInt, &today, &loadError)) {
        m_todayMinutes.reserve(today.size());
        for (const HistoryRawSample& sample : today) {
            tm localTime;
            time_t t = static_cast<time_t>(sample.epochSec);
            localtime_r(&t, &localTime);
            m_todayMinutes.push_back(
                static_cast<uint16_t>(localTime.tm_hour * 60 + localTime.tm_min));
        }
    } else {
        LOG_WARNING("[HistoryRecorder] reload today failed: {}", loadError);
    }
    return true;
}

void HistoryRecorder::closeFileLocked()
{
    if (m_fileFd >= 0) {
        close(m_fileFd);
        m_fileFd = -1;
    }
}

nlohmann::json HistoryRecorder::getTrendData(const std::string& range,
    const std::string& dateParam) const
{
    nlohmann::json data;
    TrendWindow window;
    std::string windowError;
    if (!computeTrendWindow(range, dateParam,
            static_cast<int64_t>(::time(nullptr)), &window, &windowError)) {
        data["error"] = windowError;
        return data;
    }

    std::vector<HistoryRawSample> samples;
    std::string storageError;
    for (int date : window.involvedDates) {
        // loadDayFile 每次清空输出,用临时向量累积多日样本
        std::vector<HistoryRawSample> daySamples;
        std::string loadError;
        if (!HistoryStorage::loadDayFile(m_config.dataDir, date, &daySamples, &loadError)) {
            LOG_WARNING("[HistoryRecorder] load {} failed: {}", date, loadError);
            if (storageError.empty()) {
                storageError = loadError;
            }
            continue;
        }
        samples.insert(samples.end(), daySamples.begin(), daySamples.end());
    }

    const std::vector<HistoryBucketAggregate> buckets = aggregateBuckets(
        samples, window.startEpochSec, window.intervalSec, window.bucketCount);

    const int64_t windowEnd = window.startEpochSec
        + static_cast<int64_t>(window.bucketCount) * window.intervalSec;
    uint64_t inWindowSamples = 0;
    for (const HistoryRawSample& sample : samples) {
        if (sample.epochSec >= window.startEpochSec && sample.epochSec < windowEnd) {
            ++inWindowSamples;
        }
    }

    nlohmann::json timestamps = nlohmann::json::array();
    for (int i = 0; i < window.bucketCount; ++i) {
        timestamps.push_back(window.startEpochSec
            + static_cast<int64_t>(i) * window.intervalSec);
    }

    {
        std::lock_guard<std::mutex> guard(m_mutex);
        if (!m_storageError.empty() && storageError.empty()) {
            storageError = m_storageError;
        }
    }

    data["range"] = range;
    data["intervalSeconds"] = window.intervalSec;
    data["anchorDate"] = window.anchorDate;
    data["timestamps"] = timestamps;
    data["indoor"] = {
        {"temperature", seriesToJson(buckets, SERIES_RA_TEMPERATURE, true)},
        {"humidity", seriesToJson(buckets, SERIES_RA_HUMIDITY, false)},
        {"pm25", seriesToJson(buckets, SERIES_RA_PM25, false)},
        {"co2", seriesToJson(buckets, SERIES_RA_CO2, false)},
    };
    data["outdoor"] = {
        {"temperature", seriesToJson(buckets, SERIES_OA_TEMPERATURE, true)},
        {"humidity", seriesToJson(buckets, SERIES_OA_HUMIDITY, false)},
        {"pm25", seriesToJson(buckets, SERIES_OA_PM25, false)},
        {"co2", seriesToJson(buckets, SERIES_OA_CO2, false)},
    };
    data["sampleCount"] = inWindowSamples;
    data["storageError"] = storageError.empty()
        ? nlohmann::json(nullptr)
        : nlohmann::json(storageError);
    return data;
}

nlohmann::json HistoryRecorder::getStatusData() const
{
    const HistoryStorage::DirectoryStats stats =
        HistoryStorage::scanDirectory(m_config.dataDir);

    std::string storageError;
    int64_t lastSampleEpoch = 0;
    {
        std::lock_guard<std::mutex> guard(m_mutex);
        storageError = m_storageError;
        lastSampleEpoch = m_lastSampleEpoch;
    }

    nlohmann::json data;
    data["enabled"] = m_config.enabled;
    data["dataDir"] = m_config.dataDir;
    data["sampleIntervalSec"] = m_config.sampleIntervalSec;
    data["retentionDays"] = m_config.retentionDays;
    data["totalSamples"] = stats.totalSamples;
    data["oldestDate"] = stats.oldestDate != 0
        ? nlohmann::json(stats.oldestDate)
        : nlohmann::json(nullptr);
    data["newestDate"] = stats.newestDate != 0
        ? nlohmann::json(stats.newestDate)
        : nlohmann::json(nullptr);
    data["lastSampleTime"] = lastSampleEpoch != 0
        ? nlohmann::json(formatDateTime(lastSampleEpoch))
        : nlohmann::json(nullptr);
    data["storageBytes"] = stats.totalBytes;
    data["storageError"] = storageError.empty()
        ? nlohmann::json(nullptr)
        : nlohmann::json(storageError);
    return data;
}
