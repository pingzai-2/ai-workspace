/**
 * 停止位验证测试
 * 使用 libmodbus 精确测试 1 vs 2 停止位
 */

#include <iostream>
#include <modbus/modbus.h>
#include <thread>
#include <chrono>

using namespace std;

// 测试特定停止位配置
bool testStopBits(const string& port, int baudRate, uint8_t slaveId, int stopBits, int trials = 10) {
    int success = 0;

    for (int i = 0; i < trials; i++) {
        modbus_t* modbus = modbus_new_rtu(port.c_str(), baudRate, 'N', 8, stopBits);
        if (!modbus) {
            cerr << "无法创建 Modbus 上下文" << endl;
            return false;
        }

        modbus_set_slave(modbus, slaveId);
        modbus_set_response_timeout(modbus, 0, 500000);
        modbus_set_byte_timeout(modbus, 0, 50000);

        if (modbus_connect(modbus) == 0) {
            uint16_t regs[1];
            int rc = modbus_read_registers(modbus, 0x1000, 1, regs);

            if (rc > 0) {
                success++;
            }
            modbus_close(modbus);
        }
        modbus_free(modbus);

        // 命令间隔 ≥ 500ms（按文档要求）
        this_thread::sleep_for(chrono::milliseconds(550));
    }

    double rate = (double)success / trials * 100.0;
    cout << "  " << stopBits << " 停止位: " << success << "/" << trials
         << " 成功 (" << rate << "%)" << endl;

    return success >= trials * 0.8; // 80% 成功率认为可用
}

int main() {
    string port = "/dev/ttyUSB2";
    int baudRate = 9600;
    uint8_t slaveId = 0xD1; // 209

    cout << "\n╔════════════════════════════════════════╗\n";
    cout << "║  停止位验证测试                       ║\n";
    cout << "╚════════════════════════════════════════╝\n";

    cout << "\n配置: " << port << " @ " << baudRate << " baud, 地址: 0xD1" << endl;
    cout << "命令间隔: 550ms (满足 ≥500ms 要求)\n" << endl;

    cout << "测试结果 (各10次):" << endl;

    bool stopBit1OK = testStopBits(port, baudRate, slaveId, 1);
    bool stopBit2OK = testStopBits(port, baudRate, slaveId, 2);

    cout << "\n结论:" << endl;
    if (stopBit1OK && !stopBit2OK) {
        cout << "  ✅ 使用 1 停止位" << endl;
    } else if (!stopBit1OK && stopBit2OK) {
        cout << "  ✅ 使用 2 停止位" << endl;
    } else if (stopBit1OK && stopBit2OK) {
        cout << "  ⚠️  两种都可用，推荐使用 1 停止位（标准）" << endl;
    } else {
        cout << "  ❌ 两种配置都不工作，检查硬件连接" << endl;
    }

    return 0;
}
