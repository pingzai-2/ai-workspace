/**
 * HistoryAggregation/HistoryStorage 单元测试(纯函数+文件IO,无 DataManager 依赖)
 *
 * 本地运行:
 *   g++ -std=c++14 tests/HistoryAggregationTest.cpp \
 *       history/HistoryAggregation.cpp history/HistoryStorage.cpp \
 *       -I . -o /tmp/histtest && /tmp/histtest
 *
 * 时间相关断言全部经 epochOfLocalMinute 推导期望值,与时区无关。
 */

#include "history/HistoryAggregation.h"
#include "history/HistoryStorage.h"

#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            std::cerr << "  FAIL " << __func__ << ":" << __LINE__ << ": " #cond << std::endl; \
            ++g_failures; \
            return false; \
        } \
    } while (0)

bool testSeriesValueValid()
{
    CHECK(isSeriesValueValid(SERIES_RA_TEMPERATURE, 600));
    CHECK(isSeriesValueValid(SERIES_RA_TEMPERATURE, -600));
    CHECK(!isSeriesValueValid(SERIES_OA_TEMPERATURE, 601));
    CHECK(!isSeriesValueValid(SERIES_OA_TEMPERATURE, -601));
    CHECK(isSeriesValueValid(SERIES_RA_HUMIDITY, 0));
    CHECK(isSeriesValueValid(SERIES_RA_HUMIDITY, 100));
    CHECK(!isSeriesValueValid(SERIES_OA_HUMIDITY, 101));
    CHECK(isSeriesValueValid(SERIES_RA_PM25, 999));
    CHECK(!isSeriesValueValid(SERIES_OA_PM25, 1000));
    CHECK(isSeriesValueValid(SERIES_RA_CO2, 9999));
    CHECK(!isSeriesValueValid(SERIES_OA_CO2, 10000));
    return true;
}

bool testAggregateBuckets()
{
    const int64_t start = 1000000;
    const int interval = 7200;
    std::vector<HistoryRawSample> samples;

    // 桶0: 边界起点与桶内各一条;湿度越界一条
    HistoryRawSample s0;
    s0.epochSec = start;
    s0.raw[SERIES_RA_TEMPERATURE] = 245;
    s0.raw[SERIES_RA_HUMIDITY] = 55;
    samples.push_back(s0);
    HistoryRawSample s0b;
    s0b.epochSec = start + interval - 1;
    s0b.raw[SERIES_RA_TEMPERATURE] = 255;
    s0b.raw[SERIES_RA_HUMIDITY] = 150; // 越界,剔除
    samples.push_back(s0b);
    // 桶1
    HistoryRawSample s1;
    s1.epochSec = start + interval;
    s1.raw[SERIES_RA_TEMPERATURE] = -100;
    s1.raw[SERIES_RA_CO2] = 460;
    samples.push_back(s1);
    // 窗口前/后: 忽略
    HistoryRawSample before;
    before.epochSec = start - 1;
    before.raw[SERIES_RA_TEMPERATURE] = 999;
    samples.push_back(before);
    HistoryRawSample after;
    after.epochSec = start + 12LL * interval;
    after.raw[SERIES_RA_TEMPERATURE] = 999;
    samples.push_back(after);

    const std::vector<HistoryBucketAggregate> buckets =
        aggregateBuckets(samples, start, interval, 12);
    CHECK(buckets.size() == 12);
    CHECK(buckets[0].count[SERIES_RA_TEMPERATURE] == 2);
    CHECK(buckets[0].sum[SERIES_RA_TEMPERATURE] == 500.0); // 均值 250.0 → 25.0℃
    CHECK(buckets[0].count[SERIES_RA_HUMIDITY] == 1);
    CHECK(buckets[0].sum[SERIES_RA_HUMIDITY] == 55.0);
    CHECK(buckets[1].count[SERIES_RA_TEMPERATURE] == 1);
    CHECK(buckets[1].sum[SERIES_RA_TEMPERATURE] == -100.0);
    CHECK(buckets[1].count[SERIES_RA_CO2] == 1);
    CHECK(buckets[2].count[SERIES_RA_TEMPERATURE] == 0); // 空桶
    CHECK(buckets[11].count[SERIES_RA_TEMPERATURE] == 0);
    return true;
}

