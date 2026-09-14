# 4CP Modbus RTU 设备模拟器

本工程是在 Windows 上运行的 4CP / 全热新风 Modbus RTU 从机模拟器，用于替代真实设备接入 RS485 总线。后端主站通过串口读写模拟器时，应当把它视为一台真实设备。

当前实现以仓库内最新的 **v1.22 协议**和当前源码为准。

## 1. 当前能力

- 使用标准 Modbus RTU 帧格式和 CRC16 线路顺序，CRC 低字节在前、高字节在后。
- 已实现功能码：`02H`、`03H`、`04H`、`06H`、`10H`。
- 默认设备地址：4CP 为 `0xD1`（209），全热新风为 `0xC1`（193）。
- 默认串口参数：`9600 / 8N1`。
- 支持保持寄存器、输入寄存器和离散输入。
- 支持传感器及运行数据的周期模拟更新。
- 支持一个启动入口创建多个独立模拟器进程，每个进程独占一路 COM。
- 进程与通信调度器解耦；当前提供 `modbus-slave-response` 从机应答调度器。
- 通信收发与数据更新分离，串口请求尽量快速进入、快速应答。
- 通信层使用仓库内置的 `libmodbus 3.1.2`，源码与后端统一取自 R818 SDK 母版并离线构建。
- 仓库同时携带同一 SDK 母版的 `libhv 1.3.4`；当前模拟器不构建、不链接该库。
- 工程本身无在线依赖；工具链已安装时可离线编译和运行。

## 2. 快速编译和运行

### 2.1 环境要求

- Windows 10/11。
- Visual Studio，安装“使用 C++ 的桌面开发”。
- CMake 3.20 或更高版本。
- 需要运行 Python 测试时，另行准备 Python 3 和 `pyserial`。

### 2.2 推荐入口

第一次使用前，只需按本机实际安装位置修改 `build_windows.bat` 顶部配置区：

```bat
set "CMAKE_EXE_PATH=C:\Program Files\CMake\bin\cmake.exe"
set "VS_BASE=D:\Program Files (x86)"
set "VSVARS=%VS_BASE%\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
```

在 PowerShell 中执行：

```powershell
.\build_windows.bat
.\run_windows.ps1
```

Debug 版本：

```powershell
.\build_windows.bat debug
.\run_windows.ps1 debug
```

默认产物：

```text
build\windows\Release\4CP_Simulator.exe
build\windows\Release\modbus.dll
build\windows\Debug\4CP_Simulator.exe
build\windows\Debug\modbus.dll
```

### 2.3 运行参数配置

两套入口使用不同的联调串口，请勿混用：

- `build_simple.bat` 对应既有联调入口，示例串口为 `COM10`。
- `build_windows.bat` + `run_windows.ps1` 对应新入口，默认串口为 `COM3`。

`run_windows.ps1` 顶部是串口配置区，默认配置为 `COM3 / 9600 / 0xD1`。也可以在本次执行前通过环境变量覆盖：

```powershell
$env:FOURCP_SERIAL_PORT = "COM3"
$env:FOURCP_BAUD_RATE = "9600"
$env:FOURCP_DEVICE_ADDRESS = "0xD1"
.\run_windows.ps1
```

运行日志统一追加到工程根目录的 `logs\run_windows.log`；脚本保持前台运行，不创建残留包装进程。

## 3. 命令行使用

### 3.1 单进程

```powershell
.\build\windows\Release\4CP_Simulator.exe -p COM3 -b 9600 -a 0xD1 -s modbus-slave-response
```

| 参数 | 说明 | 默认值 |
|---|---|---|
| `-p`, `--port` | 串口 | `COM1` |
| `-b`, `--baudrate` | 波特率 | `9600` |
| `-a`, `--addr` | 从机地址，支持十进制或 `0x` 十六进制 | `209` / `0xD1` |
| `-s`, `--scheduler` | 通信调度器 | `modbus-slave-response` |
| `-h`, `--help` | 显示帮助 | - |

### 3.2 多进程

一条命令可以并列创建多路模拟设备：

