# CLAUDE.md

本文件是 AI / 开发代理进入 BeiAng8Panel 工程时必须遵守的中文规则入口。编译与部署先读 [BUILD.md](BUILD.md)，协议以 `docs/4CP-全热新风-主控对外通讯协议v1.22.md` 和当前代码为准。

## 1. 工程定位

BeiAng8Panel 是 4CP / 全热新风控制面板的 C++ 后端服务。它向 Flutter、Qt 或 Android 等 UI 提供统一 HTTP API，把界面与设备协议、本地硬件操作解耦。

```text
Flutter / Qt / Android
          │
       HTTP API
          │
状态中心 DataManager + 命令入口
          │
   ┌──────┴─────────┐
   │                │
通信通道          本地能力
   │                │
通信调度器         亮度、温湿度、雷达、AQI灯等
   │
通信介质 + 具体协议
```

UI 只依赖 API，不应知道串口轮询、寄存器批次或板端 sysfs 细节。

## 2. 当前进程模型

每个配置文件对应一个独立后端进程：

```sh
BeiAng8Panel -c config/process-x.json -c config/process-y.json
```

结构为：

```text
ProcessSupervisor
  ├─ process-1：配置 X → 通信通道 X → 通信调度器 X → Application X
  ├─ process-2：配置 Y → 通信通道 Y → 通信调度器 Y → Application Y
  └─ ……
```

规则：

- 一份配置描述一路通信通道和一套进程资源。
- 只传一份配置时直接运行，不额外 fork。
- 传入多份配置时，父进程负责 fork、等待和转发退出信号。
- 每个进程可以独立选择调度器。进程 1 保留完整业务应用和 `ModbusMasterPolling` 入口；进程 2/3/4 使用独立通信角色，不创建 WiFi、OTA、屏幕等本机能力模块。
- 新进程的调度器和通道只表达通信队列、传输介质与策略，不绑定 Modbus、RS485 或 CAN。具体协议仍由对应 Gateway/设备实现接入。
- 多进程同时启用 HTTP 时，各配置必须使用不同的 `network.httpPort`，否则会发生端口占用。
- 多路扩展优先新增并列配置和进程，不把多路通道强塞进同一个 Gateway。

## 3. 单进程模块

```text
Application
  ├─ DataManager
  │    ├─ 配置
  │    ├─ Gateway 与通信调度器
  │    ├─ 业务状态
  │    └─ 原始寄存器缓存
  ├─ DataAcquisitionModule
  │    ├─ 通信线程：只采集原始寄存器快照
  │    └─ 处理线程：解析快照并更新 DataManager
  ├─ ScheduleController
  └─ HttpServerBasedOnLibhv
       └─ uiservice 页面接口
```

主要目录：

| 目录/文件 | 职责 |
|---|---|
| `main.cpp` | 参数解析、进程配置和启动入口 |
| `ProcessSupervisor.*` | 多进程创建、等待和信号转发 |
| `common/` | Application、配置、日志、公共定义和工具 |
| `gateways/` | 4CP 协议、串口和通信调度器 |
| `master/` | 数据采集、处理和定时任务 |
| `structure/` | 后端业务数据结构 |
| `httpserver/` | libhv HTTP 服务和本地能力接口 |
| `uiservice/` | UI 页面 API |
| `config/` | 默认配置 |
| `external/` | 离线第三方源码 |
| `tests/` | 当前调度器测试 |

## 4. 通信调度模型

### 4.1 单线程串行总线

每个通信通道只创建一个调度器工作线程。调度器只负责操作入队、串行执行、间隔和读写策略；具体读写由通道回调执行。进程 1 的 `ModbusMasterScheduler` 仅是现有 4CP 实现的兼容入口。

### 4.2 250 ms 通信脉搏

- 普通操作每次实际尝试结束后，至少等待 `250 ms` 才允许下一次尝试开始（进程 1 的现有参数）。
- 默认响应和帧内字节超时为 `50 ms`，由配置 `serial.timeout` 覆盖。
- 因此超时事务的一拍约为“本次等待时间 + 250 ms”，不能简单理解为固定 250 ms 周期。
- 控制操作仍与读写串行，但是否跳过间隔由具体调度策略决定。

### 4.3 写优先

调度器维护读队列和写队列：

```text
当前事务完成
    ↓
重新检查写队列
    ├─ 有写：先执行全部当前排队写任务
    └─ 无写：执行下一项读任务
```

当前正在执行的事务不会被打断。写请求只在事务边界插队；等待 250 ms 间隔期间如果有写入队，唤醒后会重新选择写任务，而不是提前锁定下一项读任务。

### 4.4 一次重试

