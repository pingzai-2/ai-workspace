#include "4CP_Protocol.h"
#include "DeviceSimulator.h"

#include <cstdint>
#include <iostream>
#include <vector>

namespace {

using namespace _4CP;

ModbusFrame makeRequest(uint8_t functionCode, std::vector<uint8_t> data)
{
    ModbusFrame frame;
    frame.deviceAddress = DEVICE_ADDRESS_4CP;
    frame.functionCode = functionCode;
    frame.data = std::move(data);
    return frame;
}

bool isException(
    const std::vector<uint8_t>& response,
    uint8_t functionCode,
    ModbusExceptionCode exceptionCode)
{
    return response.size() == 5
        && response[1] == static_cast<uint8_t>(functionCode | 0x80u)
        && response[2] == static_cast<uint8_t>(exceptionCode)
        && ModbusProtocol::ValidateCRC(response);
}

bool testDiscreteMirror()
{
    ModbusRegisterDevice device;
    if (!device.SetDiscreteInput(DI_BIT_HAS_STERILIZE, true)
        || !device.SetDiscreteInput(DI_BIT_COMPRESSOR_STATUS, true)
        || device.SetDiscreteInput(DISCRETE_BIT_COUNT, true)) {
        return false;
    }

    const auto capabilityResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
        {0x30, 0x00, 0x00, 0x07}));
    if (capabilityResponse.size() != 6 || capabilityResponse[2] != 1
        || (capabilityResponse[3] & 0x1Fu) != 0x1Fu
        || !ModbusProtocol::ValidateCRC(capabilityResponse)) {
        return false;
    }

    const auto statusResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
        {0x30, 0x20, 0x00, 0x04}));
    return statusResponse.size() == 6
        && statusResponse[2] == 1
        && statusResponse[3] == 0x08
        && device.GetDiscreteInput(DI_BIT_COMPRESSOR_STATUS) == 1
        && ModbusProtocol::ValidateCRC(statusResponse);
}

bool testDiscreteBounds()
{
    ModbusRegisterDevice device;
    const auto beforeStart = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
        {0x2F, 0xFF, 0x00, 0x01}));
    const auto pastEnd = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
        {0x30, 0x4C, 0x00, 0x02}));
    return isException(
               beforeStart,
               static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
               ModbusExceptionCode::ILLEGAL_DATA_ADDRESS)
        && isException(
               pastEnd,
               static_cast<uint8_t>(ModbusFunctionCode::READ_DISCRETE_INPUTS),
               ModbusExceptionCode::ILLEGAL_DATA_ADDRESS);
}

bool testFunctionCodeRegionsAndLimit()
{
    ModbusRegisterDevice device;
    const auto holdingReadsInput = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS),
        {0x20, 0x00, 0x00, 0x01}));
    const auto inputReadsHolding = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS),
        {0x10, 0x00, 0x00, 0x01}));
    const auto tooMany = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS),
        {0x10, 0x00, 0x00, 0x33}));
    return isException(
               holdingReadsInput,
               static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS),
               ModbusExceptionCode::ILLEGAL_DATA_ADDRESS)
        && isException(
               inputReadsHolding,
               static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS),
               ModbusExceptionCode::ILLEGAL_DATA_ADDRESS)
        && isException(
               tooMany,
               static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS),
               ModbusExceptionCode::ILLEGAL_DATA_VALUE);
}

bool testMultipleWriteIsAtomic()
{
    ModbusRegisterDevice device;
    const uint16_t before = device.GetRegister(HR_DAMPER3_STEPS_SET);
    const auto response = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS),
        {0x10, 0x76, 0x00, 0x02, 0x04, 0x00, 0x01, 0x00, 0x02}));
    return isException(
               response,
               static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS),
               ModbusExceptionCode::ILLEGAL_DATA_ADDRESS)
        && device.GetRegister(HR_DAMPER3_STEPS_SET) == before;
}

