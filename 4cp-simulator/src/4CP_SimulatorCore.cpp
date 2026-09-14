#include "4CP_SimulatorCore.h"
#include "4CP_Protocol.h"
#include "Logger.h"
#include "modbus.h"

#include <cerrno>
#include <chrono>
#include <iostream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace _4CP {

namespace {

constexpr int kProductRegisterLimit = 50;
constexpr int kFatalErrorLimit = 3;

uint16_t ReadRequestWord(const uint8_t* request, int offset) {
    return static_cast<uint16_t>(
        (static_cast<uint16_t>(request[offset]) << 8)
        | request[offset + 1]);
}

char ToLibmodbusParity(uint8_t parity) {
    if (parity == 1) {
        return 'O';
    }
    if (parity == 2) {
        return 'E';
    }
    return 'N';
}

std::string ToWindowsPortPath(const std::string& port) {
    if (port.rfind("\\\\.\\", 0) == 0) {
        return port;
    }
    return "\\\\.\\" + port;
}

bool IsSupportedFunction(uint8_t functionCode) {
    return functionCode == MODBUS_FC_READ_DISCRETE_INPUTS
        || functionCode == MODBUS_FC_READ_HOLDING_REGISTERS
        || functionCode == MODBUS_FC_READ_INPUT_REGISTERS
        || functionCode == MODBUS_FC_WRITE_SINGLE_REGISTER
        || functionCode == MODBUS_FC_WRITE_MULTIPLE_REGISTERS;
}

bool IsRecoverableFrameError(int errorCode) {
    return errorCode == EMBBADCRC
        || errorCode == EMBBADDATA
        || errorCode == EMBBADEXC;
}

} // namespace

SimulatorCore::SimulatorCore()
    : context_(nullptr)
    , mapping_(nullptr)
    , connected_(false)
    , isRunning_(false)
#ifdef _WIN32
    , communicationThreadId_(0)
#endif
{
}

SimulatorCore::~SimulatorCore() {
    Stop();
}

bool SimulatorCore::Start(const SerialConfig& config) {
    if (isRunning_ || communicationThread_.joinable()) {
        LOG("Simulator is already running");
        return false;
    }

    uint8_t deviceAddress = 0;
    {
        std::lock_guard<std::mutex> lock(devicesMutex_);
        if (devices_.size() != 1) {
            std::cerr
                << "One simulator process must contain exactly one device"
                << std::endl;
            return false;
        }
        deviceAddress = devices_.begin()->first;
    }

    const std::string portPath = ToWindowsPortPath(config.port);
    context_ = modbus_new_rtu(
        portPath.c_str(),
        static_cast<int>(config.baudrate),
        ToLibmodbusParity(config.parity),
        config.databits,
        config.stopbits);
    if (context_ == nullptr) {
        std::cerr << "Failed to create libmodbus RTU context" << std::endl;
        return false;
    }

    if (modbus_set_slave(context_, deviceAddress) == -1
        || modbus_set_byte_timeout(context_, 0, 50000) == -1
        || modbus_set_response_timeout(context_, 0, 50000) == -1
        || modbus_set_error_recovery(
               context_, MODBUS_ERROR_RECOVERY_PROTOCOL) == -1
        || !CreateMapping()) {
        std::cerr << "Failed to configure libmodbus RTU context: "
                  << modbus_strerror(errno) << std::endl;
        DestroyModbus();
        return false;
    }

    if (modbus_connect(context_) == -1) {
#ifdef _WIN32
        const unsigned long systemError =
            static_cast<unsigned long>(GetLastError());
        std::cerr << "Failed to open serial port " << config.port
                  << ", Windows error: " << systemError << std::endl;
#else
        std::cerr << "Failed to open serial port " << config.port
                  << ": " << modbus_strerror(errno) << std::endl;
#endif
        DestroyModbus();
        return false;
    }
    connected_ = true;

    isRunning_ = true;
    communicationThread_ = std::thread(&SimulatorCore::CommunicationLoop, this);
#ifdef _WIN32
    while (communicationThreadId_.load() == 0 && isRunning_) {
        std::this_thread::yield();
    }
#endif
    LOG("[MODBUS RTU] libmodbus slave started on " << config.port
        << " at " << config.baudrate << " baud");
    return true;
}

