/**
 * LogManager 实现
 */

#include "LogManager.h"
#include <iostream>
#include <spdlog/fmt/ostr.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>
#include <sys/stat.h>
#include <sys/types.h>

using namespace std;

// POSIX mkdir 递归创建目录
static void mkdir_p(const string& path)
{
    string current;
    string::size_type pos = 0;
    while ((pos = path.find('/', pos)) != string::npos) {
        current = path.substr(0, pos);
        if (!current.empty()) {
            mkdir(current.c_str(), 0755);
        }
        pos++;
    }
    mkdir(path.c_str(), 0755);
}

LogManager& LogManager::getInstance()
{
    static LogManager instance;
    return instance;
}

LogManager::~LogManager()
{
    shutdown();
}

bool LogManager::initialize(const string& logDir,
    const string& logFileName,
    LogLevel level,
    bool consoleEnabled,
    size_t maxFileSize,
    size_t maxFiles)
{
    lock_guard<mutex> lock(m_mutex);

    if (m_initialized) {
        // 已初始化，只更新日志级别
        setLogLevel(level);
        return true;
    }

    try {
        // 创建日志目录 (使用 POSIX mkdir)
        mkdir_p(logDir);

        // 创建文件轮转 sink
        string logPath = logDir + "/" + logFileName + ".log";
        auto fileSink = make_shared<spdlog::sinks::rotating_file_sink_mt>(
            logPath, maxFileSize, maxFiles);

        // 文件 sink 格式：[时间] [级别] [线程] 消息
        fileSink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [tid:%t] %v");

        // 创建主 logger（仅文件输出）
        m_logger = make_shared<spdlog::logger>("main", fileSink);
        m_logger->set_level(static_cast<spdlog::level::level_enum>(toSpdlogLevel(level)));
        m_logger->flush_on(spdlog::level::warn); // WARN 及以上级别立即刷新

        // 如果启用控制台输出，创建控制台 sink
        if (consoleEnabled) {
            auto consoleSink = make_shared<spdlog::sinks::stdout_color_sink_mt>();
            // 控制台 sink 格式：带颜色的简洁格式
            consoleSink->set_pattern("%^[%Y-%m-%d %H:%M:%S.%e]%$ [%l] %v");

            // 创建带控制台输出的 logger
            m_consoleLogger = make_shared<spdlog::logger>("console", consoleSink);
            m_consoleLogger->set_level(static_cast<spdlog::level::level_enum>(toSpdlogLevel(level)));

            // 将文件 sink 也添加到控制台 logger，实现双输出
            m_consoleLogger->sinks().push_back(fileSink);
        }

        // 注册到 spdlog 全局注册表（可选）
        spdlog::register_logger(m_logger);
        if (m_consoleLogger) {
            spdlog::register_logger(m_consoleLogger);
        }

        // 设置默认 logger
        spdlog::set_default_logger(m_consoleLogger ? m_consoleLogger : m_logger);

        m_currentLevel = level;
        m_initialized = true;

        // 记录初始化成功日志
        m_logger->info("LogManager initialized: logDir={}, level={}, consoleEnabled={}",
            logDir, static_cast<int>(level), consoleEnabled);

        return true;

    } catch (const exception& e) {
        cerr << "[LogManager] Initialization failed: " << e.what() << endl;
        return false;
    }
}

void LogManager::shutdown()
{
    lock_guard<mutex> lock(m_mutex);

    if (!m_initialized) {
        return;
    }

    try {
        if (m_logger) {
            m_logger->info("LogManager shutting down");
            m_logger->flush();
            m_logger.reset();
        }

        if (m_consoleLogger) {
            m_consoleLogger->flush();
            m_consoleLogger.reset();
        }

        spdlog::shutdown();
        m_initialized = false;

    } catch (const exception& e) {
        cerr << "[LogManager] Shutdown error: " << e.what() << endl;
    }
}

void LogManager::setLogLevel(LogLevel level)
{
    lock_guard<mutex> lock(m_mutex);

    if (!m_initialized) {
        m_currentLevel = level;
        return;
    }

    try {
        auto spdlogLevel = static_cast<spdlog::level::level_enum>(toSpdlogLevel(level));

        if (m_logger) {
            m_logger->set_level(spdlogLevel);
        }

        if (m_consoleLogger) {
            m_consoleLogger->set_level(spdlogLevel);
        }

        m_currentLevel = level;

    } catch (const exception& e) {
        cerr << "[LogManager] Failed to set log level: " << e.what() << endl;
    }
}

LogLevel LogManager::getLogLevel() const
{
    return m_currentLevel;
}

void LogManager::flush()
{
    lock_guard<mutex> lock(m_mutex);

    try {
        if (m_logger) {
            m_logger->flush();
        }

        if (m_consoleLogger) {
            m_consoleLogger->flush();
        }
    } catch (const exception& e) {
        cerr << "[LogManager] Flush error: " << e.what() << endl;
    }
}

shared_ptr<spdlog::logger> LogManager::getLogger()
{
    // 返回控制台 logger（如果存在），否则返回文件 logger
    if (m_consoleLogger) {
        return m_consoleLogger;
    }
    return m_logger;
}

int LogManager::toSpdlogLevel(LogLevel level) const
{
    switch (level) {
    case LogLevel::DEBUG:
        return spdlog::level::debug;
    case LogLevel::INFO:
        return spdlog::level::info;
    case LogLevel::WARNING:
        return spdlog::level::warn;
    case LogLevel::ERROR:
        return spdlog::level::err;
    case LogLevel::FATAL:
        return spdlog::level::critical;
    default:
        return spdlog::level::info;
    }
}

LogLevel LogManager::fromSpdlogLevel(int level) const
{
    switch (level) {
    case spdlog::level::debug:
        return LogLevel::DEBUG;
    case spdlog::level::info:
        return LogLevel::INFO;
    case spdlog::level::warn:
        return LogLevel::WARNING;
    case spdlog::level::err:
        return LogLevel::ERROR;
    case spdlog::level::critical:
        return LogLevel::FATAL;
    default:
        return LogLevel::INFO;
    }
}
