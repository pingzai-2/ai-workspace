/**
 * 定时任务调度控制器实现
 */

#include "ScheduleController.h"
#include "common/LogManager.h"
#include <algorithm>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <sstream>

using namespace std;

std::atomic<uint64_t> ScheduleController::s_taskIdCounter(1);

ScheduleController::ScheduleController()
    : m_isRunning(false)
{
}

ScheduleController::~ScheduleController()
{
    stop();
}

bool ScheduleController::start()
{
    if (m_isRunning) {
        LOG_WARNING("[ScheduleController] Already running");
        return true;
    }

    m_isRunning = true;
    m_scheduleThread = thread(&ScheduleController::scheduleLoop, this);

    LOG_INFO("[ScheduleController] Started schedule controller");
    return true;
}

void ScheduleController::stop()
{
    if (!m_isRunning) {
        return;
    }

    m_isRunning = false;

    if (m_scheduleThread.joinable()) {
        m_scheduleThread.join();
    }

    LOG_INFO("[ScheduleController] Stopped schedule controller");
}

string ScheduleController::addTask(shared_ptr<ScheduledTask> task)
{
    lock_guard<mutex> lock(m_tasksMutex);

    if (!task) {
        return "";
    }

    // 生成任务ID
    task->taskId = generateTaskId();
    task->status = TaskStatus::Idle;

    m_tasks.push_back(task);

    LOG_INFO("[ScheduleController] Added task: {} (ID: {})", task->taskName, task->taskId);

    return task->taskId;
}

bool ScheduleController::removeTask(const string& taskId)
{
    lock_guard<mutex> lock(m_tasksMutex);

    auto it = remove_if(m_tasks.begin(), m_tasks.end(),
        [&taskId](const shared_ptr<ScheduledTask>& task) {
            return task->taskId == taskId;
        });

    if (it != m_tasks.end()) {
        m_tasks.erase(it, m_tasks.end());
        LOG_INFO("[ScheduleController] Removed task: {}", taskId);
        return true;
    }

    return false;
}

bool ScheduleController::pauseTask(const string& taskId)
{
    lock_guard<mutex> lock(m_tasksMutex);

    auto task = getTask(taskId);
    if (task && task->status != TaskStatus::Disabled) {
        task->status = TaskStatus::Paused;
        LOG_INFO("[ScheduleController] Paused task: {}", taskId);
        return true;
    }

    return false;
}

bool ScheduleController::resumeTask(const string& taskId)
{
    lock_guard<mutex> lock(m_tasksMutex);

    auto task = getTask(taskId);
    if (task && task->status == TaskStatus::Paused) {
        task->status = TaskStatus::Idle;
        LOG_INFO("[ScheduleController] Resumed task: {}", taskId);
        return true;
    }

    return false;
}

shared_ptr<ScheduledTask> ScheduleController::getTask(const string& taskId)
{
    lock_guard<mutex> lock(m_tasksMutex);

    auto it = find_if(m_tasks.begin(), m_tasks.end(),
        [&taskId](const shared_ptr<ScheduledTask>& task) {
            return task->taskId == taskId;
        });

    if (it != m_tasks.end()) {
        return *it;
    }

    return nullptr;
}

vector<shared_ptr<ScheduledTask>> ScheduleController::getAllTasks() const
{
    lock_guard<mutex> lock(m_tasksMutex);
    return m_tasks;
}

size_t ScheduleController::getActiveTaskCount() const
{
    lock_guard<mutex> lock(m_tasksMutex);

    return count_if(m_tasks.begin(), m_tasks.end(),
        [](const shared_ptr<ScheduledTask>& task) {
            return task->status == TaskStatus::Idle || task->status == TaskStatus::Running;
        });
}

bool ScheduleController::triggerTask(const string& taskId)
{
    auto task = getTask(taskId);
    if (!task) {
        return false;
    }

    executeTask(task);
    return true;
}

void ScheduleController::scheduleLoop()
{
    while (m_isRunning) {
        lock_guard<mutex> lock(m_tasksMutex);

        for (auto& task : m_tasks) {
            if (task->status == TaskStatus::Idle && isTaskDue(task)) {
                executeTask(task);
            }
        }

        // 等待下一次检查
        this_thread::sleep_for(chrono::milliseconds(SCHEDULE_CHECK_INTERVAL_MS));
    }
}

bool ScheduleController::isTaskDue(shared_ptr<ScheduledTask> task)
{
    if (task->status == TaskStatus::Running) {
        return false;
    }

    // 检查执行次数限制
    if (task->maxExecutions > 0 && task->executionCount >= task->maxExecutions) {
        task->status = TaskStatus::Disabled;
        return false;
    }

    auto now = time(nullptr);
    auto tmNow = localtime(&now);

    switch (task->taskType) {
    case TaskType::Once:
        // 一次性任务：检查是否已执行
        return task->executionCount == 0;

    case TaskType::Daily:
        // 每日任务：检查时间是否匹配
        return tmNow->tm_hour == task->hour && tmNow->tm_min == task->minute && tmNow->tm_sec == 0;

    case TaskType::Weekly:
        // 每周任务：检查星期和时间是否匹配
        return tmNow->tm_wday == task->weekday && tmNow->tm_hour == task->hour && tmNow->tm_min == task->minute && tmNow->tm_sec == 0;

    case TaskType::Interval:
        // 间隔任务：基于执行次数检查
        // 这里简化处理，实际应该记录上次执行时间
        return (time(nullptr) % task->intervalSeconds) == 0;

    default:
        return false;
    }
}

void ScheduleController::executeTask(shared_ptr<ScheduledTask> task)
{
    if (!task || !task->taskFunc) {
        return;
    }

    task->status = TaskStatus::Running;
    task->executionCount++;

    LOG_INFO("[ScheduleController] Executing task: {} (Execution #{})",
        task->taskName, task->executionCount);

    try {
        task->taskFunc();
        task->status = TaskStatus::Idle;
        LOG_INFO("[ScheduleController] Task completed: {}", task->taskName);
    } catch (const exception& e) {
        LOG_ERROR("[ScheduleController] Task failed: {} - {}", task->taskName, e.what());
        task->status = TaskStatus::Idle;
    }
}

string ScheduleController::generateTaskId()
{
    ostringstream oss;
    oss << "TASK_" << setw(6) << setfill('0') << s_taskIdCounter++;
    return oss.str();
}
