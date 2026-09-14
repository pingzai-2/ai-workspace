/**
 * 定时任务调度控制器
 *
 * 管理所有定时任务，包括：
 * - 定时开关设备
 * - 自动化场景执行
 * - 定时数据采集
 */

#ifndef SCHEDULECONTROLLER_H
#define SCHEDULECONTROLLER_H

#include "common/GlobalDefine.h"
#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

// 定时任务状态
enum class TaskStatus {
    Idle = 0,
    Running = 1,
    Paused = 2,
    Disabled = 3
};

// 定时任务类型
enum class TaskType {
    Once = 0, // 一次性任务
    Daily = 1, // 每日任务
    Weekly = 2, // 每周任务
    Interval = 3 // 间隔任务
};

// 定时任务定义
struct ScheduledTask {
    std::string taskId; // 任务ID
    std::string taskName; // 任务名称
    TaskType taskType; // 任务类型
    TaskStatus status; // 任务状态

    // 时间配置
    int hour; // 小时 (0-23)
    int minute; // 分钟 (0-59)
    int weekday; // 星期 (0-6, 0=周日)
    int intervalSeconds; // 间隔(秒)

    // 执行次数限制
    int maxExecutions; // 最大执行次数 (0=无限制)
    int executionCount; // 已执行次数

    // 任务函数
    std::function<void()> taskFunc;

    ScheduledTask()
        : taskType(TaskType::Daily)
        , status(TaskStatus::Idle)
        , hour(0)
        , minute(0)
        , weekday(0)
        , intervalSeconds(60)
        , maxExecutions(0)
        , executionCount(0)
    {
    }
};

// 定时调度控制器类
class ScheduleController {
public:
    ScheduleController();
    ~ScheduleController();

    // 启动/停止
    bool start();
    void stop();
    bool isRunning() const { return m_isRunning; }

    // 任务管理
    std::string addTask(std::shared_ptr<ScheduledTask> task);
    bool removeTask(const std::string& taskId);
    bool pauseTask(const std::string& taskId);
    bool resumeTask(const std::string& taskId);
    std::shared_ptr<ScheduledTask> getTask(const std::string& taskId);

    // 获取所有任务
    std::vector<std::shared_ptr<ScheduledTask>> getAllTasks() const;

    // 手动触发任务
    bool triggerTask(const std::string& taskId);

    // 状态获取
    size_t getTaskCount() const { return m_tasks.size(); }
    size_t getActiveTaskCount() const;

private:
    // 调度线程
    void scheduleLoop();

    // 检查任务是否到期
    bool isTaskDue(std::shared_ptr<ScheduledTask> task);

    // 执行任务
    void executeTask(std::shared_ptr<ScheduledTask> task);

    // 生成任务ID
    std::string generateTaskId();

    // 任务列表
    std::vector<std::shared_ptr<ScheduledTask>> m_tasks;
    mutable std::mutex m_tasksMutex;

    // 状态
    std::atomic<bool> m_isRunning;
    std::thread m_scheduleThread;

    // 任务ID计数器
    static std::atomic<uint64_t> s_taskIdCounter;
};

#endif // SCHEDULECONTROLLER_H
