/**
 * 全局函数实现
 */

#include "GlobalFunction.h"
#include <algorithm>
#include <cstdarg>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>

using namespace std;

// 字符串工具实现
namespace StringUtils {

vector<string> split(const string& str, char delimiter)
{
    vector<string> tokens;
    stringstream ss(str);
    string token;

    while (getline(ss, token, delimiter)) {
        tokens.push_back(token);
    }

    return tokens;
}

string join(const vector<string>& strs, const string& delimiter)
{
    if (strs.empty()) {
        return "";
    }

    ostringstream oss;
    for (size_t i = 0; i < strs.size(); ++i) {
        if (i > 0) {
            oss << delimiter;
        }
        oss << strs[i];
    }

    return oss.str();
}

string trim(const string& str)
{
    size_t first = str.find_first_not_of(" \t\n\r");
    if (first == string::npos) {
        return "";
    }

    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, last - first + 1);
}

string toUpper(const string& str)
{
    string result = str;
    transform(result.begin(), result.end(), result.begin(), ::toupper);
    return result;
}

string toLower(const string& str)
{
    string result = str;
    transform(result.begin(), result.end(), result.begin(), ::tolower);
    return result;
}

bool contains(const string& str, const string& sub)
{
    return str.find(sub) != string::npos;
}

string replace(const string& str, const string& from, const string& to)
{
    string result = str;
    size_t pos = 0;

    while ((pos = result.find(from, pos)) != string::npos) {
        result.replace(pos, from.length(), to);
        pos += to.length();
    }

    return result;
}

string format(const char* fmt, ...)
{
    char buffer[4096];
    va_list args;

    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);

    return string(buffer);
}

} // namespace StringUtils

// 时间工具实现
namespace TimeUtils {

int64_t getCurrentTimestampMs()
{
    auto now = chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    return chrono::duration_cast<chrono::milliseconds>(duration).count();
}

int64_t getCurrentTimestampSec()
{
    auto now = chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    return chrono::duration_cast<chrono::seconds>(duration).count();
}

string timestampToString(int64_t timestamp, const string& format)
{
    time_t time = static_cast<time_t>(timestamp / 1000);
    char buffer[128];

    struct tm* tmInfo = localtime(&time);
    strftime(buffer, sizeof(buffer), format.c_str(), tmInfo);

    return string(buffer);
}

string getCurrentDate(const string& format)
{
    return timestampToString(getCurrentTimestampSec(), format);
}

string getCurrentTime(const string& format)
{
    return timestampToString(getCurrentTimestampSec(), format);
}

} // namespace TimeUtils

// 数值转换工具实现
namespace ConvertUtils {

int stringToInt(const string& str, int defaultValue)
{
    try {
        return stoi(str);
    } catch (...) {
        return defaultValue;
    }
}

long stringToLong(const string& str, long defaultValue)
{
    try {
        return stol(str);
    } catch (...) {
        return defaultValue;
    }
}

double stringToDouble(const string& str, double defaultValue)
{
    try {
        return stod(str);
    } catch (...) {
        return defaultValue;
    }
}

string intToString(int value)
{
    return to_string(value);
}

string doubleToString(double value, int precision)
{
    ostringstream oss;
    oss << fixed << setprecision(precision) << value;
    return oss.str();
}

int hexStringToInt(const string& hexStr)
{
    int value;
    stringstream ss;

    ss << hex << hexStr;
    ss >> value;

    return value;
}

string intToHexString(int value, int width)
{
    ostringstream oss;
    oss << hex << setw(width) << setfill('0') << value;
    return oss.str();
}

string bytesToHexString(const uint8_t* data, size_t length)
{
    ostringstream oss;

    for (size_t i = 0; i < length; ++i) {
        oss << hex << setw(2) << setfill('0') << static_cast<int>(data[i]);
    }

    return oss.str();
}

vector<uint8_t> hexStringToBytes(const string& hexStr)
{
    vector<uint8_t> bytes;

    for (size_t i = 0; i < hexStr.length(); i += 2) {
        string byteStr = hexStr.substr(i, 2);
        uint8_t byte = static_cast<uint8_t>(hexStringToInt(byteStr));
        bytes.push_back(byte);
    }

    return bytes;
}

} // namespace ConvertUtils

// 文件工具实现
namespace FileUtils {

bool fileExists(const string& path)
{
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}

bool directoryExists(const string& path)
{
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0 && S_ISDIR(buffer.st_mode));
}

bool createDirectory(const string& path)
{
    return mkdir(path.c_str(), 0755) == 0;
}

bool createDirectories(const string& path)
{
    if (directoryExists(path)) {
        return true;
    }

    size_t pos = 0;
    while ((pos = path.find('/', pos + 1)) != string::npos) {
        string subPath = path.substr(0, pos);
        if (!directoryExists(subPath)) {
            if (mkdir(subPath.c_str(), 0755) != 0) {
                return false;
            }
        }
    }

    return mkdir(path.c_str(), 0755) == 0 || directoryExists(path);
}

bool removeFile(const string& path)
{
    return unlink(path.c_str()) == 0;
}

size_t getFileSize(const string& path)
{
    struct stat buffer;
    if (stat(path.c_str(), &buffer) != 0) {
        return 0;
    }
    return static_cast<size_t>(buffer.st_size);
}

string readFile(const string& path)
{
    ifstream file(path);
    if (!file.is_open()) {
        return "";
    }

    ostringstream oss;
    oss << file.rdbuf();
    return oss.str();
}

bool writeFile(const string& path, const string& content)
{
    ofstream file(path);
    if (!file.is_open()) {
        return false;
    }

    file << content;
    return file.good();
}

} // namespace FileUtils

// 日志工具实现
namespace LogUtils {

void log(LogLevel level, const string& message)
{
    cout << formatLog(level, message) << endl;
}

string formatLog(LogLevel level, const string& message)
{
    ostringstream oss;
    oss << "[" << getLevelName(level) << "] "
        << TimeUtils::getCurrentTime("%Y-%m-%d %H:%M:%S") << " "
        << message;
    return oss.str();
}

string getLevelName(LogLevel level)
{
    switch (level) {
    case LogLevel::DEBUG:
        return "DEBUG";
    case LogLevel::INFO:
        return "INFO";
    case LogLevel::WARNING:
        return "WARN";
    case LogLevel::ERROR:
        return "ERROR";
    case LogLevel::FATAL:
        return "FATAL";
    default:
        return "UNKNOWN";
    }
}

} // namespace LogUtils
