/**
 * 详细的 Modbus 通信诊断 - 带原始数据输出
 */

#include <iostream>
#include <modbus/modbus.h>
#include <cstring>
#include <unistd.h>

using namespace std;

// 测试读取单个寄存器并显示详细信息
void testDetailedRead(const string& port, int baudRate, uint8_t slaveId, uint16_t regAddr) {
    modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
    if (!modbus) {
        cout << "❌ 无法创建 Modbus 上下文" << endl;
        return;
    }

    modbus_set_slave(modbus, slaveId);

    // 设置超时为 1 秒
    modbus_set_response_timeout(modbus, 1, 0);

    // 启用调试模式查看原始通信
    modbus_set_debug(modbus, 1);

    cout << "\n🔍 连接到 " << port << " @ " << baudRate << " baud, 从站: 0x" << hex << (int)slaveId << dec << endl;
    cout << "🔍 尝试读取寄存器 0x" << hex << regAddr << dec << "...\n" << endl;

    if (modbus_connect(modbus) < 0) {
        cout << "❌ 连接失败: " << modbus_strerror(errno) << endl;
        modbus_free(modbus);
        return;
    }

    cout << "✅ 已连接" << endl;

    uint16_t regs[1];
    int rc = modbus_read_registers(modbus, regAddr, 1, regs);

    cout << "\n结果: ";
    if (rc > 0) {
        cout << "✅ 成功! 寄存器值 = " << regs[0] << " (0x" << hex << regs[0] << dec << ")" << endl;
    } else {
        cout << "❌ 失败: " << modbus_strerror(errno) << " (errno: " << errno << ")" << endl;
        cout << "\n错误说明:" << endl;
        switch (errno) {
            case EMBBADCRC:
                cout << "  - CRC 校验失败：数据传输过程中出错" << endl;
                cout << "  原因: 电气干扰、线缆问题、波特率不匹配" << endl;
                break;
            case EMBBADDATA:
                cout << "  - 数据无效：接收到的数据不正确" << endl;
                cout << "  原因: 从站地址错误、数据格式错误" << endl;
                break;
            case ETIMEDOUT:
                cout << "  - 超时：设备无响应" << endl;
                cout << "  原因: 设备未通电、连接断开、地址错误" << endl;
                break;
            default:
                cout << "  - 其他错误 (errno=" << errno << ")" << endl;
        }
    }

    modbus_close(modbus);
    modbus_free(modbus);
}

// 测试不同的超时设置
void testTimeoutSettings(const string& port, int baudRate, uint8_t slaveId) {
    cout << "\n🔧 测试不同超时设置..." << endl;

    int timeouts[] = {100000, 300000, 500000, 1000000}; // 100ms, 300ms, 500ms, 1s
    int numTimeouts = sizeof(timeouts) / sizeof(timeouts[0]);

    for (int i = 0; i < numTimeouts; i++) {
        modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, 1);
        if (!modbus) continue;

        modbus_set_slave(modbus, slaveId);

        uint32_t sec = timeouts[i] / 1000000;
        uint32_t usec = timeouts[i] % 1000000;
        modbus_set_response_timeout(modbus, sec, usec);

        modbus_set_debug(modbus, 0); // 关闭调试

        if (modbus_connect(modbus) == 0) {
            uint16_t regs[1];
            int rc = modbus_read_registers(modbus, 0x1000, 1, regs);

            cout << "  超时 " << (timeouts[i] / 1000) << "ms: ";
            if (rc > 0) {
                cout << "✅ 成功 (值=" << regs[0] << ")" << endl;
            } else {
                cout << "❌ " << modbus_strerror(errno) << endl;
            }
            modbus_close(modbus);
        }
        modbus_free(modbus);
    }
}

// 测试不同的串口模式
void testSerialModes(const string& port, uint8_t slaveId) {
    cout << "\n🔧 测试不同串口配置..." << endl;

    struct SerialConfig {
        int baudRate;
        char parity;
        int dataBits;
        int stopBits;
    };

    SerialConfig configs[] = {
        {9600, 'N', 8, 1},
        {9600, 'E', 8, 1},
        {9600, 'O', 8, 1},
        {9600, 'N', 8, 2},
        {19200, 'N', 8, 1},
        {38400, 'N', 8, 1},
    };

    for (const auto& cfg : configs) {
        modbus_t* modbus = modbus_new_rtu(port.c_str(), cfg.baudRate, cfg.parity, cfg.dataBits, cfg.stopBits);
        if (!modbus) continue;

        modbus_set_slave(modbus, slaveId);
        modbus_set_response_timeout(modbus, 0, 500000);

        if (modbus_connect(modbus) == 0) {
            uint16_t regs[1];
            int rc = modbus_read_registers(modbus, 0x1000, 1, regs);

            cout << "  " << cfg.baudRate << " baud, " << cfg.parity
                 << ", " << cfg.dataBits << "/" << cfg.stopBits << ": ";
            if (rc > 0) {
                cout << "✅ 成功 (值=" << regs[0] << ")" << endl;
            } else {
                cout << "❌ " << modbus_strerror(errno) << endl;
            }
            modbus_close(modbus);
        }
        modbus_free(modbus);
    }
}

int main() {
    string port = "/dev/ttyUSB2";
    int baudRate = 9600;
    uint8_t slaveId = 0xD1; // 209

    cout << "\n╔════════════════════════════════════════╗\n";
    cout << "║  BeiAng 4CP 详细诊断工具             ║\n";
    cout << "╚════════════════════════════════════════╝\n";

    cout << "\n配置:" << endl;
    cout << "  串口: " << port << endl;
    cout << "  波特率: " << baudRate << endl;
    cout << "  设备地址: " << (int)slaveId << " (0x" << hex << (int)slaveId << dec << ")" << endl;

    // 1. 详细读取测试（带调试输出）
    cout << "\n" << string(50, '=') << endl;
    cout << "测试 1: 详细通信记录" << endl;
    cout << string(50, '=') << endl;
    testDetailedRead(port, baudRate, slaveId, 0x1000);

    // 2. 测试超时设置
    cout << "\n" << string(50, '=') << endl;
    cout << "测试 2: 超时设置" << endl;
    cout << string(50, '=') << endl;
    testTimeoutSettings(port, baudRate, slaveId);

    // 3. 测试串口配置
    cout << "\n" << string(50, '=') << endl;
    cout << "测试 3: 串口配置" << endl;
    cout << string(50, '=') << endl;
    testSerialModes(port, slaveId);

    return 0;
}