void SimulatorCore::Stop() {
    const bool wasRunning = isRunning_.exchange(false);

    if (communicationThread_.joinable()) {
#ifdef _WIN32
        // libmodbus 3.1.2 的从机接收会阻塞等待首字节；停止时只取消该通信线程的同步 I/O。
        const unsigned long threadId = communicationThreadId_.load();
        HANDLE threadHandle = OpenThread(THREAD_TERMINATE, FALSE, threadId);
        if (threadHandle != nullptr) {
            CancelSynchronousIo(threadHandle);
            CloseHandle(threadHandle);
        }
#endif
        communicationThread_.join();
    }
    DestroyModbus();

    if (wasRunning) {
        LOG("4CP Simulator stopped");
    }
}

bool SimulatorCore::AddDevice(
    uint8_t addr,
    std::shared_ptr<ModbusRegisterDevice> device) {
    std::lock_guard<std::mutex> lock(devicesMutex_);
    if (devices_.find(addr) != devices_.end()) {
        std::cerr << "Device with address " << static_cast<int>(addr)
                  << " already exists" << std::endl;
        return false;
    }

    devices_[addr] = std::move(device);
    LOG("[MODBUS RTU] Device added: addr=0x" << std::hex
        << static_cast<int>(addr) << std::dec);
    return true;
}

void SimulatorCore::RemoveDevice(uint8_t addr) {
    std::lock_guard<std::mutex> lock(devicesMutex_);
    const auto it = devices_.find(addr);
    if (it != devices_.end()) {
        devices_.erase(it);
        LOG("[MODBUS RTU] Device removed: addr=0x" << std::hex
            << static_cast<int>(addr) << std::dec);
    }
}

std::shared_ptr<ModbusRegisterDevice> SimulatorCore::GetDevice(uint8_t addr) {
    std::lock_guard<std::mutex> lock(devicesMutex_);

    if (addr == MODBUS_BROADCAST_ADDRESS && !devices_.empty()) {
        return devices_.begin()->second;
    }
    const auto it = devices_.find(addr);
    return (it == devices_.end()) ? nullptr : it->second;
}

void SimulatorCore::UpdateAllDevices() {
    std::lock_guard<std::mutex> lock(devicesMutex_);
    for (auto& pair : devices_) {
        pair.second->UpdateSimulation();
    }
}

void SimulatorCore::SetRequestCompletedCallback(
    RequestCompletedCallback callback) {
    requestCompletedCallback_ = std::move(callback);
}

bool SimulatorCore::CreateMapping() {
    // 3.1.2 按协议绝对地址索引映射；未定义区域保持零，不进入业务处理。
    mapping_ = modbus_mapping_new(
        0,
        DI_CAPABILITY_START + DISCRETE_BIT_COUNT,
        HR_LAST_REGISTER + 1,
        IR_LAST_REGISTER + 1);
    return mapping_ != nullptr;
}

void SimulatorCore::DestroyModbus() {
    if (mapping_ != nullptr) {
        modbus_mapping_free(mapping_);
        mapping_ = nullptr;
    }
    if (context_ != nullptr) {
        if (connected_) {
            modbus_close(context_);
            connected_ = false;
        }
        modbus_free(context_);
        context_ = nullptr;
    }
}

void SimulatorCore::CopyDeviceToMapping(
    const std::shared_ptr<ModbusRegisterDevice>& device) {
    device->CopyDataImage(
        mapping_->tab_registers + HR_TOTAL_SWITCH,
        mapping_->tab_input_registers + IR_FACTORY_ID,
        mapping_->tab_input_bits + DI_CAPABILITY_START);
}

