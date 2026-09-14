/**
 * 故障码定义和处理（根据协议文档v1.10）
 */

#ifndef FAULTCODE_H
#define FAULTCODE_H

#include "common/GlobalDefine.h"
#include <string>
#include <vector>

// 4CP设备故障码位定义（对应寄存器1006H）
enum class FaultBit {
    FAULT_BIT0 = 0, // 新风风机异常
    FAULT_BIT1 = 1, // 回风风机异常
    FAULT_BIT2 = 2, // 预留
    FAULT_BIT3 = 3, // 预留
    FAULT_BIT4 = 4, // 预留
    FAULT_BIT5 = 5, // 预留
    FAULT_BIT6 = 6, // 预留
    FAULT_BIT7 = 7, // 预留
    FAULT_BIT8 = 8, // 预留
    FAULT_BIT9 = 9, // 预留
    FAULT_BIT10 = 10, // 预留
    FAULT_BIT11 = 11, // 预留
    FAULT_BIT12 = 12, // 预留
    FAULT_BIT13 = 13, // 预留
    FAULT_BIT14 = 14, // 预留
    FAULT_BIT15 = 15 // 预留
};

namespace BeiAng4CPFaultCode {
// 使用enum class定义，访问时需要使用FaultBit::FAULT_BIT0
}

// 单个故障信息
struct FaultInfo {
    int bitPosition; // 故障位位置
    std::string faultName; // 故障名称
    std::string description; // 故障描述
    bool isActive; // 故障是否激活

    FaultInfo()
        : bitPosition(0)
        , isActive(false)
    {
    }

    FaultInfo(int bit, const std::string& name, const std::string& desc)
        : bitPosition(bit)
        , faultName(name)
        , description(desc)
        , isActive(false)
    {
    }
};

// 故障码处理器类
class FaultCodeHandler {
public:
    FaultCodeHandler();
    ~FaultCodeHandler() = default;

    // 解析故障码寄存器值
    void parseFaultCodes(uint16_t faultCode1, uint16_t faultCode2 = 0);

    // 检查是否有故障
    bool hasFault() const { return !m_activeFaults.empty(); }

    // 检查特定故障位
    bool isFaultActive(FaultBit bit) const;

    // 获取所有激活的故障
    const std::vector<FaultInfo>& getActiveFaults() const { return m_activeFaults; }

    // 获取所有可能的故障定义
    static std::vector<FaultInfo> getAllFaultDefinitions();

    // 获取故障描述
    std::string getFaultDescription(FaultBit bit) const;

    // 清除所有故障
    void clearFaults();

    // 生成故障报告
    std::string generateFaultReport() const;

private:
    std::vector<FaultInfo> m_activeFaults; // 当前激活的故障列表
    uint16_t m_faultCode1; // 当前故障码1
    uint16_t m_faultCode2; // 当前故障码2

    // 初始化故障定义
    void initializeFaultDefinitions();

    // 检查并添加激活的故障
    void checkAndAddFault(uint16_t faultCode, FaultBit bit, const std::string& name, const std::string& desc);
};

#endif // FAULTCODE_H