bool testParseDateString()
{
    int64_t startOfDay = 0;
    CHECK(isValidDateString("2026-09-04"));
    CHECK(isValidDateString("2024-02-29")); // 闰年
    CHECK(!isValidDateString("2023-02-29"));
    CHECK(!isValidDateString("2026-13-01"));
    CHECK(!isValidDateString("2026-00-10"));
    CHECK(!isValidDateString("2026-09-00"));
    CHECK(!isValidDateString("2026-09-31"));
    CHECK(!isValidDateString("2026-9-4"));
    CHECK(!isValidDateString("20260904"));
    CHECK(!isValidDateString(""));
    CHECK(parseDateString("2026-09-04", &startOfDay));
    CHECK(startOfDay == epochOfLocalMinute(20260904, 0));
    return true;
}

bool testDateIntAddDays()
{
    CHECK(dateIntAddDays(20260831, 1) == 20260901);
    CHECK(dateIntAddDays(20260101, -1) == 20251231);
    CHECK(dateIntAddDays(20240228, 1) == 20240229); // 闰年
    CHECK(dateIntAddDays(20250228, 1) == 20250301);
    CHECK(dateIntAddDays(20260904, 0) == 20260904);
    return true;
}

bool testWindowDayRolling()
{
    // 2026-09-04 08:30 请求 day: 末桶起点 08:00,首桶起点 = 前一天 10:00
    const int64_t now = epochOfLocalMinute(20260904, 8 * 60 + 30);
    TrendWindow window;
    std::string error;
    CHECK(computeTrendWindow("day", "", now, &window, &error));
    CHECK(window.intervalSec == 7200);
    CHECK(window.bucketCount == 12);
    CHECK(window.startEpochSec == epochOfLocalMinute(20260903, 10 * 60));
    CHECK(window.anchorDate == "2026-09-04");
    CHECK((window.involvedDates.size() == 2
        && window.involvedDates[0] == 20260903
        && window.involvedDates[1] == 20260904));
    // 末桶起点 = 最近整 2 小时
    CHECK(window.startEpochSec + 11LL * 7200
        == epochOfLocalMinute(20260904, 8 * 60));

    // 单数小时同样向下取整到偶数小时: 09:30 → 末桶 08:00
    const int64_t now2 = epochOfLocalMinute(20260904, 9 * 60 + 30);
    TrendWindow window2;
    CHECK(computeTrendWindow("day", "", now2, &window2, &error));
    CHECK(window2.startEpochSec + 11LL * 7200
        == epochOfLocalMinute(20260904, 8 * 60));

    // 00:30 当天: 末桶 00:00,首桶 = 前一天 02:00(00:00 回退 22h)
    const int64_t now3 = epochOfLocalMinute(20260904, 0 * 60 + 30);
    TrendWindow window3;
    CHECK(computeTrendWindow("day", "", now3, &window3, &error));
    CHECK(window3.startEpochSec + 11LL * 7200
        == epochOfLocalMinute(20260904, 0 * 60));
    CHECK(window3.startEpochSec == epochOfLocalMinute(20260903, 2 * 60));
    return true;
}

bool testWindowDayAnchored()
{
    // 锚点历史日: 该自然日 00:00 起 12 桶
    const int64_t now = epochOfLocalMinute(20260904, 8 * 60 + 30);
    TrendWindow window;
    std::string error;
    CHECK(computeTrendWindow("day", "2026-09-01", now, &window, &error));
    CHECK(window.intervalSec == 7200);
    CHECK(window.bucketCount == 12);
    CHECK(window.startEpochSec == epochOfLocalMinute(20260901, 0));
    CHECK(window.anchorDate == "2026-09-01");
    CHECK(window.involvedDates.size() == 1);
    CHECK(window.involvedDates[0] == 20260901);
    return true;
}

