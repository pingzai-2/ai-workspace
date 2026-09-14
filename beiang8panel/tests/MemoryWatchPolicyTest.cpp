/**
 * MemoryWatchPolicy 单元测试(纯策略,无 IO)
 *
 * 本地运行:
 *   g++ -std=c++14 tests/MemoryWatchPolicyTest.cpp -I . -o /tmp/memwatchtest && /tmp/memwatchtest
 */

#include "memwatch/MemoryWatchPolicy.h"

#include <iostream>

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

MemoryWatchConfig testConfig()
{
    MemoryWatchConfig config;
    config.checkIntervalSec = 10;
    config.warnThresholdKB = 64 * 1024;
    config.restartAppThresholdKB = 32 * 1024;
    config.rebootThresholdKB = 16 * 1024;
    config.sustainedChecks = 3;
    config.actionCooldownSec = 300;
    return config;
}

bool testNormalAndRecover()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    CHECK(evaluate({200 * 1024, false}, config, t0, &state) == MemoryWatchAction::None);
    CHECK(evaluate({200 * 1024, false}, config, t0 + 10, &state) == MemoryWatchAction::None);

    // 进入低水位: 告警一次
    CHECK(evaluate({60 * 1024, false}, config, t0 + 20, &state) == MemoryWatchAction::LogWarnOnce);
    // 持续低水位未到 60s 重复节奏: 静默
    CHECK(evaluate({62 * 1024, false}, config, t0 + 30, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({61 * 1024, false}, config, t0 + 60, &state) == MemoryWatchAction::KeepQuiet);
    // 满 60s 重复告警
    CHECK(evaluate({60 * 1024, false}, config, t0 + 90, &state) == MemoryWatchAction::LogWarnRepeat);
    // 恢复: 记恢复日志一次,之后正常
    CHECK(evaluate({200 * 1024, false}, config, t0 + 100, &state) == MemoryWatchAction::LogRecover);
    CHECK(evaluate({200 * 1024, false}, config, t0 + 110, &state) == MemoryWatchAction::None);
    // 再次进入低水位重新告警(状态已重置)
    CHECK(evaluate({50 * 1024, false}, config, t0 + 120, &state) == MemoryWatchAction::LogWarnOnce);
    return true;
}

bool testRestartAppSustained()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // restart 档(16MB<=mem<32MB)需连续 3 次才动作,前两次只告警
    CHECK(evaluate({30 * 1024, false}, config, t0, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({28 * 1024, false}, config, t0 + 10, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({29 * 1024, false}, config, t0 + 20, &state) == MemoryWatchAction::RestartApp);
    state.lastRestartAppEpoch = t0 + 20; // 模块动作后回写
    // 恢复
    CHECK(evaluate({500 * 1024, false}, config, t0 + 30, &state) == MemoryWatchAction::LogRecover);
    return true;
}

bool testEscalateToRebootWithinCooldown()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // 重启 App 后冷却内(300s)水位仍处 restart 档 → 升级重启设备
    state.lastRestartAppEpoch = t0;
    CHECK(evaluate({30 * 1024, false}, config, t0 + 30, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({30 * 1024, false}, config, t0 + 40, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({30 * 1024, false}, config, t0 + 50, &state) == MemoryWatchAction::RebootDevice);
    return true;
}

bool testCooldownExpiredRestartsAgain()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // 冷却已过(>300s)再次持续低水位 → 允许再次重启 App(而非直接重启设备)
    state.lastRestartAppEpoch = t0;
    CHECK(evaluate({30 * 1024, false}, config, t0 + 400, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({30 * 1024, false}, config, t0 + 410, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({30 * 1024, false}, config, t0 + 420, &state) == MemoryWatchAction::RestartApp);
    return true;
}

bool testRebootTier()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // reboot 档(mem<16MB)连续 3 次 → 重启设备
    CHECK(evaluate({15 * 1024, false}, config, t0, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({14 * 1024, false}, config, t0 + 10, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({15 * 1024, false}, config, t0 + 20, &state) == MemoryWatchAction::RebootDevice);
    return true;
}

bool testOtaBusySuppressesActions()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // OTA 进行中: 动作档命中但只告警不动作
    CHECK(evaluate({10 * 1024, true}, config, t0, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({10 * 1024, true}, config, t0 + 10, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({10 * 1024, true}, config, t0 + 20, &state) == MemoryWatchAction::SkipOtaBusy);
    return true;
}

bool testLevelChangeResetsStreak()
{
    const MemoryWatchConfig config = testConfig();
    MemoryWatchState state;
    const int64_t t0 = 1000;

    // warn 档累计 2 次后跌入 reboot 档: 档位变化重新计数
    CHECK(evaluate({40 * 1024, false}, config, t0, &state) == MemoryWatchAction::LogWarnOnce);
    CHECK(evaluate({40 * 1024, false}, config, t0 + 10, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({10 * 1024, false}, config, t0 + 20, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({10 * 1024, false}, config, t0 + 30, &state) == MemoryWatchAction::KeepQuiet);
    CHECK(evaluate({10 * 1024, false}, config, t0 + 40, &state) == MemoryWatchAction::RebootDevice);
    return true;
}

} // namespace

int main()
{
    const bool allPassed =
        testNormalAndRecover()
        && testRestartAppSustained()
        && testEscalateToRebootWithinCooldown()
        && testCooldownExpiredRestartsAgain()
        && testRebootTier()
        && testOtaBusySuppressesActions()
        && testLevelChangeResetsStreak();
    if (!allPassed || g_failures != 0) {
        std::cerr << "Memory watch policy tests failed (" << g_failures << " assertion(s))" << std::endl;
        return 1;
    }
    std::cout << "Memory watch policy tests passed" << std::endl;
    return 0;
}