```powershell
.\build\windows\Release\4CP_Simulator.exe `
  --process process-1 COM10 9600 0xD1 modbus-slave-response `
  --process process-2 COM11 9600 0xC1 modbus-slave-response
```

每个 `--process` 的格式固定为：

```text
--process <进程名> <串口> <波特率> <设备地址> <调度器>
```

每个进程独占一路串口，并明确选择一个调度器。以后可以继续增加进程，也可以增加新的主机或从机调度器，二者不相互耦合。

## 4. 架构

```text
ProcessSupervisor
  ├─ 模拟器进程 1：COM10 + 设备地址 + 调度器
  ├─ 模拟器进程 2：COM11 + 设备地址 + 调度器
  └─ ……

单个模拟器进程
  └─ CommunicationScheduler
       └─ ModbusSlaveScheduler
            ├─ 通信路径：镜像快照 → libmodbus 收包/校验并立即应答 → 写值回填镜像
            └─ 数据路径：独立数据线程 → 周期更新模拟数据
```

核心原则：

1. **进程和调度器分离**：进程只描述串口、地址和所选调度器。
2. **通信和数据处理分离**：libmodbus 通信线程只同步小型数据镜像并应答，数据线程独立更新模拟状态。
3. **一进程一路串口**：多路串口通过多个并列子进程实现，互不阻塞。
4. **调度器可扩展**：当前是 Modbus 从机应答调度器，后续可增加其他主机或从机调度策略。

主要模块：

| 文件 | 职责 |
|---|---|
| `src/main.cpp` | 命令行解析和进程配置入口 |
| `ProcessSupervisor` | 创建、监视和回收多个 Windows 子进程 |
| `CommunicationScheduler` | 通信调度器统一接口和工厂 |
| `ModbusSlaveScheduler` | 当前 Modbus 从机应答调度器，组合通信与数据更新 |
| `4CP_SimulatorCore` | 使用 libmodbus 打开串口、收包、校验、异常处理和应答 |
| `external/libmodbus` | 随工程离线构建的 Modbus RTU 通信库 |
| `external/libhv` | 与后端统一归档的 HTTP 库源码；模拟器当前不使用 |
| `4CP_Protocol` | 协议地址、位定义及兼容行为测试所需的帧工具 |
| `DeviceSimulator` | 数据镜像、寄存器写回和模拟数据更新 |

## 5. 协议说明

### 5.1 基本参数

| 项目 | 4CP | 全热新风 |
|---|---:|---:|
| 默认地址 | `0xD1`（209） | `0xC1`（193） |
| 波特率 | `9600` | `9600` |
| 数据格式 | `8N1` | `8N1` |

地址由启动进程时的参数决定。同一模拟器进程只响应自己的地址。

### 5.2 Modbus RTU 帧

```text
[设备地址] [功能码] [数据区] [CRC低字节] [CRC高字节]
```

- 多字节寄存器数据按 Modbus 规则高字节在前。
- CRC16 使用标准 Modbus RTU 线路顺序：低字节在前、高字节在后。
- 非本机地址的请求不处理。
- 非法功能码、非法地址或非法数据按 Modbus 异常响应处理。

### 5.3 已实现功能码

| 功能码 | 作用 |
|---|---|
| `02H` | 读取离散输入 |
| `03H` | 读取保持寄存器 |
| `04H` | 读取输入寄存器 |
| `06H` | 写单个保持寄存器 |
| `10H` | 写多个保持寄存器 |

### 5.4 当前寄存器区间

| 数据区 | 当前范围 | 访问方式 | 说明 |
|---|---|---|---|
| 保持寄存器 | `0x1000`～`0x1076` | `03H / 06H / 10H` | 控制、设定、RTC、维护、内外循环风量设定、风阀设定等 |
| 输入寄存器 | `0x2000`～`0x203B` | `04H` | 身份、实时状态、传感器、压力、压缩机温度、主控板版本字符串等 |
| 离散输入 | 从 `0x3000` 开始 | `02H` | 能力、运行状态和故障位；当前定义到位偏移 76 |

关键身份数据：

