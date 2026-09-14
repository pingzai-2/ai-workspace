/**
 * HistoryStorage - 历史样本日文件存取(无 DataManager 依赖,可单测)
 *
 * 文件布局: <dataDir>/samples-YYYYMMDD.bin
 *   16B 文件头 + N × 20B 定长记录(小端,追加写)
 * 断电安全: 打开写入句柄时把尾部撕裂记录截断到最近完整记录;
 *           读取侧遇到撕裂尾同样只取完整记录。
 */

#ifndef HISTORYSTORAGE_H
#define HISTORYSTORAGE_H

#include "HistoryAggregation.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace HistoryStorage {

constexpr uint16_t FILE_VERSION = 1;
constexpr size_t HEADER_SIZE = 16;
constexpr size_t RECORD_SIZE = sizeof(HistorySampleRecord);

// dataDir + 日期 → 文件路径
std::string sampleFilePath(const std::string& dataDir, int dateInt);

// 递归创建目录(已存在视为成功)
bool ensureDirectory(const std::string& path);

// 打开(必要时创建)某日的追加写句柄。
// - 空文件: 写入文件头
// - 尾部撕裂: 截断到最近完整记录
// - 头校验失败(非本格式/日期不符): 返回 -1
// 调用方负责 close(fd)。
int openAppendFile(const std::string& dataDir, int dateInt);

// 追加一条记录并 fdatasync 落盘
bool appendSample(int fd, const HistorySampleRecord& record);

// 读取某日文件为带 epoch 的样本列表。
// 文件不存在: 返回 true 且 out 为空(无数据≠错误)。
// 文件头非法: 返回 false(损坏,调用方记日志)。
bool loadDayFile(const std::string& dataDir, int dateInt,
    std::vector<HistoryRawSample>* out, std::string* error = nullptr);

// 删除保留期外的日文件(cutoff 之前的日期),返回删除数量
int pruneOldFiles(const std::string& dataDir, int cutoffDateInt);

// 目录统计(/api/history/status 用)
struct DirectoryStats {
    size_t fileCount = 0;
    uint64_t totalSamples = 0;
    uint64_t totalBytes = 0;
    int oldestDate = 0;  // 0=无文件
    int newestDate = 0;
};
DirectoryStats scanDirectory(const std::string& dataDir);

} // namespace HistoryStorage

#endif // HISTORYSTORAGE_H
