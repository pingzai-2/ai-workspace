#include "BeiAng4CPGateway.h"
#include "common/ProtocolBitWords.h"

#include <cmath>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>

namespace {

bool nearlyEqual(float left, float right)
{
    return std::fabs(left - right) < 0.001f;
}

bool testFixedOffsetsAndRawFields()
{
    BeiAng4CPGateway gateway(nullptr, "unused");
    BeiAng4CPGateway::RawRegisterCache raw;
    raw.holdingValid = true;
    raw.inputValid = true;
    raw.discreteValid = true;

    raw.holdingRegs[0] = 1;       // 1000H 总开关
    raw.holdingRegs[7] = 1;       // 1007H 语义待确认，只对外发布 raw
    raw.holdingRegs[9] = 23;      // 1009H 预留，只对外发布 raw
    raw.holdingRegs[18] = 1;      // 1012H IEF
    raw.holdingRegs[40] = 321;    // 1028H 单位待确认，只对外发布 raw

    raw.inputRegs[0] = 0x4241;                         // 2000H "BA"
    raw.inputRegs[1] = 0;                              // 2001H 4CP
    raw.inputRegs[2] = 0x0121;                         // 2002H 编码待确认
    raw.inputRegs[13] = static_cast<uint16_t>(-55);    // 200DH -5.5℃
    raw.inputRegs[14] = 61;                            // 200EH
    raw.inputRegs[15] = 42;                            // 200FH
    raw.inputRegs[16] = 777;                           // 2010H
    raw.inputRegs[36] = 0x0005;                        // 2024H 位含义待确认

    raw.discreteInputs[3] = 1;
    raw.discreteInputs[32] = 1;
    raw.discreteInputs[36] = 1; // bit36 除霜中
    raw.discreteInputs[64] = 1;
    for (uint16_t bit = 0; bit < BeiAng4CPGateway::RawRegisterCache::DISCRETE_COUNT; ++bit) {
        ProtocolData::bit_word_set(raw.discreteWords, bit, raw.discreteInputs[bit]);
    }

    GatewayGeneralDataStructure parsed;
    if (!gateway.parseRawDeviceData(raw, parsed)) {
        return false;
    }

    if (!parsed.getControlStatus().switchOn
        || !parsed.getControlStatus().iefPurification
        || parsed.getDeviceInfo().factoryFlag != "BA"
        || !nearlyEqual(parsed.getRA1Sensor().temperature, -5.5f)
        || parsed.getRA1Sensor().humidity != 61
        || parsed.getRA1Sensor().pm25 != 42
        || parsed.getRA1Sensor().co2 != 777
        || parsed.getDrainageSystem().inletFloatRaw != 0x0005
        || !parsed.getCapabilityFlags().hasIefPurification
        || !parsed.getCirculationPump().pumpStatus
        || !parsed.getCompressorStatus().defrosting) {
        return false;
    }

    const nlohmann::json json = nlohmann::json::parse(parsed.toJson());
    return json["deviceInfo"]["versionRaw"] == 0x0121
        && json["deviceInfo"]["version"] == "2.89"
        && json["controlStatus"]["runModeRaw"] == 1
        && !json["controlStatus"].contains("runMode")
        && json["deviceControlParams"]["exhaustFanGearRaw"] == 23
        && json["deviceControlParams"]["compressorEevRaw"] == 321
        && json["drainageSystem"]["inletFloatRaw"] == 0x0005;
}

bool testIncompleteSnapshotIsRejected()
{
    BeiAng4CPGateway gateway(nullptr, "unused");
    BeiAng4CPGateway::RawRegisterCache raw;
    raw.holdingValid = true;
    GatewayGeneralDataStructure parsed;
    return !gateway.parseRawDeviceData(raw, parsed);
}

bool testHoldingModuleGroupIsAppliedAsOneMirror()
{
    uint16_t holding[BeiAng4CPGateway::RawRegisterCache::HOLDING_COUNT] = {0};
    holding[1] = 1; // 1001H 新风
    holding[2] = 0; // 1002H 超净
    holding[3] = 1; // 1003H 调湿；允许与新风同时开启

    GatewayGeneralDataStructure parsed;
    BeiAng4CPGateway::applyHoldingRegisterData(holding, parsed);
    const ControlStatus& first = parsed.getControlStatus();
    if (!first.freshAirModuleOn || first.superPureOn
        || !first.humidityModuleOn) {
        return false;
    }

    // 设备读回属于事实。即使三个互斥字段同时为 1，解析层也不得
    // 套用写入策略进行纠正，必须让业务快照看到同一组实际值。
    holding[1] = 1;
    holding[2] = 1;
    holding[3] = 1;
    BeiAng4CPGateway::applyHoldingRegisterData(holding, parsed);
    const ControlStatus& second = parsed.getControlStatus();
    return second.freshAirModuleOn && second.superPureOn
        && second.humidityModuleOn;
}

bool testV122HoldingLayout()
{
    uint16_t holding[BeiAng4CPGateway::RawRegisterCache::HOLDING_COUNT] = {0};
    holding[6] = 1;   // 1006H 一键离家开关
    holding[7] = 5;   // 1007H 睡眠模式
    holding[10] = 4;  // 100AH 整机运行模式：温润
    holding[27] = 2026;                                        // 101BH 年
    holding[28] = static_cast<uint16_t>((8 << 8) | 31);        // 101CH 月8 日31
    holding[29] = static_cast<uint16_t>((14 << 8) | 5);        // 101DH 时14 分5
    holding[30] = static_cast<uint16_t>((30 << 8) | 1);        // 101EH 秒30 周1
    holding[31] = 0;                                           // 101FH 24小时制
    holding[43] = 1; // 102BH 高压开关
    holding[48] = 100; // 1030H 厂测模式
    holding[65] = 610; // 1041H FAN1外循环1档
    holding[71] = 480; // 1047H FAN1内循环1档
    holding[113] = 1;  // 1071H 风阀1方向
    holding[116] = 2000; // 1074H 风阀1步数

    GatewayGeneralDataStructure parsed;
    BeiAng4CPGateway::applyHoldingRegisterData(holding, parsed);
    const ControlStatus& control = parsed.getControlStatus();
    const RtcTimeData& rtc = parsed.getRtcTime();
    const FactoryTestSettings& factory = parsed.getFactoryTestSettings();
    const FanFlowData& flow = parsed.getFanFlow();
    const DamperControlData& damper = parsed.getDamperControl();

    return control.leaveHomeOn
        && static_cast<int>(control.runMode) == 5
        && control.wholeUnitRunMode == 4
        && rtc.year == 2026 && rtc.month == 8 && rtc.day == 31
        && rtc.hour == 14 && rtc.minute == 5
        && rtc.second == 30 && rtc.week == 1 && rtc.format == 0
        && factory.highPressureSwitchOn && !factory.lowPressureSwitchOn
        && parsed.getDeviceInfo().factoryTestActive
        && flow.fan1ExternalFlow[0] == 610
        && flow.fan1InternalFlow[0] == 480
        && damper.damper1Direction && damper.damper1Steps == 2000;
}

bool testV122InputLayout()
{
    BeiAng4CPGateway gateway(nullptr, "unused");
    BeiAng4CPGateway::RawRegisterCache raw;
    raw.holdingValid = true;
    raw.inputValid = true;
    raw.discreteValid = false;

    raw.inputRegs[25] = 123;  // 2019H TVOC：1.23 mg/m³
    raw.inputRegs[26] = 8;    // 201AH 甲醛：0.08 mg/m³
    raw.inputRegs[29] = 2;    // 201DH 自动模式时显示全热新风
    raw.inputRegs[30] = static_cast<uint16_t>(-125); // 201EH 进风口 -12.5℃
    raw.inputRegs[31] = 55;   // 201FH 进风口湿度
    raw.inputRegs[34] = 2450; // 2022H 高压 24.5bar
    raw.inputRegs[35] = 980;  // 2023H 低压 9.8bar
    raw.inputRegs[43] = static_cast<uint16_t>(801); // 202BH 排气 80.1℃
    // 2030H-203BH 主控板版本时间字符串 "v1.22"
    const char version[24] = "v1.22";
    for (int i = 0; i < 12; i++) {
        raw.inputRegs[48 + i] = static_cast<uint16_t>(
            (static_cast<uint8_t>(version[i * 2]) << 8)
            | static_cast<uint8_t>(version[i * 2 + 1]));
    }

    GatewayGeneralDataStructure parsed;
    if (!gateway.parseRawDeviceData(raw, parsed)) {
        return false;
    }
    return nearlyEqual(parsed.getAirQuality().tvoc, 1.23f)
        && nearlyEqual(parsed.getAirQuality().formaldehyde, 0.08f)
        && parsed.getControlStatus().autoCirculationDisplay == 2
        && nearlyEqual(parsed.getInletAirSensor().temperature, -12.5f)
        && parsed.getInletAirSensor().humidity == 55
        && nearlyEqual(parsed.getCompressorStatus().highPressure, 24.5f)
        && nearlyEqual(parsed.getCompressorStatus().lowPressure, 9.8f)
        && nearlyEqual(parsed.getCompressorStatus().dischargeTemperature, 80.1f)
        && parsed.getDeviceInfo().controllerVersionTime == "v1.22";
}

} // namespace

int main()
{
    if (!testFixedOffsetsAndRawFields()
        || !testIncompleteSnapshotIsRejected()
        || !testHoldingModuleGroupIsAppliedAsOneMirror()
        || !testV122HoldingLayout()
        || !testV122InputLayout()) {
        std::cerr << "Modbus snapshot parser tests failed" << std::endl;
        return 1;
    }
    std::cout << "Modbus snapshot parser tests passed" << std::endl;
    return 0;
}