| 地址 | 内容 |
|---|---|
| `0x2000` | 工厂标志，ASCII `BA` |
| `0x2001` | 机型：4CP=`0`，全热新风=`1` |
| `0x2002` | 协议版本 |
| `0x1024` | 设备地址设置 |

完整寄存器定义不要在多份文档中重复维护，请直接查看：

- [模拟器实现框架](docs/模拟器实现框架.md)
- [4CP-全热新风-主控对外通讯协议v1.22.md](docs/4CP-全热新风-主控对外通讯协议v1.22.md)
- [4CP-全热新风-主控对外通讯协议v1.22.pdf](docs/4CP-全热新风-主控对外通讯协议v1.22.pdf)
- `include/4CP_Protocol.h`

## 6. 测试

### 6.1 Python 测试客户端

安装依赖：

```powershell
py -m pip install pyserial
```

```powershell
py .\test_modbus_rtu.py --list
py .\test_modbus_rtu.py COM5
py .\test_modbus_rtu.py COM5 9600
```

测试通常需要一对能够互通的串口：模拟器占用一端，Python 主站占用另一端。测试前必须先确认 Windows 中真实存在这些 COM 口。

### 6.2 辅助脚本

- `build_simple.bat`：服务器/既有环境构建入口，使用当前命令行中的 VS 与 CMake 环境，VS 生成器产物位于 `build\Release`。
- `start_test.bat`：历史联调入口，当前固定使用 `COM10` 运行模拟器、`COM5` 运行 Python 测试，并依赖 `pyserial`。

`build_simple.bat` 与 `build_windows.bat` 都是保留并验证的构建方式；新环境优先使用路径配置明确的 `build_windows.bat`。`start_test.bat` 目前不会可靠判断串口缺失或测试失败，末尾出现 `Test complete` 不能单独作为测试通过证据。

## 7. 离线边界

- 模拟器运行时不访问网络。
- `external/libmodbus 3.1.2` 和 `external/libhv 1.3.4` 均随工程归档，构建时不下载源码；模拟器当前只构建 libmodbus。
- Visual Studio、CMake、Python 和 `pyserial` 必须提前安装；“离线编译”不等于脚本负责离线安装工具链。
- 没有真实串口时，可证明程序能够启动并报告串口打开失败，但不能证明 Modbus 通信正确。
- 部署时 `4CP_Simulator.exe` 与同目录的 `modbus.dll` 必须一起复制；目标机仍可能需要对应的 Microsoft C/C++ 运行库。

## 8. 故障排查

### 构建脚本找不到 CMake 或 Visual Studio

修改 `build_windows.bat` 顶部的 `CMAKE_EXE_PATH`、`VS_BASE` 和 `VSVARS`，不要在业务逻辑中写入本机路径。

### 串口打开失败

1. 用设备管理器或 `py .\test_modbus_rtu.py --list` 确认 COM 口真实存在。
2. 确认串口没有被其他程序占用。
3. 确认传入的端口名与实际端口一致。

### 通信无响应

1. 确认两端不是同一个被独占的 COM 口，而是实际互通的一对串口。
2. 确认 RS485 A/B、地线和收发方向正确。
3. 确认两端均为 `9600 / 8N1`。
4. 确认从机地址是 `0xD1` 或本次启动时指定的地址。
5. 检查功能码、寄存器区间和 CRC。

## 9. 开发约束

- 协议以最新 v1.22 文档和当前 `include/4CP_Protocol.h` 为准，不再维护废弃版本的寄存器表。
- 新增寄存器时，先补协议常量，再补 `DeviceSimulator` 的初始化、读写或数据更新逻辑，最后补测试。
- 新增调度器时，保持 `进程配置 → 调度器工厂 → 调度器实现` 的边界，不把新策略直接堆进 `main.cpp`。
- 不把周期数据处理重新塞回串口接收回调；通信路径继续保持快进快出。
- Windows 实际验证优先使用 `build_windows.bat` 和 `run_windows.ps1`。
- 项目的构建、运行、架构和协议摘要只在本 README 维护，避免多份正文再次漂移。
