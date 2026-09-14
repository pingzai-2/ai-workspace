/**
 * LogManager - 基于 spdlog 的日志管理器
 * 提供线程安全、高性能的日志服务，支持文件轮转和多输出目标
 */

#ifndef LOGMANAGER_H
#define LOGMANAGER_H

#include "GlobalDefine.h"
#include <memory>
#include <mutex>
#include <string>

// 包含 spdlog 头文件（header-only 模式）
#include <spdlog/fmt/ostr.h>
#include <spdlog/spdlog.h>

/**
 * @brief 日志管理器单例类
 *
 * 功能特性：
 * - 线程安全
 * - 支持多级别日志 (TRACE/DEBUG/INFO/WARN/ERR/CRITICAL)
 * - 支持控制台和文件双输出
 * - 支持日志文件自动轮转
 * - 低内存占用，适合嵌入式系统
 */
class LogManager {
public:
    /**
     * @brief 获取单例实例
     * @return LogManager& 单例引用
     */
    static LogManager& getInstance();

    /**
     * @brief 初始化日志管理器
     *
     * @param logDir 日志文件目录（默认: "logs"）
     * @param logFileName 日志文件名（默认: "beiang8panel"）
     * @param level 日志级别（默认: INFO）
     * @param consoleEnabled 是否启用控制台输出（默认: true）
     * @param maxFileSize 单个日志文件最大大小（字节，默认: 10MB）
     * @param maxFiles 保留的最大日志文件数量（默认: 5）
     * @return true 初始化成功
     * @return false 初始化失败
     */
    bool initialize(const std::string& logDir = "logs",
        const std::string& logFileName = "beiang8panel",
        LogLevel level = LogLevel::INFO,
        bool consoleEnabled = true,
        size_t maxFileSize = 10 * 1024 * 1024,
        size_t maxFiles = 5);

    /**
     * @brief 关闭日志管理器，刷新并关闭所有日志记录器
     */
    void shutdown();

    /**
     * @brief 设置日志级别
     * @param level 目标日志级别
     */
    void setLogLevel(LogLevel level);

    /**
     * @brief 获取当前日志级别
     * @return LogLevel 当前日志级别
     */
    LogLevel getLogLevel() const;

    /**
     * @brief 刷新日志缓冲区
     */
    void flush();

    /**
     * @brief 获取底层的 spdlog logger
     * @return std::shared_ptr<spdlog::logger> logger 实例
     */
    std::shared_ptr<spdlog::logger> getLogger();

    // 禁止拷贝和赋值
    LogManager(const LogManager&) = delete;
    LogManager& operator=(const LogManager&) = delete;

private:
    LogManager() = default;
    ~LogManager();

    /**
     * @brief 将 LogLevel 枚举转换为 spdlog 的 level_t
     * @param level LogLevel 枚举值
     * @return spdlog::level::level_enum spdlog 日志级别
     */
    int toSpdlogLevel(LogLevel level) const;

    /**
     * @brief 从 spdlog level_t 转换为 LogLevel 枚举
     * @param level spdlog 日志级别
     * @return LogLevel LogLevel 枚举值
     */
    LogLevel fromSpdlogLevel(int level) const;

private:
    std::shared_ptr<spdlog::logger> m_logger; ///< 主日志记录器
    std::shared_ptr<spdlog::logger> m_consoleLogger; ///< 控制台日志记录器
    std::mutex m_mutex; ///< 互斥锁保护初始化过程
    bool m_initialized = false; ///< 初始化状态
    LogLevel m_currentLevel = LogLevel::INFO; ///< 当前日志级别
};

// ============================================================================
// 便捷日志宏定义（兼容原有的宏接口）
// ============================================================================

/**
 * @brief 记录 TRACE 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_TRACE(fmt, ...) \
    LogManager::getInstance().getLogger()->trace(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 DEBUG 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_DEBUG(fmt, ...) \
    LogManager::getInstance().getLogger()->debug(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 INFO 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_INFO(fmt, ...) \
    LogManager::getInstance().getLogger()->info(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 WARNING 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_WARNING(fmt, ...) \
    LogManager::getInstance().getLogger()->warn(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 WARNING 级别日志 (LOG_WARN 别名)
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_WARN(fmt, ...) \
    LogManager::getInstance().getLogger()->warn(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 ERROR 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_ERROR(fmt, ...) \
    LogManager::getInstance().getLogger()->error(fmt, ##__VA_ARGS__)

/**
 * @brief 记录 CRITICAL/FATAL 级别日志
 * @param fmt 格式化字符串
 * @param ... 参数
 */
#define LOG_CRITICAL(fmt, ...) \
    LogManager::getInstance().getLogger()->critical(fmt, ##__VA_ARGS__)

// 别名
#define LOG_FATAL LOG_CRITICAL

#endif // LOGMANAGER_H
