#include "common/ModbusFreshnessTracker.h"

#include <chrono>
#include <iostream>

int main()
{
    using namespace std::chrono;
    using Clock = ModbusFreshnessTracker::Clock;

    ModbusFreshnessTracker tracker;
    const Clock::time_point startedAt(milliseconds(1000));

    if (tracker.isFresh(startedAt)) {
        std::cerr << "freshness must be false before the first success\n";
        return 1;
    }

    tracker.markSuccess(startedAt);
    if (!tracker.isFresh(startedAt + milliseconds(29999))) {
        std::cerr << "freshness expired before 30 seconds\n";
        return 1;
    }
    if (tracker.isFresh(startedAt + milliseconds(30000))) {
        std::cerr << "freshness must expire at 30 seconds\n";
        return 1;
    }

    const Clock::time_point recoveredAt = startedAt + milliseconds(45000);
    tracker.markSuccess(recoveredAt);
    if (!tracker.isFresh(recoveredAt)
        || !tracker.isFresh(recoveredAt + milliseconds(29999))
        || tracker.isFresh(recoveredAt + milliseconds(30000))) {
        std::cerr << "a successful communication did not reset the window\n";
        return 1;
    }

    std::cout << "Modbus freshness tracker tests passed\n";
    return 0;
}
