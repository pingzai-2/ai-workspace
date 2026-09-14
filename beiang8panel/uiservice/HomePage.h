/**
 * 首页API
 *
 * 提供首页相关的HTTP API接口
 */

#ifndef HOMEPAGE_H
#define HOMEPAGE_H

#include <string>
#include "BasePage.h"

class HomePage : public BasePage {
public:
    explicit HomePage(DataManager* dataManager);

    // API: 获取首页数据
    // 返回设备状态、环境数据、工作模式等
    std::string getHomeData();

    // API: 获取设备摘要信息
    std::string getDeviceSummary();

    // API: 获取环境数据
    std::string getEnvironmentData();

    // API: 获取空气质量数据（包含TVOC、甲醛）
    std::string getAirQualityData();

    // API: 获取压缩机状态
    std::string getCompressorStatus();

    // API: 获取风阀状态
    std::string getValveStatus();

    // API: 获取风阀方向和步数
    std::string getDamperControlStatus();

    // API: 获取风机转速信息
    std::string getFanRPMData();

    // API: 获取风机风量数据
    std::string getFanFlowData();

    // API: 获取加湿系统状态
    std::string getHumidifierSystemStatus();

    // API: 获取排水系统状态
    std::string getDrainageSystemStatus();

    // API: 快捷控制
    std::string quickPowerOn(bool on);
    std::string quickSetMode(int mode);

    // API: 获取实时数据摘要
    std::string getRealtimeSummary();
};

#endif // HOMEPAGE_H
