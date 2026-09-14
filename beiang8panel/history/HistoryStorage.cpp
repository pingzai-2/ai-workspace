/**
 * HistoryStorage 实现
 */

#include "HistoryStorage.h"

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <fstream>
#include <sstream>

namespace {

constexpr char kMagic[4] = {'B', '8', 'P', 'H'};

int syncFileData(int fd)
{
#if defined(__APPLE__)
    // macOS 没有 fdatasync；fsync 提供同等的落盘保障。
    return ::fsync(fd);
#elif defined(__linux__)
    // book Ubuntu 与 R818 嵌入式 Linux 均走这里。
    return ::fdatasync(fd);
#else
    // 其它 POSIX 平台没有 fdatasync 时使用通用同步接口。
    return ::fsync(fd);
#endif
}

#pragma pack(push, 1)
struct FileHeader {
    char magic[4];
    uint16_t version;
    uint16_t recordSize;
    uint32_t date;   // YYYYMMDD
    uint32_t reserved;
};
#pragma pack(pop)
static_assert(sizeof(FileHeader) == HistoryStorage::HEADER_SIZE,
    "history file header must be 16 bytes");

std::string fileNameOfDate(int dateInt)
{
    char buf[32];
    std::snprintf(buf, sizeof(buf), "samples-%08d.bin", dateInt);
    return std::string(buf);
}

// 文件名 → 日期;不匹配样本文件命名返回 false
bool parseFileName(const std::string& name, int* outDate)
{
    const std::string prefix = "samples-";
    const std::string suffix = ".bin";
    if (name.size() != prefix.size() + 8 + suffix.size()
        || name.compare(0, prefix.size(), prefix) != 0
        || name.compare(name.size() - suffix.size(), suffix.size(), suffix) != 0) {
        return false;
    }
    for (size_t i = prefix.size(); i < prefix.size() + 8; ++i) {
        if (name[i] < '0' || name[i] > '9') {
            return false;
        }
    }
    *outDate = std::atoi(name.substr(prefix.size(), 8).c_str());
    return true;
}

} // namespace

