/**
 * 故障码处理实现
 */

#include "FaultCode.h"
#include <iomanip>
#include <sstream>

using namespace std;

FaultCodeHandler::FaultCodeHandler()
    : m_faultCode1(0)
    , m_faultCode2(0)
{
    initializeFaultDefinitions();
}

void FaultCodeHandler::parseFaultCodes(uint16_t faultCode1, uint16_t faultCode2)
{
    m_faultCode1 = faultCode1;
    m_faultCode2 = faultCode2;
    m_activeFaults.clear();

    // 解析故障码1的每一位
    checkAndAddFault(faultCode1, FaultBit::FAULT_BIT0, "新风风机异常", "新风风机运行异常或故障");
    checkAndAddFault(faultCode1, FaultBit::FAULT_BIT1, "回风风机异常", "回风风机运行异常或故障");

    // 预留位（目前未使用）
    for (int i = 2; i <= 15; i++) {
        if (faultCode1 & (1 << i)) {
            m_activeFaults.push_back(FaultInfo(i, "预留故障位" + to_string(i), "预留故障描述"));
        }
    }

    // 如果有故障码2，也可以解析（目前协议未定义）
    if (faultCode2 != 0) {
        for (int i = 0; i <= 15; i++) {
            if (faultCode2 & (1 << i)) {
                m_activeFaults.push_back(FaultInfo(i + 16, "故障码2-位" + to_string(i), "故障码2的位" + to_string(i)));
            }
        }
    }
}

bool FaultCodeHandler::isFaultActive(FaultBit bit) const
{
    return (m_faultCode1 & (1 << static_cast<int>(bit))) != 0;
}

vector<FaultInfo> FaultCodeHandler::getAllFaultDefinitions()
{
    vector<FaultInfo> definitions;

    definitions.push_back(FaultInfo(0, "新风风机异常", "新风风机运行异常或故障"));
    definitions.push_back(FaultInfo(1, "回风风机异常", "回风风机运行异常或故障"));

    // 预留位
    for (int i = 2; i <= 15; i++) {
        definitions.push_back(FaultInfo(i, "预留位" + to_string(i), "预留故障位"));
    }

    return definitions;
}

string FaultCodeHandler::getFaultDescription(FaultBit bit) const
{
    switch (bit) {
    case FaultBit::FAULT_BIT0:
        return "新风风机异常：新风风机运行异常或故障";
    case FaultBit::FAULT_BIT1:
        return "回风风机异常：回风风机运行异常或故障";
    default:
        return "预留故障位";
    }
}

void FaultCodeHandler::clearFaults()
{
    m_faultCode1 = 0;
    m_faultCode2 = 0;
    m_activeFaults.clear();
}

string FaultCodeHandler::generateFaultReport() const
{
    if (!hasFault()) {
        return "无故障";
    }

    ostringstream report;
    report << "故障码1: 0x" << hex << setw(4) << setfill('0') << m_faultCode1 << dec << "\n";
    if (m_faultCode2 != 0) {
        report << "故障码2: 0x" << hex << setw(4) << setfill('0') << m_faultCode2 << dec << "\n";
    }
    report << "激活的故障数量: " << m_activeFaults.size() << "\n\n";

    for (const auto& fault : m_activeFaults) {
        report << "  - [" << fault.bitPosition << "] " << fault.faultName
               << ": " << fault.description << "\n";
    }

    return report.str();
}

void FaultCodeHandler::initializeFaultDefinitions()
{
    // 故障定义已在parseFaultCodes中处理
}

void FaultCodeHandler::checkAndAddFault(uint16_t faultCode, FaultBit bit, const string& name, const string& desc)
{
    if (faultCode & (1 << static_cast<int>(bit))) {
        FaultInfo info(static_cast<int>(bit), name, desc);
        info.isActive = true;
        m_activeFaults.push_back(info);
    }
}