Gateway 的单次读写默认最多尝试两次：首次失败后再重试一次。失败任务不会在调度器内部连续死循环，而是重新入队、重新经过 250 ms 脉搏和写优先选择。

这和 `dataAcquisition.maxRetryCount` 不是同一概念：后者是连续采集失败达到阈值后触发重连的条件，默认值为 5。

### 4.5 典型极端场景

```text
读 1 超时 → 等待 250 ms
若写 A 已排队 → 写 A 先执行
写 A 也超时 → 等待 250 ms
若仍有写 → 下一项写优先
否则 → 读 1 的一次重试
读 1 重试后无论成功失败，再进入下一拍选择
```

## 5. 周期采集与数据处理

默认采集周期配置为 `1000 ms`。一次原始数据采集当前包含：

| 数据区 | 范围 | 实际批次 |
|---|---|---|
| 保持寄存器 | `0x1000`～`0x1076`，119 个 | `50 + 50 + 19` |
| 输入寄存器 | `0x2000`～`0x203B`，60 个 | `50 + 10` |
| 离散输入 | `0x3000` 起的能力位 | 当前周期读取 16 位 |

这里的 `1000 ms` 是一轮采集完成后，采集模块进入下一轮前的等待配置；一轮内部的每个 Modbus 事务仍遵守 250 ms 通信脉搏。

采集分两步：

1. 通信线程只读取原始寄存器并发布最新快照，不解析业务字段，也不持有 DataManager 锁。
2. 处理线程解析快照，再更新业务状态和寄存器缓存。

待处理快照采用“最新值覆盖旧值”：处理线程落后时不无限堆积历史快照，保证通信线程尽快继续收集真实设备数据。

写事务成功只表示 Modbus 写请求成功完成。设备运行状态仍由后续周期读取获得，因此 UI 看到状态变化可能晚于写完成若干拍；前端不需要了解后端调度细节。

## 6. 协议边界

- 当前协议版本是 v1.22。
- 4CP 默认地址为 `0xD1`（209），全热新风默认地址为 `0xC1`（193）。
- 默认串口是 `9600 / 8N1`。
- CRC16 使用标准 Modbus RTU 线路顺序：低字节在前、高字节在后。
- 当前主要数据区为 `0x1000`、`0x2000`、`0x3000`。
- 周期读取最多 50 个寄存器一批，避免单帧过大，并与设备通信节奏一致。
- 协议字段、地址和缩放规则集中在 `gateways/BeiAng4CPGateway.h` 与 v1.22 文档；不要在 HTTP 页面重复写裸地址。
- 解析和业务映射是第二阶段机械工作，不得反向污染通信调度器。

## 7. 状态和持久化

- 运行状态、业务结构和原始寄存器缓存保存在 `DataManager` 内存中。
- 当前没有新增一套类似 Flutter 的业务状态 JSON 快照落盘机制。
- 配置仍通过 `FactoryConfig.json` 读取和保存，保存时应保留后端未管理字段。
- 板端优先使用可写路径 `/mnt/UDISK/beiang8panel/FactoryConfig.json`；没有用户配置时可从只读出厂配置迁移。
- 板端日志默认写入 `/mnt/UDISK/beiang8panel/logs`；本地构建默认写入工程 `logs`，可用 `BEIANG_LOG_DIR` 覆盖。
- TRMK222 雷达状态由独立 daemon 写状态文件，后端通过状态文件读取，并通过命令文件下发开关。

不要为了方便额外引入数据库或新的状态落盘格式，除非用户明确要求改变保存机制。

## 8. 本地硬件与系统能力

当前 HTTP 层除 Modbus 外，还包含以下板端能力：

- GXHTC3 温湿度和序列号：读取 sysfs。
- 背光：优先使用 `/sys/class/backlight`，不存在时回退全志 `/dev/disp` ioctl。
- TRMK222 人感雷达：状态文件 + 命令文件，与独占串口 daemon 配合。
- 9 路 AQI RGB：只写 `/sys/class/led/multi_brightness`；写成功采用请求状态，不读取驱动节点反推灯态。
- RTC：设置接口会写设备 RTC 寄存器；读取接口中仍有未完全接入真实硬件的部分。
- Wi‑Fi：扫描（`GET /api/local-device/wifi/scan` 同步聚合，POST版已移除；产测仍用 `/scanWifi`+`/getWifiInfo`）、连接、普通断开、开关和状态查询（`/api/local-device/wifi/status`）已由独立 `WifiManager` 工作线程接入；普通断开保持开关开启，`enabled=false` 才是关闭。连接成功后自动经模组0x24对时（写系统时间+全部RTC）。R818 系统命令已适配，R528 和异常场景仍需实机验收。
- RS485 通讯开关：`/api/local-device/rs485/enabled`（GET/POST），全停语义（定时任务丢弃记日志+命令队列+轮询），状态持久化 `/mnt/UDISK/rs485_enable`；关闭期间 Modbus 透传接口快速 503。WiFi/OTA 不受影响。
- 天气和 IP 定位：通过 curl 调用外部服务，运行时需要网络。

