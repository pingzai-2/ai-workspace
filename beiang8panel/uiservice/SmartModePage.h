/**
 * 智能模式页面API
 */

#ifndef SMARTMODEPAGE_H
#define SMARTMODEPAGE_H

#include <string>
#include "BasePage.h"

class SmartModePage : public BasePage {
public:
    explicit SmartModePage(DataManager* dataManager);

    // API: 获取智能模式数据
    std::string getSmartModeData();

    // API: 设置智能模式参数
    std::string setSmartModeParams(const std::string& paramsJson);

    // API: 设置智能场景
    std::string setSmartScene(int scene);

    // API: 设置目标参数
    std::string setTargetValues(float pm25, float co2);
};

#endif // SMARTMODEPAGE_H
