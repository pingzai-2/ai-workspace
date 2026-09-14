/**
 * MemoryWatchPolicy - 内存水位监控纯策略(无 IO、无线程,可单测)
 *
 * 三级阈值(Exclusive, 低到高): warn(仅告警日志) < restartApp(重启Flutter) < reboot(重启设备)
 * 防抖与防重启循环:
 * - warn 以下按节奏记日志(进入记一次,之后每 60s 重复),恢复记一次 INFO
 * - restart/reboot 档需连续 sustainedChecks 次采样命中才动作(瞬时波动不触发)
 * - restartApp 动作后有 actionCooldownSec 冷却;冷却内水位仍处 restart 档
 *   视为"重启未解决"→ 升级为 RebootDevice
 * - OTA 进行中(下载/安装)抑制所有动作,仅告警,避免打断升级
 */

#ifndef MEMORYWATCHPOLICY_H
#define MEMORYWATCHPOLICY_H

#include <cstdint>

struct MemoryWatchConfig {
    bool enabled = true;
    int checkIntervalSec = 10;          // 采样间隔
    int32_t warnThresholdKB = 64 * 1024;      // 告警阈值
    int32_t restartAppThresholdKB = 32 * 1024; // 重启 Flutter 阈值
    int32_t rebootThresholdKB = 16 * 1024;     // 重启设备阈值
    int sustainedChecks = 3;            // 动作所需连续命中次数
    int actionCooldownSec = 300;        // 重启App后的动作冷却(超时后仍低→升级重启设备)
};

// 当前水位档位(互斥): 0=正常 1=warn 2=restart 3=reboot
enum class MemoryWatchLevel { Normal = 0, Warn = 1, RestartApp = 2, RebootDevice = 3 };

// 策略累积状态(模块持有,evaluate 内更新)
struct MemoryWatchState {
    int levelStreak = 0;               // 当前档位连续命中次数
    int lastLevel = 0;                 // 上一轮档位(0-3)
    bool inLowWater = false;           // 处于低水位周期(用于恢复检测)
    int64_t lastWarnLogEpoch = 0;      // 上次告警日志时间(0=未记)
    int64_t lastRestartAppEpoch = 0;   // 上次重启App时间(0=从未)
};

// 单次采样输入
struct MemoryWatchSample {
    int64_t memAvailableKB = 0;
    bool otaBusy = false;
};

// evaluate 返回的动作(模块负责解释执行:记日志/杀进程/重启)
enum class MemoryWatchAction {
    None,            // 水位正常,无日志
    KeepQuiet,       // 低水位但未到日志节奏,静默
    LogWarnOnce,     // 进入低水位,记告警
    LogWarnRepeat,   // 持续低水位,按节奏重复告警
    LogRecover,      // 恢复正常,记恢复日志
    RestartApp,      // 重启 Flutter(已满足持续次数)
    RebootDevice,    // 重启设备(持续超低 或 重启App后冷却内仍低=升级)
    SkipOtaBusy,     // 应动作但 OTA 进行中,抑制(记告警)
};

inline MemoryWatchLevel levelOf(int64_t memAvailableKB, const MemoryWatchConfig& config)
{
    if (memAvailableKB < config.rebootThresholdKB) {
        return MemoryWatchLevel::RebootDevice;
    }
    if (memAvailableKB < config.restartAppThresholdKB) {
        return MemoryWatchLevel::RestartApp;
    }
    if (memAvailableKB < config.warnThresholdKB) {
        return MemoryWatchLevel::Warn;
    }
    return MemoryWatchLevel::Normal;
}

inline int levelToInt(MemoryWatchLevel level)
{
    return static_cast<int>(level);
}

// 每个采样周期调用一次;now 为 epoch 秒
inline MemoryWatchAction evaluate(const MemoryWatchSample& sample,
    const MemoryWatchConfig& config, int64_t now, MemoryWatchState* state)
{
    const MemoryWatchLevel level = levelOf(sample.memAvailableKB, config);

    if (level == MemoryWatchLevel::Normal) {
        if (state->inLowWater) {
            *state = MemoryWatchState();
            return MemoryWatchAction::LogRecover;
        }
        return MemoryWatchAction::None;
    }

    // 档位变化则重新累计连续命中
    if (levelToInt(level) != state->lastLevel) {
        state->levelStreak = 1;
        state->lastLevel = levelToInt(level);
    } else {
        ++state->levelStreak;
    }
    state->inLowWater = true;

    // 告警日志节奏: 进入记一次,之后每 60s 重复(任何低档位都记)
    const int64_t prevWarnLogEpoch = state->lastWarnLogEpoch;
    const bool shouldLog = prevWarnLogEpoch == 0
        || now - prevWarnLogEpoch >= 60;
    if (shouldLog) {
        state->lastWarnLogEpoch = now;
    }
    const auto warnLogAction = [shouldLog, prevWarnLogEpoch]() {
        if (!shouldLog) {
            return MemoryWatchAction::KeepQuiet;
        }
        return prevWarnLogEpoch == 0
            ? MemoryWatchAction::LogWarnOnce
            : MemoryWatchAction::LogWarnRepeat;
    };

    if (level == MemoryWatchLevel::Warn) {
        return warnLogAction();
    }

    // 动作档: 需连续命中
    if (state->levelStreak < config.sustainedChecks) {
        return warnLogAction();
    }

    if (sample.otaBusy) {
        return MemoryWatchAction::SkipOtaBusy;
    }

    if (level == MemoryWatchLevel::RebootDevice) {
        return MemoryWatchAction::RebootDevice;
    }

    // restart 档: 冷却内仍低 → 重启未解决,升级为重启设备
    if (state->lastRestartAppEpoch != 0
        && now - state->lastRestartAppEpoch < config.actionCooldownSec) {
        return MemoryWatchAction::RebootDevice;
    }
    return MemoryWatchAction::RestartApp;
}

#endif // MEMORYWATCHPOLICY_H
