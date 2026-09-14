/**
 * 手动模式页面API
 */

#ifndef MANUALMODEPAGE_H
#define MANUALMODEPAGE_H

#include <string>
#include "BasePage.h"

class ManualModePage : public BasePage {
public:
    explicit ManualModePage(DataManager* dataManager);

    // API: 获取手动模式数据
    std::string getManualModeData();

    // API: 设置手动模式参数
    std::string setManualModeParams(const std::string& paramsJson);

    // API: 设置风机档位
    std::string setFanSpeed(int level);

    // API: 控制UV灯
    std::string setUVLight(bool on);

    // API: 控制负离子
    std::string setIonizer(bool on);
};

#endif // MANUALMODEPAGE_H
