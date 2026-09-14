/**
 * 设备维护页面API
 */

#ifndef DEVICEMAINTENANCEPAGE_H
#define DEVICEMAINTENANCEPAGE_H

#include <string>
#include "BasePage.h"

class DeviceMaintenancePage : public BasePage {
public:
    explicit DeviceMaintenancePage(DataManager* dataManager);

    // API: 获取滤网状态
    std::string getFilterStatus();

    // API: 重置滤网寿命
    std::string resetFilterLife();

    // API: 获取设备统计信息
    std::string getDeviceStatistics();

    // API: 获取设备日志
    std::string getDeviceLogs();
};

#endif // DEVICEMAINTENANCEPAGE_H
