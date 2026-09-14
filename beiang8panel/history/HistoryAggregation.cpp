/**
 * HistoryAggregation 实现
 */

#include "HistoryAggregation.h"

#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <ctime>

namespace {

tm localTmOf(int64_t epochSec)
{
    time_t t = static_cast<time_t>(epochSec);
    tm out;
    localtime_r(&t, &out);
    return out;
}

time_t mktimeLocal(tm value)
{
    return mktime(&value);
}

int dateIntFromTm(const tm& value)
{
    return (value.tm_year + 1900) * 10000
        + (value.tm_mon + 1) * 100
        + value.tm_mday;
}

tm startOfDayTm(int64_t epochSec)
{
    tm value = localTmOf(epochSec);
    value.tm_hour = 0;
    value.tm_min = 0;
    value.tm_sec = 0;
    return value;
}

// 协议量程: 温度 ±60.0℃(原值±600), 湿度 0-100, PM2.5 0-999, CO2 0-9999
bool seriesInProtocolRange(int series, int32_t v)
{
    switch (series) {
    case SERIES_RA_TEMPERATURE:
    case SERIES_OA_TEMPERATURE:
        return v >= -600 && v <= 600;
    case SERIES_RA_HUMIDITY:
    case SERIES_OA_HUMIDITY:
        return v >= 0 && v <= 100;
    case SERIES_RA_PM25:
    case SERIES_OA_PM25:
        return v >= 0 && v <= 999;
    case SERIES_RA_CO2:
    case SERIES_OA_CO2:
        return v >= 0 && v <= 9999;
    default:
        return false;
    }
}

int daysInMonth(int year, int month)
{
    static const int table[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if (month < 1 || month > 12) {
        return 0;
    }
    if (month == 2
        && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
        return 29;
    }
    return table[month - 1];
}

} // namespace

bool isSeriesValueValid(int series, int32_t rawValue)
{
    return seriesInProtocolRange(series, rawValue);
}

std::vector<HistoryBucketAggregate> aggregateBuckets(
    const std::vector<HistoryRawSample>& samples,
    int64_t startEpochSec, int intervalSec, int bucketCount)
{
    std::vector<HistoryBucketAggregate> buckets(
        bucketCount > 0 ? static_cast<size_t>(bucketCount) : 0);
    if (intervalSec <= 0 || bucketCount <= 0) {
        return buckets;
    }
    for (const HistoryRawSample& sample : samples) {
        const int64_t offset = sample.epochSec - startEpochSec;
        if (offset < 0) {
            continue;
        }
        const int64_t index = offset / intervalSec;
        if (index >= static_cast<int64_t>(buckets.size())) {
            continue;
        }
        HistoryBucketAggregate& bucket = buckets[static_cast<size_t>(index)];
        for (int series = 0; series < SERIES_COUNT; ++series) {
            if (seriesInProtocolRange(series, sample.raw[series])) {
                bucket.sum[series] += sample.raw[series];
                bucket.count[series] += 1;
            }
        }
    }
    return buckets;
}

int localDateInt(int64_t epochSec)
{
    return dateIntFromTm(localTmOf(epochSec));
}

std::string localDateString(int64_t epochSec)
{
    char buf[16];
    tm value = localTmOf(epochSec);
    strftime(buf, sizeof(buf), "%Y-%m-%d", &value);
    return std::string(buf);
}

int64_t localStartOfDayEpoch(int64_t epochSec)
{
    tm value = startOfDayTm(epochSec);
    return static_cast<int64_t>(mktimeLocal(value));
}

int64_t epochOfLocalMinute(int dateInt, uint16_t minuteOfDay)
{
    tm value = {};
    value.tm_year = dateInt / 10000 - 1900;
    value.tm_mon = (dateInt / 100) % 100 - 1;
    value.tm_mday = dateInt % 100;
    value.tm_hour = minuteOfDay / 60;
    value.tm_min = minuteOfDay % 60;
    value.tm_sec = 0;
    value.tm_isdst = -1;
    return static_cast<int64_t>(mktimeLocal(value));
}

bool parseDateString(const std::string& text, int64_t* outStartOfDay)
{
    if (text.size() != 10 || text[4] != '-' || text[7] != '-') {
        return false;
    }
    for (size_t i = 0; i < text.size(); ++i) {
        if (i == 4 || i == 7) {
            continue;
        }
        if (text[i] < '0' || text[i] > '9') {
            return false;
        }
    }
    const int year = std::atoi(text.substr(0, 4).c_str());
    const int month = std::atoi(text.substr(5, 2).c_str());
    const int day = std::atoi(text.substr(8, 2).c_str());
    if (year < 1970 || month < 1 || month > 12) {
        return false;
    }
    if (day < 1 || day > daysInMonth(year, month)) {
        return false;
    }
    if (outStartOfDay) {
        *outStartOfDay = epochOfLocalMinute(year * 10000 + month * 100 + day, 0);
    }
    return true;
}

bool isValidDateString(const std::string& text)
{
    return parseDateString(text, nullptr);
}

int dateIntAddDays(int dateInt, int days)
{
    tm value = {};
    value.tm_year = dateInt / 10000 - 1900;
    value.tm_mon = (dateInt / 100) % 100 - 1;
    value.tm_mday = dateInt % 100;
    value.tm_hour = 12; // 取正午避免本地时制下的日期漂移
    value.tm_isdst = -1;
    value.tm_mday += days;
    const time_t normalized = mktimeLocal(value);
    if (normalized == static_cast<time_t>(-1)) {
        return dateInt;
    }
    tm out;
    localtime_r(&normalized, &out);
    return dateIntFromTm(out);
}

bool computeTrendWindow(const std::string& range, const std::string& dateParam,
    int64_t nowEpochSec, TrendWindow* outWindow, std::string* error)
{
    if (range != "day" && range != "week" && range != "month") {
        if (error) {
            *error = "range 必须为 day/week/month";
        }
        return false;
    }

    int64_t anchorStart = 0;
    std::string anchorStr;
    if (dateParam.empty()) {
        anchorStart = localStartOfDayEpoch(nowEpochSec);
        anchorStr = localDateString(nowEpochSec);
    } else {
        if (!parseDateString(dateParam, &anchorStart)) {
            if (error) {
                *error = "date 参数格式必须为 YYYY-MM-DD";
            }
            return false;
        }
        anchorStr = dateParam;
    }

    TrendWindow window;
    window.anchorDate = anchorStr;

    if (range == "day") {
        window.intervalSec = 7200;
        window.bucketCount = 12;
        if (anchorStr == localDateString(nowEpochSec)) {
            // 滚动 24h: 最近一个整 2 小时为末桶(第 12 桶,序号 11)起点(进行中桶)
            tm value = localTmOf(nowEpochSec);
            value.tm_min = 0;
            value.tm_sec = 0;
            value.tm_hour &= ~1;
            const int64_t lastEvenHour = static_cast<int64_t>(mktimeLocal(value));
            window.startEpochSec = lastEvenHour - 11LL * 7200;
        } else {
            // 历史日: 该自然日 00:00 起 12 桶
            window.startEpochSec = anchorStart;
        }
    } else if (range == "week") {
        // 锚点日与其前 6 个自然日
        window.intervalSec = 86400;
        window.bucketCount = 7;
        window.startEpochSec = anchorStart - 6LL * 86400;
    } else {
        // 锚点所在月 1 号至锚点日,每桶一个自然日
        tm value = localTmOf(anchorStart);
        const int dayOfMonth = value.tm_mday;
        value.tm_mday = 1;
        value.tm_hour = 0;
        value.tm_min = 0;
        value.tm_sec = 0;
        value.tm_isdst = -1;
        window.startEpochSec = static_cast<int64_t>(mktimeLocal(value));
        window.intervalSec = 86400;
        window.bucketCount = dayOfMonth;
    }

    // 窗口覆盖的自然日(读天文件用):按自然日枚举,避免固定步进漏掉末尾部分日
    const int64_t windowEnd = window.startEpochSec
        + static_cast<int64_t>(window.bucketCount) * window.intervalSec;
    int date = localDateInt(window.startEpochSec);
    const int lastDate = localDateInt(windowEnd - 1);
    while (date <= lastDate) {
        window.involvedDates.push_back(date);
        date = dateIntAddDays(date, 1);
    }

    if (outWindow) {
        *outWindow = window;
    }
    return true;
}