bool SimulatorCore::ExceedsProductLimit(
    const uint8_t* request,
    int requestLength) const {
    if (requestLength < 8) {
        return false;
    }

    const uint8_t functionCode = request[1];
    if (functionCode != MODBUS_FC_READ_HOLDING_REGISTERS
        && functionCode != MODBUS_FC_READ_INPUT_REGISTERS
        && functionCode != MODBUS_FC_WRITE_MULTIPLE_REGISTERS) {
        return false;
    }
    return ReadRequestWord(request, 4) > kProductRegisterLimit;
}

bool SimulatorCore::ValidateHoldingWriteRequest(
    const std::shared_ptr<ModbusRegisterDevice>& device,
    const uint8_t* request,
    int requestLength) const {
    if (requestLength < 8) {
        return true;
    }

    const uint8_t functionCode = request[1];
    const uint16_t startAddress = ReadRequestWord(request, 2);
    if (functionCode == MODBUS_FC_WRITE_SINGLE_REGISTER) {
        if (requestLength != 8) {
            return false;
        }
        const uint16_t value = ReadRequestWord(request, 4);
        return device->ValidateHoldingWrite(startAddress, 1, &value);
    }

    if (functionCode != MODBUS_FC_WRITE_MULTIPLE_REGISTERS) {
        return true;
    }
    if (requestLength < 9) {
        return false;
    }

    const uint16_t registerCount = ReadRequestWord(request, 4);
    const uint8_t byteCount = request[6];
    if (registerCount == 0 || registerCount > kProductRegisterLimit
        || byteCount != registerCount * 2
        || requestLength != 9 + byteCount) {
        return false;
    }

    std::vector<uint16_t> values(registerCount);
    for (uint16_t index = 0; index < registerCount; ++index) {
        values[index] = ReadRequestWord(request, 7 + index * 2);
    }
    return device->ValidateHoldingWrite(
        startAddress, registerCount, values.data());
}

void SimulatorCore::ApplyHoldingWrite(
    const std::shared_ptr<ModbusRegisterDevice>& device,
    const uint8_t* request,
    int requestLength) {
    const uint8_t functionCode = request[1];
    const uint16_t startAddress = ReadRequestWord(request, 2);

    if (functionCode == MODBUS_FC_WRITE_SINGLE_REGISTER
        && requestLength == 8) {
        if (startAddress >= HR_TOTAL_SWITCH
            && startAddress <= HR_LAST_REGISTER) {
            const uint16_t value = ReadRequestWord(request, 4);
            const bool applied =
                device->ApplyHoldingWrite(startAddress, 1, &value);
            LOG("[MODBUS WRITE] FC06 start=0x" << std::hex << startAddress
                << ", value=0x" << value
                << ", applied=" << (applied ? "yes" : "no")
                << std::dec);
        }
        return;
    }

    if (functionCode != MODBUS_FC_WRITE_MULTIPLE_REGISTERS
        || requestLength < 9) {
        return;
    }

    const uint16_t registerCount = ReadRequestWord(request, 4);
    const uint8_t byteCount = request[6];
    if (registerCount == 0 || registerCount > kProductRegisterLimit
        || byteCount != registerCount * 2
        || requestLength != 9 + byteCount) {
        return;
    }

    const uint32_t endAddress =
        static_cast<uint32_t>(startAddress) + registerCount - 1u;
    if (startAddress < HR_TOTAL_SWITCH || endAddress > HR_LAST_REGISTER) {
        return;
    }

    // libmodbus 负责校验和应答；设备业务镜像直接采用本次请求的数据，
    // 不依赖 modbus_reply 对内部 mapping 的副作用。
    std::vector<uint16_t> values(registerCount);
    for (uint16_t index = 0; index < registerCount; ++index) {
        values[index] = ReadRequestWord(request, 7 + index * 2);
    }
    const bool applied = device->ApplyHoldingWrite(
        startAddress, registerCount, values.data());

    // 应答已经发送完成；这里只输出一条汇总日志，避免逐寄存器日志拖慢下一帧。
    LOG("[MODBUS WRITE] FC10 start=0x" << std::hex << startAddress
        << ", end=0x" << static_cast<uint16_t>(endAddress)
        << ", count=" << std::dec << registerCount
        << ", applied=" << (applied ? "yes" : "no")
        << ", total=" << device->GetRegister(HR_TOTAL_SWITCH)
        << ", fresh=" << device->GetRegister(HR_FRESH_MODULE_SWITCH)
        << ", pure=" << device->GetRegister(HR_CLEAN_MODE_SWITCH)
        << ", humidity=" << device->GetRegister(HR_HUMIDITY_MODULE_SWITCH));
}