bool testWindowWeek()
{
    // 无锚点: 今天与前 6 个自然日
    const int64_t now = epochOfLocalMinute(20260904, 12 * 60);
    TrendWindow window;
    std::string error;
    CHECK(computeTrendWindow("week", "", now, &window, &error));
    CHECK(window.intervalSec == 86400);
    CHECK(window.bucketCount == 7);
    CHECK(window.startEpochSec == epochOfLocalMinute(20260829, 0));
    CHECK(window.involvedDates.size() == 7);
    CHECK(window.involvedDates.front() == 20260829);
    CHECK(window.involvedDates.back() == 20260904);
    // 指定锚点
    TrendWindow anchored;
    CHECK(computeTrendWindow("week", "2026-09-01", now, &anchored, &error));
    CHECK(anchored.startEpochSec == epochOfLocalMinute(20260826, 0));
    return true;
}

bool testWindowMonth()
{
    const int64_t now = epochOfLocalMinute(20260904, 12 * 60);
    TrendWindow window;
    std::string error;
    CHECK(computeTrendWindow("month", "", now, &window, &error));
    CHECK(window.intervalSec == 86400);
    CHECK(window.bucketCount == 4); // 当月 1 号至今天
    CHECK(window.startEpochSec == epochOfLocalMinute(20260901, 0));
    CHECK(window.involvedDates.size() == 4);
    // 锚点月中
    TrendWindow anchored;
    CHECK(computeTrendWindow("month", "2026-02-10", now, &anchored, &error));
    CHECK(anchored.bucketCount == 10);
    CHECK(anchored.startEpochSec == epochOfLocalMinute(20260201, 0));
    CHECK(anchored.anchorDate == "2026-02-10");
    // 非法入参
    std::string dummy;
    CHECK(!computeTrendWindow("hour", "", now, &window, &dummy));
    CHECK(!computeTrendWindow("day", "2026-02-30", now, &window, &dummy));
    return true;
}

class TempDir {
public:
    TempDir()
    {
        std::string tmpl = "/tmp/beiang_history_test_XXXXXX";
        std::vector<char> buf(tmpl.begin(), tmpl.end());
        buf.push_back('\0');
        char* dir = mkdtemp(buf.data());
        m_path = dir ? dir : "";
    }
    ~TempDir()
    {
        if (!m_path.empty()) {
            std::string cmd = "rm -rf " + m_path;
            std::system(cmd.c_str());
        }
    }
    const std::string& path() const { return m_path; }

private:
    std::string m_path;
};

HistorySampleRecord makeRecord(uint16_t minuteOfDay, int16_t raTempX10, uint16_t raHumidity,
    uint16_t raPm25, uint16_t raCo2, int16_t oaTempX10)
{
    HistorySampleRecord record = {};
    record.minuteOfDay = minuteOfDay;
    record.raTemperatureX10 = raTempX10;
    record.raHumidity = raHumidity;
    record.raPm25 = raPm25;
    record.raCo2 = raCo2;
    record.oaTemperatureX10 = oaTempX10;
    record.oaHumidity = 60;
    record.oaPm25 = 20;
    record.oaCo2 = 420;
    return record;
}

