/**
 * 全局函数声明
 */

#ifndef GLOBALFUNCTION_H
#define GLOBALFUNCTION_H

#include "GlobalDefine.h"
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

// 字符串工具
namespace StringUtils {
// 字符串分割
std::vector<std::string> split(const std::string& str, char delimiter);

// 字符串连接
std::string join(const std::vector<std::string>& strs, const std::string& delimiter);

// 去除首尾空白
std::string trim(const std::string& str);

// 转换为大写
std::string toUpper(const std::string& str);

// 转换为小写
std::string toLower(const std::string& str);

// 判断是否包含子串
bool contains(const std::string& str, const std::string& sub);

// 字符串替换
std::string replace(const std::string& str, const std::string& from, const std::string& to);

// 格式化字符串
std::string format(const char* fmt, ...);
}

// 时间工具
namespace TimeUtils {
// 获取当前时间戳（毫秒）
int64_t getCurrentTimestampMs();

// 获取当前时间戳（秒）
int64_t getCurrentTimestampSec();

// 时间戳转字符串
std::string timestampToString(int64_t timestamp, const std::string& format = "%Y-%m-%d %H:%M:%S");

// 字符串转时间戳
int64_t stringToTimestamp(const std::string& timeStr, const std::string& format = "%Y-%m-%d %H:%M:%S");

// 获取当前日期字符串
std::string getCurrentDate(const std::string& format = "%Y-%m-%d");

// 获取当前时间字符串
std::string getCurrentTime(const std::string& format = "%H:%M:%S");
}

// 数值转换工具
namespace ConvertUtils {
// 字符串转整数
int stringToInt(const std::string& str, int defaultValue = 0);

// 字符串转长整数
long stringToLong(const std::string& str, long defaultValue = 0);

// 字符串转浮点数
double stringToDouble(const std::string& str, double defaultValue = 0.0);

// 整数转字符串
std::string intToString(int value);

// 浮点数转字符串
std::string doubleToString(double value, int precision = 2);

// 十六进制字符串转整数
int hexStringToInt(const std::string& hexStr);

// 整数转十六进制字符串
std::string intToHexString(int value, int width = 2);

// 字节数组转十六进制字符串
std::string bytesToHexString(const uint8_t* data, size_t length);

// 十六进制字符串转字节数组
std::vector<uint8_t> hexStringToBytes(const std::string& hexStr);
}

// 文件工具
namespace FileUtils {
// 判断文件是否存在
bool fileExists(const std::string& path);

// 判断目录是否存在
bool directoryExists(const std::string& path);

// 创建目录
bool createDirectory(const std::string& path);

// 递归创建目录
bool createDirectories(const std::string& path);

// 删除文件
bool removeFile(const std::string& path);

// 获取文件大小
size_t getFileSize(const std::string& path);

// 读取文件内容
std::string readFile(const std::string& path);

// 写入文件内容
bool writeFile(const std::string& path, const std::string& content);
}

// 日志工具
namespace LogUtils {
// 记录日志
void log(LogLevel level, const std::string& message);

// 格式化日志
std::string formatLog(LogLevel level, const std::string& message);

// 获取日志级别名称
std::string getLevelName(LogLevel level);
}

#endif // GLOBALFUNCTION_H