这些能力在 macOS 或普通 Linux PC 上可能没有对应设备节点。本机运行只能验证进程和 API 边界，不能代替板端硬件验收。

## 9. HTTP 与 UI 边界

- Flutter App 当前只是一个 UI 客户端；后端不依赖 Flutter 实现。
- 将来替换为 Qt 或 Android 时，只要保持 API 契约，Modbus 调度、寄存器解析和本地能力无需随 UI 重写。
- HTTP 页面只负责校验请求、调用 DataManager/Gateway 并组织响应，不直接持有串口。
- UI 控制返回与设备真实运行状态是两件事：写请求完成后，真实状态由后续采集刷新。
- API 的具体字段和路由查看 `docs/HTTP_API.md`，不要在本文件复制一套容易过时的完整接口表。

## 10. 配置与运行

默认配置搜索顺序：

1. `/mnt/UDISK/beiang8panel/FactoryConfig.json`
2. `config/FactoryConfig.json`
3. `./FactoryConfig.json`
4. `/etc/beiang8panel/FactoryConfig.json`
5. `/usr/share/beiang8panel/config/FactoryConfig.json`

常用命令：

```sh
# 默认配置
./BeiAng8Panel

# 一个进程
./BeiAng8Panel -c /path/process-x.json

# 多个独立进程
./BeiAng8Panel -c /path/process-x.json -c /path/process-y.json

# 后台运行
./BeiAng8Panel -d -c /path/process-x.json

# 帮助和版本
./BeiAng8Panel -h
./BeiAng8Panel -v
```

`FactoryConfig.json` 当前主要包含：

- `serial`：进程 1 兼容配置，包含旧的串口参数。
- `transport`：新通信进程使用的通用传输描述；`type` 与 `endpoint` 不预设具体协议。
- `device`：地址、机型、协议版本。
- `network`：HTTP 监听地址和端口。
- `dataAcquisition`：轮询等待、连续失败阈值、自动重连。
- `radar`：状态文件和命令文件。
- `weather`：服务地址与认证配置；敏感值不要复制到日志、文档或提交说明。

## 11. 编译入口

当前正式入口：

```text
build_macos.sh          / run_macos.sh
build_linux.sh          / run_linux.sh
build_embedded_r528.sh  / run_embedded_r528.sh
build_embedded_r818.sh  / run_embedded_r818.sh
```

详细要求见 [BUILD.md](BUILD.md)。`build-native.sh`、`build-arm64.sh` 为原服务器兼容入口，保留但不作为当前脚本范本。

所有平台都必须从工程 `external/` 离线构建 libmodbus/libhv，不得改回依赖系统安装或在线下载的流程。

## 12. 修改规则

- 修改前先读当前代码，不用旧文档替代实现。
- 保持朴素、边界清楚、接近 C 风格的写法；只有确有必要时使用复杂 C++ 抽象。
- 进程、调度器、Gateway、协议解析、数据处理和 UI API 分层修改，不跨层堆逻辑。
- 同一路通信通道的全部底层调用必须继续经过单一调度器线程。
- 不破坏“写优先、事务不可中断、每次尝试重新进入脉搏”的语义。
- 不把业务解析重新塞回通信线程。
- 不在源码中写死 SDK、构建机或个人目录；平台差异放到脚本顶部配置区和配置文件。
- 不无差别归一化业务源码换行；只有实际构建受阻时才最小处理。
- 不修改 `external/` 第三方业务源码来迎合单个平台，优先在隔离构建目录中解决生成问题。
- 不删除原服务器兼容脚本，除非用户明确要求。
- 不擅自暂存、提交、部署或改动用户的其他未提交文件。

## 13. 验证要求

根据修改范围选择验证，结论必须分开表述：

1. **文档/静态检查通过**：只证明文本和引用一致。
2. **本机构建通过**：只证明当前主机产物可生成。
3. **进程能够启动**：串口错误仍可能导致随后退出。
4. **串口通信通过**：必须有真实 TTY/模拟器收发证据。
5. **板端运行通过**：必须核对目标架构、动态加载器、MD5 和真实设备进程。
6. **业务正确**：还需要 API、寄存器和硬件状态的实际联动验证。

当前调度器测试位于 `tests/ModbusMasterSchedulerTest.cpp`，覆盖写优先、命令间隔和失败重试重新排队。正式平台构建脚本默认关闭测试；本地改动调度器时应单独启用并运行该测试。