bool testHoldingWritesCanBeReadBack()
{
    ModbusRegisterDevice device;
    const auto freshResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::WRITE_SINGLE_REGISTER),
        {0x10, 0x01, 0x00, 0x01}));
    if (freshResponse.size() != 8
        || device.GetRegister(HR_FRESH_MODULE_SWITCH) != 1
        || device.GetRegister(HR_TOTAL_SWITCH) != 1) {
        return false;
    }

    const auto singleResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::WRITE_SINGLE_REGISTER),
        {0x10, 0x08, 0x00, 0x04}));
    if (singleResponse.size() != 8
        || !ModbusProtocol::ValidateCRC(singleResponse)
        || device.GetRegister(HR_FAN_GEAR) != 4) {
        return false;
    }

    const auto multipleResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::WRITE_MULTIPLE_REGISTERS),
        {0x10, 0x0F, 0x00, 0x02, 0x04, 0x00, 0x3C, 0x00, 0xFA}));
    if (multipleResponse.size() != 8
        || !ModbusProtocol::ValidateCRC(multipleResponse)) {
        return false;
    }

    const auto readResponse = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_HOLDING_REGISTERS),
        {0x10, 0x08, 0x00, 0x09}));
    return readResponse.size() == 23
        && readResponse[2] == 18
        && readResponse[3] == 0x00
        && readResponse[4] == 0x04
        && readResponse[17] == 0x00
        && readResponse[18] == 0x3C
        && readResponse[19] == 0x00
        && readResponse[20] == 0xFA
        && ModbusProtocol::ValidateCRC(readResponse);
}

bool testModuleInterlockAndAutomaticTotalSwitch()
{
    ModbusRegisterDevice device;
    const uint16_t freshAndHumidity[] = {1, 0, 1};
    if (!device.ApplyHoldingWrite(
            HR_FRESH_MODULE_SWITCH, 3, freshAndHumidity)
        || device.GetRegister(HR_TOTAL_SWITCH) != 1
        || device.GetRegister(HR_FRESH_MODULE_SWITCH) != 1
        || device.GetRegister(HR_CLEAN_MODE_SWITCH) != 0
        || device.GetRegister(HR_HUMIDITY_MODULE_SWITCH) != 1) {
        return false;
    }

    const uint16_t enabled = 1;
    if (!device.ApplyHoldingWrite(HR_CLEAN_MODE_SWITCH, 1, &enabled)
        || device.GetRegister(HR_FRESH_MODULE_SWITCH) != 0
        || device.GetRegister(HR_CLEAN_MODE_SWITCH) != 1
        || device.GetRegister(HR_HUMIDITY_MODULE_SWITCH) != 0
        || device.GetRegister(HR_TOTAL_SWITCH) != 1) {
        return false;
    }

    if (!device.ApplyHoldingWrite(HR_FRESH_MODULE_SWITCH, 1, &enabled)
        || device.GetRegister(HR_FRESH_MODULE_SWITCH) != 1
        || device.GetRegister(HR_CLEAN_MODE_SWITCH) != 0
        || device.GetRegister(HR_TOTAL_SWITCH) != 1) {
        return false;
    }

    // v1.22: 1000H 可直接写。1=一键开启(模块保持)；0=整机关机(模块联动清零)。
    const uint16_t invalidTotal = 2;
    if (!device.ApplyHoldingWrite(HR_TOTAL_SWITCH, 1, &enabled)
        || device.GetRegister(HR_TOTAL_SWITCH) != 1
        || device.GetRegister(HR_FRESH_MODULE_SWITCH) != 1) {
        return false;
    }

    const uint16_t disabled = 0;
    return !device.ValidateHoldingWrite(HR_TOTAL_SWITCH, 1, &invalidTotal)
        && device.ApplyHoldingWrite(HR_TOTAL_SWITCH, 1, &disabled)
        && device.GetRegister(HR_TOTAL_SWITCH) == 0
        && device.GetRegister(HR_FRESH_MODULE_SWITCH) == 0
        && device.GetRegister(HR_CLEAN_MODE_SWITCH) == 0
        && device.GetRegister(HR_HUMIDITY_MODULE_SWITCH) == 0;
}