namespace HistoryStorage {

std::string sampleFilePath(const std::string& dataDir, int dateInt)
{
    std::string path = dataDir;
    if (!path.empty() && path.back() != '/') {
        path += '/';
    }
    return path + fileNameOfDate(dateInt);
}

bool ensureDirectory(const std::string& path)
{
    if (path.empty()) {
        return false;
    }
    std::string current;
    for (size_t i = 0; i < path.size(); ++i) {
        current += path[i];
        if (path[i] == '/' && i > 0) {
            if (mkdir(current.c_str(), 0755) != 0 && errno != EEXIST) {
                return false;
            }
        }
    }
    if (mkdir(current.c_str(), 0755) != 0 && errno != EEXIST) {
        return false;
    }
    struct stat st;
    return stat(current.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

int openAppendFile(const std::string& dataDir, int dateInt)
{
    const std::string path = sampleFilePath(dataDir, dateInt);
    const int fd = open(path.c_str(), O_RDWR | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        return -1;
    }

    struct stat st;
    if (fstat(fd, &st) != 0) {
        close(fd);
        return -1;
    }

    if (st.st_size == 0) {
        FileHeader header;
        std::memcpy(header.magic, kMagic, sizeof(kMagic));
        header.version = FILE_VERSION;
        header.recordSize = static_cast<uint16_t>(RECORD_SIZE);
        header.date = static_cast<uint32_t>(dateInt);
        header.reserved = 0;
        if (write(fd, &header, sizeof(header)) != static_cast<ssize_t>(sizeof(header))) {
            close(fd);
            return -1;
        }
        if (syncFileData(fd) != 0) {
            close(fd);
            return -1;
        }
        return fd;
    }

    FileHeader header;
    if (st.st_size < static_cast<off_t>(sizeof(header))
        || pread(fd, &header, sizeof(header), 0) != static_cast<ssize_t>(sizeof(header))
        || std::memcmp(header.magic, kMagic, sizeof(kMagic)) != 0
        || header.version != FILE_VERSION
        || header.recordSize != RECORD_SIZE
        || header.date != static_cast<uint32_t>(dateInt)) {
        close(fd);
        return -1;
    }

    // 断电可能留下撕裂的尾记录: 截断到最近完整记录
    const off_t bodySize = st.st_size - static_cast<off_t>(sizeof(header));
    const off_t fullBytes = (bodySize / static_cast<off_t>(RECORD_SIZE))
        * static_cast<off_t>(RECORD_SIZE);
    if (bodySize != fullBytes
        && ftruncate(fd, static_cast<off_t>(sizeof(header)) + fullBytes) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

bool appendSample(int fd, const HistorySampleRecord& record)
{
    if (fd < 0) {
        return false;
    }
    if (write(fd, &record, RECORD_SIZE) != static_cast<ssize_t>(RECORD_SIZE)) {
        return false;
    }
    return syncFileData(fd) == 0;
}

bool loadDayFile(const std::string& dataDir, int dateInt,
    std::vector<HistoryRawSample>* out, std::string* error)
{
    if (out) {
        out->clear();
    }
    const std::string path = sampleFilePath(dataDir, dateInt);
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        // 不存在/暂时不可读: 视为当日无数据,由 errno 区分
        if (errno == ENOENT) {
            return true;
        }
        if (error) {
            *error = "open failed: " + path + ": " + std::strerror(errno);
        }
        return false;
    }
    const std::streamoff fileSize = file.tellg();
    if (fileSize < static_cast<std::streamoff>(HEADER_SIZE)) {
        if (error) {
            *error = "file too small: " + path;
        }
        return false;
    }
    file.seekg(0);
    FileHeader header;
    file.read(reinterpret_cast<char*>(&header), sizeof(header));
    if (!file
        || std::memcmp(header.magic, kMagic, sizeof(kMagic)) != 0
        || header.version != FILE_VERSION
        || header.recordSize != RECORD_SIZE) {
        if (error) {
            *error = "bad header: " + path;
        }
        return false;
    }

    const size_t fullRecords =
        (static_cast<size_t>(fileSize) - HEADER_SIZE) / RECORD_SIZE;
    if (out) {
        out->reserve(fullRecords);
    }
    HistorySampleRecord record;
    for (size_t i = 0; i < fullRecords; ++i) {
        file.read(reinterpret_cast<char*>(&record), RECORD_SIZE);
        if (!file) {
            if (error) {
                *error = "read failed at record " + std::to_string(i) + ": " + path;
            }
            return false;
        }
        HistoryRawSample sample;
        sample.epochSec = epochOfLocalMinute(dateInt, record.minuteOfDay);
        sample.raw[SERIES_RA_TEMPERATURE] = record.raTemperatureX10;
        sample.raw[SERIES_RA_HUMIDITY] = record.raHumidity;
        sample.raw[SERIES_RA_PM25] = record.raPm25;
        sample.raw[SERIES_RA_CO2] = record.raCo2;
        sample.raw[SERIES_OA_TEMPERATURE] = record.oaTemperatureX10;
        sample.raw[SERIES_OA_HUMIDITY] = record.oaHumidity;
        sample.raw[SERIES_OA_PM25] = record.oaPm25;
        sample.raw[SERIES_OA_CO2] = record.oaCo2;
        if (out) {
            out->push_back(sample);
        }
    }
    return true;
}

int pruneOldFiles(const std::string& dataDir, int cutoffDateInt)
{
    DIR* dir = opendir(dataDir.c_str());
    if (!dir) {
        return -1;
    }
    int removed = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        int date = 0;
        if (!parseFileName(entry->d_name, &date)) {
            continue;
        }
        if (date >= cutoffDateInt) {
            continue;
        }
        const std::string path = sampleFilePath(dataDir, date);
        if (unlink(path.c_str()) == 0) {
            ++removed;
        }
    }
    closedir(dir);
    return removed;
}

DirectoryStats scanDirectory(const std::string& dataDir)
{
    DirectoryStats stats;
    DIR* dir = opendir(dataDir.c_str());
    if (!dir) {
        return stats;
    }
    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        int date = 0;
        if (!parseFileName(entry->d_name, &date)) {
            continue;
        }
        struct stat st;
        if (stat(sampleFilePath(dataDir, date).c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
            continue;
        }
        ++stats.fileCount;
        stats.totalBytes += static_cast<uint64_t>(st.st_size);
        if (st.st_size > static_cast<off_t>(HEADER_SIZE)) {
            stats.totalSamples +=
                (static_cast<uint64_t>(st.st_size) - HEADER_SIZE) / RECORD_SIZE;
        }
        if (stats.oldestDate == 0 || date < stats.oldestDate) {
            stats.oldestDate = date;
        }
        if (date > stats.newestDate) {
            stats.newestDate = date;
        }
    }
    closedir(dir);
    return stats;
}

} // namespace HistoryStorage