void SimulatorCore::CommunicationLoop() {
#ifdef _WIN32
    communicationThreadId_ = GetCurrentThreadId();
#endif
    uint8_t request[MODBUS_RTU_MAX_ADU_LENGTH] = {};
    int consecutiveFatalErrors = 0;

    while (isRunning_) {
        errno = 0;
        const int requestLength = modbus_receive(context_, request);
        if (requestLength == 0) {
            continue;
        }
        if (requestLength == -1) {
            const int errorCode = errno;
            if (!isRunning_) {
                break;
            }
            if (errorCode == ETIMEDOUT) {
                continue;
            }

            modbus_flush(context_);
            if (IsRecoverableFrameError(errorCode)) {
                LOG("[MODBUS RTU] Invalid frame discarded: "
                    << modbus_strerror(errorCode));
                continue;
            }

            ++consecutiveFatalErrors;
            LOG("[MODBUS RTU] Serial receive failed ("
                << consecutiveFatalErrors << "/" << kFatalErrorLimit
                << "): " << modbus_strerror(errorCode));
            if (consecutiveFatalErrors >= kFatalErrorLimit) {
                isRunning_ = false;
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            continue;
        }

        consecutiveFatalErrors = 0;
        const uint8_t deviceAddress = request[0];
        const uint8_t functionCode = request[1];
        const std::shared_ptr<ModbusRegisterDevice> device =
            GetDevice(deviceAddress);
        if (!device) {
            continue;
        }

        const auto requestReadyAt = std::chrono::steady_clock::now();
        CopyDeviceToMapping(device);

        int replyLength = 0;
        bool holdingWriteAccepted = false;
        if (!IsSupportedFunction(functionCode)) {
            replyLength = modbus_reply_exception(
                context_, request, MODBUS_EXCEPTION_ILLEGAL_FUNCTION);
        } else if (ExceedsProductLimit(request, requestLength)) {
            replyLength = modbus_reply_exception(
                context_, request, MODBUS_EXCEPTION_ILLEGAL_DATA_VALUE);
        } else if (!ValidateHoldingWriteRequest(
                       device, request, requestLength)) {
            replyLength = modbus_reply_exception(
                context_, request, MODBUS_EXCEPTION_ILLEGAL_DATA_VALUE);
        } else {
            replyLength = modbus_reply(
                context_, request, requestLength, mapping_);
            holdingWriteAccepted =
                functionCode == MODBUS_FC_WRITE_SINGLE_REGISTER
                || functionCode == MODBUS_FC_WRITE_MULTIPLE_REGISTERS;
        }

        const auto replyFinishedAt = std::chrono::steady_clock::now();
        if (replyLength == -1) {
            LOG("[MODBUS RTU] Reply failed: " << modbus_strerror(errno));
            isRunning_ = false;
            break;
        }

        if (holdingWriteAccepted) {
            ApplyHoldingWrite(device, request, requestLength);
        }
        if (requestCompletedCallback_) {
            requestCompletedCallback_(
                deviceAddress,
                functionCode,
                requestLength,
                replyLength,
                std::chrono::duration_cast<std::chrono::microseconds>(
                    replyFinishedAt - requestReadyAt));
        }
    }
#ifdef _WIN32
    communicationThreadId_ = 0;
#endif
}

} // namespace _4CP