bool testStorageRoundTrip()
{
    TempDir tmp;
    CHECK(!tmp.path().empty());

    CHECK(HistoryStorage::ensureDirectory(tmp.path() + "/sub/dir"));
    CHECK(HistoryStorage::ensureDirectory(tmp.path())); // 已存在视为成功

    // 新文件 → 写头 → 追加 2 条 → 读回
    int fd = HistoryStorage::openAppendFile(tmp.path(), 20260904);
    CHECK(fd >= 0);
    CHECK(HistoryStorage::appendSample(fd, makeRecord(600, 245, 55, 8, 470, 312)));
    CHECK(HistoryStorage::appendSample(fd, makeRecord(610, 255, 57, 9, 480, 318)));
    close(fd);

    HistoryStorage::DirectoryStats stats = HistoryStorage::scanDirectory(tmp.path());
    CHECK(stats.fileCount == 1);
    CHECK(stats.totalSamples == 2);
    CHECK(stats.totalBytes == HistoryStorage::HEADER_SIZE + 2 * HistoryStorage::RECORD_SIZE);
    CHECK(stats.oldestDate == 20260904 && stats.newestDate == 20260904);

    std::vector<HistoryRawSample> samples;
    std::string error;
    CHECK(HistoryStorage::loadDayFile(tmp.path(), 20260904, &samples, &error));
    CHECK(samples.size() == 2);
    CHECK(samples[0].epochSec == epochOfLocalMinute(20260904, 600));
    CHECK(samples[0].raw[SERIES_RA_TEMPERATURE] == 245);
    CHECK(samples[0].raw[SERIES_RA_HUMIDITY] == 55);
    CHECK(samples[0].raw[SERIES_RA_PM25] == 8);
    CHECK(samples[0].raw[SERIES_RA_CO2] == 470);
    CHECK(samples[0].raw[SERIES_OA_TEMPERATURE] == 312);
    CHECK(samples[0].raw[SERIES_OA_HUMIDITY] == 60);
    CHECK(samples[0].raw[SERIES_OA_PM25] == 20);
    CHECK(samples[0].raw[SERIES_OA_CO2] == 420);
    CHECK(samples[1].raw[SERIES_RA_TEMPERATURE] == 255);

    // 不存在的日期 = 无数据而非错误
    std::vector<HistoryRawSample> empty;
    CHECK(HistoryStorage::loadDayFile(tmp.path(), 20250101, &empty, &error));
    CHECK(empty.empty());

    // 重复打开(重启场景)可继续追加,样本计数正确
    fd = HistoryStorage::openAppendFile(tmp.path(), 20260904);
    CHECK(fd >= 0);
    CHECK(HistoryStorage::appendSample(fd, makeRecord(620, 250, 56, 8, 475, 315)));
    close(fd);
    stats = HistoryStorage::scanDirectory(tmp.path());
    CHECK(stats.totalSamples == 3);
    return true;
}

bool testStorageTornTailAndHeader()
{
    TempDir tmp;
    CHECK(!tmp.path().empty());

    int fd = HistoryStorage::openAppendFile(tmp.path(), 20260904);
    CHECK(fd >= 0);
    CHECK(HistoryStorage::appendSample(fd, makeRecord(600, 245, 55, 8, 470, 312)));
    close(fd);

    // 模拟断电撕裂: 尾部追加 5 字节半条记录
    const std::string path = HistoryStorage::sampleFilePath(tmp.path(), 20260904);
    FILE* fp = std::fopen(path.c_str(), "ab");
    CHECK(fp != nullptr);
    const char torn[5] = {1, 2, 3, 4, 5};
    CHECK(std::fwrite(torn, 1, sizeof(torn), fp) == sizeof(torn));
    std::fclose(fp);

    // 读取侧只取完整记录
    std::vector<HistoryRawSample> samples;
    std::string error;
    CHECK(HistoryStorage::loadDayFile(tmp.path(), 20260904, &samples, &error));
    CHECK(samples.size() == 1);

    // 写侧重开: 截断撕裂尾,继续追加
    fd = HistoryStorage::openAppendFile(tmp.path(), 20260904);
    CHECK(fd >= 0);
    CHECK(HistoryStorage::appendSample(fd, makeRecord(700, 250, 56, 8, 475, 315)));
    close(fd);
    HistoryStorage::DirectoryStats stats = HistoryStorage::scanDirectory(tmp.path());
    CHECK(stats.totalSamples == 2);
    CHECK(stats.totalBytes == HistoryStorage::HEADER_SIZE + 2 * HistoryStorage::RECORD_SIZE);

    // 头校验失败: 破坏 magic 后打开与读取都拒绝
    fp = std::fopen(path.c_str(), "r+b");
    CHECK(fp != nullptr);
    const char bad[4] = {'X', 'X', 'X', 'X'};
    CHECK(std::fwrite(bad, 1, sizeof(bad), fp) == sizeof(bad));
    std::fclose(fp);
    CHECK(HistoryStorage::openAppendFile(tmp.path(), 20260904) < 0);
    CHECK(!HistoryStorage::loadDayFile(tmp.path(), 20260904, &samples, &error));

    // 文件名日期与头内日期不符: 把 20260904 的有效文件复制成 20260905 名字后拒绝
    const std::string source = HistoryStorage::sampleFilePath(tmp.path(), 20260904);
    const std::string other = HistoryStorage::sampleFilePath(tmp.path(), 20260905);
    std::string copyCmd = "cp " + source + " " + other;
    CHECK(std::system(copyCmd.c_str()) == 0);
    CHECK(HistoryStorage::openAppendFile(tmp.path(), 20260905) < 0);
    return true;
}

