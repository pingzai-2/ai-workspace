/**
 * HistoryRecorder - 历史趋势采样与查询模块
 *
 * 独立线程按对齐间隔从 DataManager 寄存器缓存采样室内/外温湿/PM2.5/CO₂
 * (输入寄存器 200DH-2014H,只读缓存、不碰串口),追加写入 UDISK 日文件;
 * HTTP 查询时读天文件现算 day/week/month 桶序列。
 *
 * 设计文档: docs/历史趋势数据存储与接口设计.md
 */

#ifndef HISTORYRECORDER_H
#define HISTORYRECORDER_H

#include "HistoryAggregation.h"

#include <nlohmann/json.hpp>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class DataManager;

class HistoryRecorder {
public:
    struct Config {
        bool enabled = true;
        std::string dataDir = "/mnt/UDISK/beiang8panel/history";
        int sampleIntervalSec = 600;   // 对齐墙钟的采样间隔(60..86400)
        int retentionDays = 370;       // 日文件保留天数(含当天)
    };

    HistoryRecorder(DataManager* dataManager, const Config& config);
    ~HistoryRecorder();

    HistoryRecorder(const HistoryRecorder&) = delete;
    HistoryRecorder& operator=(const HistoryRecorder&) = delete;

    // 启动采样线程;stop 可重复调用。enabled=false 时启动为空转(不采样)。
    bool start();
    void stop();
    bool isRunning() const { return m_running.load(); }

    // GET /api/history/trend 的 data 对象。range: day/week/month,
    // dateParam: 可选 "YYYY-MM-DD" 锚点(空=今天)。入参已由 HTTP 层校验,
    // 此处再防御: 非法时返回 {"error": "..."}。
    nlohmann::json getTrendData(const std::string& range,
        const std::string& dateParam) const;

    // GET /api/history/status 的 data 对象
    nlohmann::json getStatusData() const;

private:
    void samplingLoop();
    // 采样一步: 读缓存→落盘。at 为对齐边界的标称时间。
    void appendSampleAtTime(int64_t atEpochSec);
    // 确保当天文件句柄可用(跨天切换/启动/存储故障自愈),调用方持 m_mutex
    bool ensureOpenForDate(int dateInt);
    void closeFileLocked();

    DataManager* m_dataManager;
    Config m_config;

    std::atomic<bool> m_running{false};
    std::thread m_thread;
    std::mutex m_stopMutex;
    std::condition_variable m_stopCv;

    // 保护文件句柄/当日去重表/统计/存储错误
    mutable std::mutex m_mutex;
    int m_fileFd = -1;
    int m_fileDate = 0;                 // 当天文件日期 YYYYMMDD
    std::vector<uint16_t> m_todayMinutes; // 当日已采样分钟(去重,含重启重载)
    uint64_t m_totalSamples = 0;        // 本次运行追加样本数
    int64_t m_lastSampleEpoch = 0;
    mutable std::string m_storageError;
};

#endif // HISTORYRECORDER_H
