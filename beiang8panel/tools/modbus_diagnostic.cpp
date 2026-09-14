/**
 * Modbus 设备诊断工具
 * 用于排查 BeiAng 4CP 设备的通信问题
 */

#include <iostream>
#include <modbus/modbus.h>
#include <vector>
#include <chrono>
#include <thread>

using namespace std;

void printSeparator() {
    cout << "\n========================================\n";
}

// 测试串口连接
bool testSerialConnection(const string& port, int baudRate) {
    printSeparator();
    cout << "📡 测试串口连接: " << port << " @ " << baudRate << " baud" << endl;

    modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
    if (!modbus) {
        cout << "❌ 无法创建 Modbus 上下文" << endl;
        return false;
    }

    // 设置较短的超时
    modbus_set_response_timeout(modbus, 0, 500000);
    modbus_set_byte_timeout(modbus, 0, 50000);

    if (modbus_connect(modbus) < 0) {
        cout << "❌ 无法连接到串口: " << modbus_strerror(errno) << endl;
        modbus_free(modbus);
        return false;
    }

    cout << "✅ 串口连接成功" << endl;
    modbus_close(modbus);
    modbus_free(modbus);
    return true;
}

// 扫描可能的设备地址
void scanDeviceAddresses(const string& port, int baudRate) {
    printSeparator();
    cout << "🔍 扫描设备地址 (1-247)..." << endl;

    vector<uint8_t> foundAddresses;

    for (uint8_t slaveId = 1; slaveId <= 247; slaveId++) {
        modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
        if (!modbus) continue;

        modbus_set_slave(modbus, slaveId);
        modbus_set_response_timeout(modbus, 0, 200000); // 200ms 超时
        modbus_set_byte_timeout(modbus, 0, 50000);

        if (modbus_connect(modbus) == 0) {
            uint16_t regs[1];
            // 尝试读取寄存器 0x1000
            int rc = modbus_read_registers(modbus, 0x1000, 1, regs);

            if (rc > 0) {
                foundAddresses.push_back(slaveId);
                cout << "✅ 找到设备! 地址: " << (int)slaveId
                     << " (0x" << hex << (int)slaveId << dec << ")" << endl;
            }

            modbus_close(modbus);
        }
        modbus_free(modbus);

        // 找到设备后继续扫描一段时间，看是否有多个设备
        if (!foundAddresses.empty() && foundAddresses.size() >= 5) {
            break;
        }
    }

    if (foundAddresses.empty()) {
        cout << "❌ 未找到任何响应的设备" << endl;
        cout << "\n可能的原因:" << endl;
        cout << "  1. 设备未通电" << endl;
        cout << "  2. 串口线连接错误" << endl;
        cout << "  3. 波特率不匹配" << endl;
        cout << "  4. 设备故障" << endl;
    } else {
        cout << "\n📋 共找到 " << foundAddresses.size() << " 个设备" << endl;
        cout << "   推荐使用的地址: 0x" << hex << (int)foundAddresses[0] << dec << endl;
    }
}

// 测试特定地址的通信质量
void testCommunicationQuality(const string& port, int baudRate, uint8_t slaveId) {
    printSeparator();
    cout << "📊 测试通信质量 (地址: " << (int)slaveId
         << " / 0x" << hex << (int)slaveId << dec << ")" << endl;

    modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
    if (!modbus) {
        cout << "❌ 无法创建 Modbus 上下文" << endl;
        return;
    }

    modbus_set_slave(modbus, slaveId);
    modbus_set_response_timeout(modbus, 0, 500000);
    modbus_set_byte_timeout(modbus, 0, 50000);

    if (modbus_connect(modbus) < 0) {
        cout << "❌ 连接失败: " << modbus_strerror(errno) << endl;
        modbus_free(modbus);
        return;
    }

    int successCount = 0;
    int crcErrorCount = 0;
    int slaveErrorCount = 0;
    int timeoutCount = 0;
    int otherErrorCount = 0;
    const int testRounds = 20;

    cout << "   进行 " << testRounds << " 轮测试..." << endl;

    for (int i = 0; i < testRounds; i++) {
        uint16_t regs[23];
        int rc = modbus_read_registers(modbus, 0x1000, 23, regs);

        if (rc > 0) {
            successCount++;
        } else {
            if (errno == EMBBADCRC) {
                crcErrorCount++;
            } else if (errno == EMBBADDATA) {
                slaveErrorCount++;
            } else if (errno == ETIMEDOUT) {
                timeoutCount++;
            } else {
                otherErrorCount++;
            }
        }

        this_thread::sleep_for(chrono::milliseconds(100));
    }

    modbus_close(modbus);
    modbus_free(modbus);

    cout << "\n📈 测试结果:" << endl;
    cout << "   ✅ 成功: " << successCount << "/" << testRounds
         << " (" << (successCount * 100 / testRounds) << "%)" << endl;
    cout << "   ❌ CRC 错误: " << crcErrorCount << "/" << testRounds << endl;
    cout << "   ⚠️  从站地址错误: " << slaveErrorCount << "/" << testRounds << endl;
    cout << "   ⏱️  超时: " << timeoutCount << "/" << testRounds << endl;
    cout << "   ❓ 其他错误: " << otherErrorCount << "/" << testRounds << endl;

    if (successCount >= testRounds * 0.8) {
        cout << "\n✅ 通信质量良好" << endl;
    } else if (successCount >= testRounds * 0.5) {
        cout << "\n⚠️  通信质量一般，可能存在电气干扰" << endl;
    } else {
        cout << "\n❌ 通信质量差，需要检查硬件连接" << endl;
    }
}