bool testFreshControlWriteConditions()
{
    ModbusRegisterDevice device;
    const uint16_t gear = 4;
    if (device.ValidateHoldingWrite(HR_FAN_GEAR, 1, &gear)) {
        return false;
    }

    const uint16_t enabled = 1;
    if (!device.ApplyHoldingWrite(
            HR_FRESH_MODULE_SWITCH, 1, &enabled)
        || !device.ValidateHoldingWrite(HR_FAN_GEAR, 1, &gear)) {
        return false;
    }

    // v1.22: 1007H 取值 0-5；超出范围拒绝。
    const uint16_t sleepMode = 5;
    const uint16_t invalidMode = 6;
    // v1.22: 102BH-102CH、1038H-103EH 仅厂测模式可写。
    const uint16_t flowSetValue = 1234;
    const uint16_t factoryTestOn[] = {HR_FACTORY_TEST_MODE_ENABLED};
    return device.ValidateHoldingWrite(HR_FRESH_RUN_MODE, 1, &sleepMode)
        && !device.ValidateHoldingWrite(
            HR_FRESH_RUN_MODE, 1, &invalidMode)
        && !device.ValidateHoldingWrite(
            HR_FAN1_FLOW_SET, 1, &flowSetValue)
        && device.ApplyHoldingWrite(
            HR_FACTORY_TEST_MODE, 1, factoryTestOn)
        && device.ApplyHoldingWrite(HR_FAN1_FLOW_SET, 1, &flowSetValue)
        && device.GetRegister(HR_FAN1_FLOW_SET) == flowSetValue;
}

bool testAlertSimulationChangesDynamically()
{
    ModbusRegisterDevice device(DEVICE_ADDRESS_4CP, 1234);
    const uint16_t faultBits[] = {
        64, 65, 66, 68, 69, 70, 71, 72, 73, 74, 75, 76
    };
    const uint16_t remainingAddresses[] = {
        HR_FILTER1_REMAINING,
        HR_FILTER2_REMAINING,
        HR_FILTER3_REMAINING,
        HR_HUMIDIFY_MODULE_REMAINING,
        HR_IEF_CLEAN_REMAINING
    };

    uint32_t previousState = 0;
    bool hasPreviousState = false;
    bool sawDifferentState = false;
    bool sawConsecutiveNonEmptyStates = false;
    for (int round = 0; round < 20; ++round) {
        for (int index = 0; index < 10; ++index) {
            device.UpdateSimulation();
        }

        uint32_t currentState = 0;
        for (size_t index = 0;
             index < sizeof(faultBits) / sizeof(faultBits[0]); ++index) {
            if (device.GetDiscreteInput(faultBits[index]) != 0) {
                currentState |= 1u << index;
            }
        }
        for (size_t index = 0;
             index < sizeof(remainingAddresses)
                 / sizeof(remainingAddresses[0]); ++index) {
            if (device.GetRegister(remainingAddresses[index]) <= 15 * 24) {
                currentState |= 1u << (16 + index);
            }
        }

        if (hasPreviousState && currentState != previousState) {
            sawDifferentState = true;
            if (currentState != 0 && previousState != 0) {
                sawConsecutiveNonEmptyStates = true;
            }
        }
        previousState = currentState;
        hasPreviousState = true;
    }
    return sawDifferentState && sawConsecutiveNonEmptyStates;
}

bool testSimulationDoesNotOverrideModuleSwitches()
{
    ModbusRegisterDevice device(DEVICE_ADDRESS_4CP, 1234);
    const uint16_t freshAndHumidity[] = {1, 0, 1};
    if (!device.ApplyHoldingWrite(
            HR_FRESH_MODULE_SWITCH, 3, freshAndHumidity)) {
        return false;
    }

    for (int round = 0; round < 30; ++round) {
        device.UpdateSimulation();
    }

    return device.GetRegister(HR_TOTAL_SWITCH) == 1
        && device.GetRegister(HR_FRESH_MODULE_SWITCH) == 1
        && device.GetRegister(HR_CLEAN_MODE_SWITCH) == 0
        && device.GetRegister(HR_HUMIDITY_MODULE_SWITCH) == 1;
}

bool testInputIdentityCanBeRead()
{
    ModbusRegisterDevice device;
    const auto response = device.ProcessFrame(makeRequest(
        static_cast<uint8_t>(ModbusFunctionCode::READ_INPUT_REGISTERS),
        {0x20, 0x00, 0x00, 0x03}));
    return response.size() == 11
        && response[2] == 6
        && response[3] == 0x42
        && response[4] == 0x41
        && response[5] == 0x00
        && response[6] == 0x00
        && response[7] == 0x01
        && response[8] == 0x22
        && ModbusProtocol::ValidateCRC(response);
}

