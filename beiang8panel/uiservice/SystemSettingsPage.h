/**
 * 系统设置页面API
 */

#ifndef SYSTEMSETTINGSPAGE_H
#define SYSTEMSETTINGSPAGE_H

#include <string>
#include "BasePage.h"

class SystemSettingsPage : public BasePage {
public:
    explicit SystemSettingsPage(DataManager* dataManager);

    // API: 获取系统设置
    std::string getSystemSettings();

    // API: 设置系统参数
    std::string setSystemSettings(const std::string& settingsJson);

    // API: 网络设置
    std::string setNetworkConfig(const std::string& configJson);

    // API: 显示设置
    std::string setDisplayConfig(const std::string& configJson);

    // API: 恢复出厂设置
    std::string factoryReset();
};

#endif // SYSTEMSETTINGSPAGE_H