// 测试不同波特率
void testBaudRates(const string& port, uint8_t slaveId) {
    printSeparator();
    cout << "🔄 测试不同波特率..." << endl;

    vector<int> baudRates = {9600, 19200, 38400, 57600, 115200};

    for (int baudRate : baudRates) {
        modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
        if (!modbus) continue;

        modbus_set_slave(modbus, slaveId);
        modbus_set_response_timeout(modbus, 0, 300000);
        modbus_set_byte_timeout(modbus, 0, 50000);

        if (modbus_connect(modbus) == 0) {
            uint16_t regs[1];
            int rc = modbus_read_registers(modbus, 0x1000, 1, regs);

            if (rc > 0) {
                cout << "✅ 波特率 " << baudRate << ": 可用" << endl;
            } else {
                cout << "❌ 波特率 " << baudRate << ": " << modbus_strerror(errno) << endl;
            }
            modbus_close(modbus);
        }
        modbus_free(modbus);
    }
}

int main(int argc, char* argv[]) {
    cout << "\n╔════════════════════════════════════════╗\n";
    cout << "║  BeiAng 4CP Modbus 诊断工具 v1.0     ║\n";
    cout << "╚════════════════════════════════════════╝\n";

    string port = "/dev/ttyUSB2";
    int baudRate = 9600;
    uint8_t slaveId = 0xD1; // 209

    // 解析命令行参数
    for (int i = 1; i < argc; i++) {
        string arg = argv[i];
        if (arg == "--port" && i + 1 < argc) {
            port = argv[++i];
        } else if (arg == "--baud" && i + 1 < argc) {
            baudRate = atoi(argv[++i]);
        } else if (arg == "--address" && i + 1 < argc) {
            slaveId = atoi(argv[++i]);
        } else if (arg == "--scan") {
            // 扫描模式
            if (testSerialConnection(port, baudRate)) {
                scanDeviceAddresses(port, baudRate);
            }
            return 0;
        }
    }

    cout << "\n配置:" << endl;
    cout << "  串口: " << port << endl;
    cout << "  波特率: " << baudRate << endl;
    cout << "  设备地址: " << (int)slaveId << " (0x" << hex << (int)slaveId << dec << ")" << endl;

    // 1. 测试串口连接
    if (!testSerialConnection(port, baudRate)) {
        return 1;
    }

    // 2. 扫描设备地址
    cout << "\n提示: 使用 --scan 参数扫描所有可能的设备地址" << endl;
    cout << "      例如: " << argv[0] << " --port " << port << " --scan" << endl;

    // 3. 测试通信质量
    testCommunicationQuality(port, baudRate, slaveId);

    // 4. 测试不同波特率
    testBaudRates(port, slaveId);

    printSeparator();
    cout << "\n💡 建议:\n";
    cout << "1. 如果扫描未找到设备，检查:\n";
    cout << "   - 设备是否通电\n";
    cout << "   - 串口线连接是否正确 (TX-RX交叉, GND共地)\n";
    cout << "   - USB转串口驱动是否正常\n\n";
    cout << "2. 如果 CRC 错误较多:\n";
    cout << "   - 检查线缆质量\n";
    cout << "   - 缩短线缆长度\n";
    cout << "   - 添加磁环或使用屏蔽线\n";
    cout << "   - 检查是否有电气干扰源\n\n";
    cout << "3. 如果从站地址错误:\n";
    cout << "   - 使用 --scan 找到正确地址\n";
    cout << "   - 更新配置文件中的 device.address\n\n";

    return 0;
}