bool testCustomAddressIsReflectedInRegister()
{
    ModbusRegisterDevice device(DEVICE_ADDRESS_FRESH);
    return device.GetDeviceAddress() == DEVICE_ADDRESS_FRESH
        && device.GetRegister(HR_DEVICE_ADDR) == DEVICE_ADDRESS_FRESH;
}

bool testLibmodbusDataImageAdapter()
{
    ModbusRegisterDevice device;
    device.SetRegister(HR_FAN_GEAR, 4);
    device.SetDiscreteInput(DI_BIT_COMPRESSOR_STATUS, true);

    std::vector<uint16_t> holding(
        HR_LAST_REGISTER - HR_TOTAL_SWITCH + 1);
    std::vector<uint16_t> input(
        IR_LAST_REGISTER - IR_FACTORY_ID + 1);
    std::vector<uint8_t> discrete(DISCRETE_BIT_COUNT);
    device.CopyDataImage(holding.data(), input.data(), discrete.data());

    if (holding[HR_FAN_GEAR - HR_TOTAL_SWITCH] != 4
        || input[IR_FACTORY_ID - IR_FACTORY_ID] != 0x4241
        || discrete[DI_BIT_COMPRESSOR_STATUS] != 1) {
        return false;
    }

    const uint16_t writeValues[] = {60, 250};
    return device.ApplyHoldingWrite(
               HR_TARGET_HUMIDITY, 2, writeValues)
        && device.GetRegister(HR_TARGET_HUMIDITY) == 60
        && device.GetRegister(HR_TARGET_TEMP) == 250
        && !device.ApplyHoldingWrite(HR_LAST_REGISTER, 2, writeValues);
}

bool testV122NewHoldingRegisters()
{
    ModbusRegisterDevice device;
    const uint16_t damperDir = 1;
    const uint16_t damperSteps = 480;
    const uint16_t rtcYear = 2027;
    const uint16_t fan2InnerGear1 = 320;
    if (!device.ApplyHoldingWrite(HR_DAMPER1_DIR_SET, 1, &damperDir)
        || !device.ApplyHoldingWrite(HR_DAMPER1_STEPS_SET, 1, &damperSteps)
        || !device.ApplyHoldingWrite(HR_RTC_YEAR, 1, &rtcYear)
        || !device.ApplyHoldingWrite(
               static_cast<uint16_t>(HR_FAN_FLOW_SET_FIRST + 13u), 1,
               &fan2InnerGear1)) {
        return false;
    }
    // FAN2内循环1档 = 1041H + 12 + 6 = 1053H
    return device.GetRegister(HR_DAMPER1_DIR_SET) == 1
        && device.GetRegister(HR_DAMPER1_STEPS_SET) == 480
        && device.GetRegister(HR_RTC_YEAR) == 2027
        && device.GetRegister(HR_FAN_FLOW_SET_FIRST + 13u) == 320
        && device.GetRegister(HR_FAN_FLOW_SET_FIRST) == 300
        && device.GetRegister(HR_FAN_FLOW_SET_LAST) == 1800;
}

} // namespace

int main()
{
    if (!testDiscreteMirror()
        || !testDiscreteBounds()
        || !testFunctionCodeRegionsAndLimit()
        || !testMultipleWriteIsAtomic()
        || !testHoldingWritesCanBeReadBack()
        || !testModuleInterlockAndAutomaticTotalSwitch()
        || !testFreshControlWriteConditions()
        || !testAlertSimulationChangesDynamically()
        || !testSimulationDoesNotOverrideModuleSwitches()
        || !testInputIdentityCanBeRead()
        || !testCustomAddressIsReflectedInRegister()
        || !testLibmodbusDataImageAdapter()
        || !testV122NewHoldingRegisters()) {
        std::cerr << "4CP protocol tests failed" << std::endl;
        return 1;
    }
    std::cout << "4CP protocol tests passed" << std::endl;
    return 0;
}
