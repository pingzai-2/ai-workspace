/**
 * 手动模式页面API实现
 */

#include "ManualModePage.h"

ManualModePage::ManualModePage(DataManager* dataManager)
    : BasePage(dataManager)
{
}

std::string ManualModePage::getManualModeData() {
    // TODO: 获取手动模式数据
    return buildNotImplemented("getManualModeData");
}

std::string ManualModePage::setManualModeParams(const std::string& paramsJson) {
    // TODO: 设置手动模式参数
    return buildNotImplemented("setManualModeParams");
}

std::string ManualModePage::setFanSpeed(int level) {
    // TODO: 设置风机档位
    return buildNotImplemented("setFanSpeed");
}

std::string ManualModePage::setUVLight(bool on) {
    // TODO: 控制UV灯
    return buildNotImplemented("setUVLight");
}

std::string ManualModePage::setIonizer(bool on) {
    // TODO: 控制负离子
    return buildNotImplemented("setIonizer");
}
