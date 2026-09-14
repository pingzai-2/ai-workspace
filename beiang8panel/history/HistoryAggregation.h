/**
 * HistoryAggregation - 历史趋势纯计算(无 IO、无 DataManager 依赖,可单测)
 *
 * 职责:
 * 1. 定义存储记录与序列枚举(协议 v1.22 输入寄存器 200DH-2014H)
 * 2. 桶窗口计算: day/week/month 三种视图的桶起点/间隔/数量
 * 3. 样本有效性过滤(协议量程)与分桶均值
 *
 * 时间语义: 桶边界按面板本地时间(自然日/整 2 小时), epoch 为 UTC 秒,
 * 由调用方本地化格式化。全部函数不修改全局状态。
 */

#ifndef HISTORYAGGREGATION_H
#define HISTORYAGGREGATION_H

#include <cstdint>
#include <string>
#include <vector>

// 8 个采样序列,顺序与 200DH-2014H 寄存器一一对应
enum HistorySeries {
    SERIES_RA_TEMPERATURE = 0,  // 200DH 室内温度 ×10 (int16)
    SERIES_RA_HUMIDITY,         // 200EH 室内湿度 %RH (uint16)
    SERIES_RA_PM25,             // 200FH 室内 PM2.5 µg/m³ (uint16)
    SERIES_RA_CO2,              // 2010H 室内 CO2 ppm (uint16)
    SERIES_OA_TEMPERATURE,      // 2011H 室外温度 ×10 (int16)
    SERIES_OA_HUMIDITY,         // 2012H 室外湿度 %RH (uint16)
    SERIES_OA_PM25,             // 2013H 室外 PM2.5 µg/m³ (uint16)
    SERIES_OA_CO2,              // 2014H 室外 CO2 ppm (uint16)
    SERIES_COUNT
};

// 落盘样本记录,18 字节(9×2B),小端,全部存协议原始值
#pragma pack(push, 1)
struct HistorySampleRecord {
    uint16_t minuteOfDay;        // 当日本地时间分钟数 0..1439(去重键)
    int16_t  raTemperatureX10;   // 200DH 原值
    uint16_t raHumidity;         // 200EH 原值
    uint16_t raPm25;             // 200FH 原值
    uint16_t raCo2;              // 2010H 原值
    int16_t  oaTemperatureX10;   // 2011H 原值
    uint16_t oaHumidity;         // 2012H 原值
    uint16_t oaPm25;             // 2013H 原值
    uint16_t oaCo2;              // 2014H 原值
};
#pragma pack(pop)
static_assert(sizeof(HistorySampleRecord) == 18, "history sample record must be 18 bytes");

// 聚合输入样本: 记录 + 换算后的 epoch(本地日期 + minuteOfDay → UTC 秒)
struct HistoryRawSample {
    int64_t epochSec;
    int32_t raw[SERIES_COUNT];
};

// 单序列值是否在协议有效量程内(超出视为传感器异常,聚合时剔除)
bool isSeriesValueValid(int series, int32_t rawValue);

// 分桶聚合: 桶 i 覆盖 [startEpochSec + i*intervalSec, +(i+1)*intervalSec),
// 样本按 epoch 落桶,无效值仅从对应序列均值中剔除。
struct HistoryBucketAggregate {
    double sum[SERIES_COUNT] = {0.0};
    int32_t count[SERIES_COUNT] = {0};
};
std::vector<HistoryBucketAggregate> aggregateBuckets(
    const std::vector<HistoryRawSample>& samples,
    int64_t startEpochSec, int intervalSec, int bucketCount);

// ========== 日期/时间辅助(本地时区) ==========

// time_t → 本地日期整数,如 20260904
int localDateInt(int64_t epochSec);
// time_t → 本地日期字符串 "YYYY-MM-DD"
std::string localDateString(int64_t epochSec);
// 本地日期当日 00:00 的 epoch 秒
int64_t localStartOfDayEpoch(int64_t epochSec);
// 本地日期 + minuteOfDay → epoch 秒
int64_t epochOfLocalMinute(int dateInt, uint16_t minuteOfDay);
// 严格校验 "YYYY-MM-DD"(含闰年与每月天数),合法则 outStartOfDay 为当日 00:00
bool parseDateString(const std::string& text, int64_t* outStartOfDay);
// parseDateString 的便捷谓词
bool isValidDateString(const std::string& text);
// dateInt 加减天数(mktime 归一化,支持跨月/跨年)
int dateIntAddDays(int dateInt, int days);

// ========== 桶窗口计算 ==========

struct TrendWindow {
    int64_t startEpochSec = 0;   // 首桶起点
    int intervalSec = 0;         // 桶间隔(秒)
    int bucketCount = 0;         // 桶数量
    std::string anchorDate;      // "YYYY-MM-DD" 锚点日
    std::vector<int> involvedDates; // 窗口覆盖的自然日(YYYYMMDD,升序去重),调用方按此读天文件
};

// 计算 range 视图的桶窗口:
//   day(锚点=今天)   : 最近整 2 小时为末桶起点的滚动 24h,12 桶 ×2h(末桶进行中)
//   day(锚点=历史日) : 该自然日 00:00 起 12 桶 ×2h
//   week             : 锚点日与其前 6 个自然日,7 桶 ×1d
//   month            : 锚点所在月 1 号至锚点日,锚点日号数个桶 ×1d
// range 非法或 date 格式非法返回 false 并写 *error。
bool computeTrendWindow(const std::string& range, const std::string& dateParam,
    int64_t nowEpochSec, TrendWindow* outWindow, std::string* error);

#endif // HISTORYAGGREGATION_H
