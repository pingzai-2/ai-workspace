/**
 * 工程模式页面API
 */

#ifndef ENGINEERINGMODEPAGE_H
#define ENGINEERINGMODEPAGE_H

#include <string>
#include "BasePage.h"

class EngineeringModePage : public BasePage {
public:
    explicit EngineeringModePage(DataManager* dataManager);

    // API: 获取工程模式数据
    std::string getEngineeringModeData();

    // API: 读取寄存器
    std::string readRegister(int address, int count);

    // API: 写入寄存器
    std::string writeRegister(int address, int value);

    // API: 获取诊断信息
    std::string getDiagnosticInfo();
};

#endif // ENGINEERINGMODEPAGE_H
