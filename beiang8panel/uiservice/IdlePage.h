/**
 * 待机页面API
 */

#ifndef IDLEPAGE_H
#define IDLEPAGE_H

#include <string>
#include "BasePage.h"

class IdlePage : public BasePage {
public:
    explicit IdlePage(DataManager* dataManager);

    // API: 获取待机页面数据
    std::string getIdlePageData();

    // API: 获取环境数据（RA/OA/SA/TVOC/甲醛）
    std::string getEnvironmentData();

    // API: 获取室内外空气评价提醒（待机页面显示）
    // 依据室内(200FH)/室外(2013H) PM2.5 综合判定，返回提醒文案
    std::string getAirQualityReminder();

    // API: 唤醒设备
    std::string wakeUp();
};

#endif // IDLEPAGE_H