bool testStoragePrune()
{
    TempDir tmp;
    CHECK(!tmp.path().empty());

    for (int date : {20260101, 20260601, 20260903, 20260904}) {
        int fd = HistoryStorage::openAppendFile(tmp.path(), date);
        CHECK(fd >= 0);
        CHECK(HistoryStorage::appendSample(fd, makeRecord(0, 200, 50, 5, 400, 300)));
        close(fd);
    }
    // 保留 20260601 及之后
    const int removed = HistoryStorage::pruneOldFiles(tmp.path(), 20260601);
    CHECK(removed == 1);
    HistoryStorage::DirectoryStats stats = HistoryStorage::scanDirectory(tmp.path());
    CHECK(stats.fileCount == 3);
    CHECK(stats.oldestDate == 20260601);
    CHECK(stats.newestDate == 20260904);
    return true;
}

bool testEndToEndDayAggregation()
{
    TempDir tmp;
    CHECK(!tmp.path().empty());

    // 昨天 10:00-24:00 每小时一条 + 今天 00:00-08:00 每小时一条
    const int yesterday = 20260903;
    const int today = 20260904;
    int fdY = HistoryStorage::openAppendFile(tmp.path(), yesterday);
    CHECK(fdY >= 0);
    for (int hour = 10; hour < 24; ++hour) {
        CHECK(HistoryStorage::appendSample(
            fdY, makeRecord(hour * 60, 240 + hour, 50, 8, 460, 300)));
    }
    close(fdY);
    int fdT = HistoryStorage::openAppendFile(tmp.path(), today);
    CHECK(fdT >= 0);
    for (int hour = 0; hour < 9; ++hour) {
        CHECK(HistoryStorage::appendSample(
            fdT, makeRecord(hour * 60, 245 + hour, 52, 7, 455, 305)));
    }
    close(fdT);

    // 以 2026-09-04 09:00 为"现在"(末桶起点 08:00)
    const int64_t now = epochOfLocalMinute(today, 9 * 60);
    TrendWindow window;
    std::string error;
    CHECK(computeTrendWindow("day", "", now, &window, &error));
    CHECK(window.startEpochSec == epochOfLocalMinute(yesterday, 10 * 60));

    std::vector<HistoryRawSample> samples;
    for (int date : window.involvedDates) {
        // loadDayFile 每次清空输出,逐日累积
        std::vector<HistoryRawSample> daySamples;
        CHECK(HistoryStorage::loadDayFile(tmp.path(), date, &daySamples, &error));
        samples.insert(samples.end(), daySamples.begin(), daySamples.end());
    }
    CHECK(samples.size() == 23);

    const std::vector<HistoryBucketAggregate> buckets =
        aggregateBuckets(samples, window.startEpochSec, 7200, 12);
    CHECK(buckets[0].count[SERIES_RA_TEMPERATURE] == 2);   // 10:00 与 11:00
    CHECK(buckets[10].count[SERIES_RA_TEMPERATURE] == 2);  // 06:00 与 07:00
    // 末桶(序号 11, 08:00-10:00)进行中,只有 08:00 一条
    CHECK(buckets[11].count[SERIES_RA_TEMPERATURE] == 1);
    CHECK(buckets[0].sum[SERIES_RA_TEMPERATURE] == 240 + 10 + 240 + 11);
    CHECK(buckets[11].sum[SERIES_RA_TEMPERATURE] == 245 + 8);
    return true;
}

} // namespace

int main()
{
    const bool allPassed =
        testSeriesValueValid()
        && testAggregateBuckets()
        && testParseDateString()
        && testDateIntAddDays()
        && testWindowDayRolling()
        && testWindowDayAnchored()
        && testWindowWeek()
        && testWindowMonth()
        && testStorageRoundTrip()
        && testStorageTornTailAndHeader()
        && testStoragePrune()
        && testEndToEndDayAggregation();
    if (!allPassed || g_failures != 0) {
        std::cerr << "History aggregation tests failed (" << g_failures << " assertion(s))" << std::endl;
        return 1;
    }
    std::cout << "History aggregation tests passed" << std::endl;
    return 0;
}
