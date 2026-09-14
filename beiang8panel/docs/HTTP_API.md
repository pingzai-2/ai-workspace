# BeiAng8Panel HTTP API 文档

本文档描述 BeiAng8Panel 后端服务（空气净化器/全热新风控制器面板）当前**实际提供**的所有 HTTP REST API 接口。

> 本文档以**当前代码实际行为**为准（实现状态、返回字段、响应结构均与源码核对）。协议目标参考 `docs/4CP-全热新风-主控对外通讯协议v1.22.md`。

**服务地址**: `http://<host>:<port>` （默认端口 8080，配置项 `network.httpPort`）
**软件版本**: `1.3.0` （`BEIANG_8PANEL_VERSION`）
**Modbus 协议版本**: `V1.22` （`PROTOCOL_VERSION`）
**默认设备地址**: `209` （`0xD1`）
**响应格式**: JSON（封装格式不统一，见下文「响应封装」）
**文档版本**: 3.29

---

## 实现状态说明

| 状态标记      | 说明                                                                                     |
| ------------- | ---------------------------------------------------------------------------------------- |
| ✅ 已实现     | 接口已真正实现，会执行实际操作（读写设备 / 硬件 / 真实外部 API），返回真实或已落实的数据 |
| ⏸ 暂不可用   | 代码路径保留，但当前架构下无法工作；等待依赖能力就绪（如模组数据接口）                   |
| 🔄 部分实现   | 接口可用，但行为不完整（如只改内存未下发给设备、或只支持部分参数）                       |
| ⚠️ 模拟数据 | 接口可达、参数会校验，但**返回固定模拟数据**，未连接真实硬件/外部服务              |
| ❌ 未实现     | 接口已注册可访问，但功能未实现，返回未实现占位响应（`code:1006`）或固定的"成功"假响应  |

---

## 响应封装（重要）

当前代码存在**多种**响应封装方式，前端需按实际接口区分：

### 模式 A：标准 `{code,message,data}` 封装

```json
{ "code": 0, "message": "Success", "data": { ... } }
```

由 `ApiResponse` / `BasePage` 构建器产生。注意 `message` 取值：

- `HomePage`、`IdlePage` 等页面类：`"Success"`（首字母大写），`code` 为 `0`（`/api/idle/environment`、`/api/idle/air-quality-reminder` 例外，为 `200`）
- `HttpServerBasedOnLibhv` 内联处理器（统一 API 接口）：`"success"`（全小写），`code` 为 `0`

### 模式 B：裸对象 / 裸数组（无 `code` 外层）

```json
{ "pong": true }
[ "GET /api/device/status", ... ]
```

部分内联处理器自行构建 JSON 后交由 `buildSuccessResponse` 输出。当数据以 `{` 或 `[` 开头时**原样返回**，不再包裹 `code/message/data`。涉及接口：`/api/ping`、`/api/health`、`/api/version`、`/api/paths`、`/getScreenBrightness`、`/setScreenSleep`、`/setScreenBrightness`、`/getTempHumi`、`/api/modbus/read`、`/api/modbus/write`、`/getWeather`、`/getLocation`、WiFi 系列、人感雷达 / AQI 灯 / 扬声器等。

### 模式 C：错误响应

```json
{ "code": <错误码>, "message": "<描述>" }
```

错误响应**不带 `data` 字段**。常见错误码见文末「错误码说明」。

> ⚠️ 因封装不统一，前端解析时**不要假定每个接口都有 `code/data`**，应按本文档各接口的「实际响应」解析。

---

## 已实现接口总览（✅）

> 以下为**已实现（✅ 真实可用）**的全部接口总览。模拟（⚠️）与未实现（❌）接口不在此列，见「快速参考表」。
> 各接口详细说明见对应章节。共 55 个。

### Modbus 控制 / 查询接口

| 方法 | 路径                                     | 参数                                                                             | 功能                            | 寄存器                                      | 返回数据                                                                                                 |
| ---- | ---------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| POST | `/api/freshair/switch`                 | `on`(bool,必填)                                                                | 新风模块开关                    | 写1001H                                     | `{code:0,message:"success",data:{accepted:true,on:true}}`                                              |
| GET  | `/api/freshair/status`                 | 无                                                                               | 新风状态                        | 1001H/1007H/1008H/100CH/2003H/2004H         | `{freshAirModuleOn:true,runMode:2,fanGear:3,freshFanDutyCycle:65,fanMaxGear:3,fanMaxGearRecirc:5}`     |
| POST | `/api/freshair/speed`                  | `speed`(int,0-6,必填)                                                          | 新风风速设定                    | 写1008H                                     | `{code:0,message:"success",data:{accepted:true,speed:3}}`                                              |
| POST | `/api/freshair/runmode`                | `mode`(int,0-5,必填)                                                           | 新风运行模式                    | 写1007H                                     | `{code:0,message:"success",data:{accepted:true,mode:2}}`                                               |
| POST | `/api/humidity-module/switch`          | `on`(bool,必填)                                                                | 调湿模块开关                    | 写1003H                                     | `{code:0,message:"success",data:{accepted:true,on:true}}`                                              |
| GET  | `/api/humidity-module/status`          | 无                                                                               | 调湿模块状态                    | 1003H/1004H/1005H/100FH                     | `{humidityModuleOn:true,humidificationOn:false,dehumidificationOn:false,targetHumidity:50}`            |
| POST | `/api/humidity-module/target`          | `humidity`(int,30-70,必填)                                                     | 目标湿度设定                    | 写100FH                                     | `{code:0,message:"success",data:{accepted:true,humidity:50}}`                                          |
| POST | `/api/humidity-module/humidify`        | `on`(bool,必填)                                                                | 加湿开关                        | 写1004H（1003H开启时只读）                  | `{accepted:true,on:true}`（裸对象）                                                                    |
| POST | `/api/humidity-module/dehumidify`      | `on`(bool,必填)                                                                | 除湿开关                        | 写1005H（1003H开启时只读）                  | `{accepted:true,on:false}`（裸对象）                                                                   |
| POST | `/api/freshair/exhaust-speed`          | `speed`(int,0-6,必填)                                                          | 排风风量档位(预留)              | 写1009H                                     | `{accepted:true,speed:2}`（裸对象）                                                                    |
| POST | `/api/freshair/stepless`               | `on`(bool,必填)                                                                | 无极风量控制开关                | 写100BH                                     | `{accepted:true,on:true}`（裸对象）                                                                    |
| POST | `/api/freshair/duty`                   | `fresh`/`exhaust`/`boost`(int,0-100,至少一项)                              | 风量占空比                      | 写100CH/100DH/100EH                         | `{accepted:true,count:2}`（裸对象）                                                                    |
| POST | `/api/device/target-temperature`       | `temperature`(number,16.0-31.0,必填)                                           | 目标温度设定(×10)              | 写1010H                                     | `{accepted:true,temperature:25.0,raw:250}`（裸对象）                                                   |
| POST | `/api/device/plasma-disinfect`         | `enabled`(bool,必填)                                                           | 等离子消毒开关                  | 写1011H                                     | `{accepted:true,enabled:true}`（裸对象）                                                               |
| POST | `/api/device/aux-heat`                 | `mode`(int,0-3,必填)                                                           | 电辅热选择                      | 写1013H                                     | `{accepted:true,mode:1}`（裸对象）                                                                     |
| POST | `/api/humidity-module/intensity`       | `intensity`(int,0-2,必填)                                                      | 加湿/除湿强度                   | 写1014H                                     | `{accepted:true,intensity:1}`（裸对象）                                                                |
| POST | `/api/device/sa-fan-ratio`             | `ratio`(number,必填)                                                           | SA风量与增压风机比例(×10)      | 写1015H                                     | `{accepted:true,ratio:1.8,raw:18}`（裸对象）                                                           |
| POST | `/api/device/fan-delay-off`            | `minutes`(int,0-65535,必填)                                                    | 关机后延时关风机时间            | 写1020H                                     | `{accepted:true,minutes:5}`（裸对象）                                                                  |
| POST | `/api/device/compressor`               | `eevOpening`(0-500)/`frequencySet`(0-90)/`frequencyMax`(60-95)，至少一项   | 压缩机设定                      | 写1028H-102AH                               | `{accepted:true,updated:["frequencySet"]}`（裸对象）                                                   |
| POST | `/api/device/factory-test`             | `enabled`(bool,必填)，开启需`confirm`:true                                   | 厂测模式                        | 写1030H(100/0)                              | `{accepted:true,enabled:false}`（裸对象）                                                              |
| POST | `/api/device/pressure-switch`          | `switch`("high"/"low")+`on`(bool)                                            | 高/低压开关(仅厂测)             | 写102BH/102CH                               | `{accepted:true,switch:"high",on:true}`（裸对象）                                                      |
| POST | `/api/factory/fan`                     | `fan`(1-4)+`value`(int)                                                      | 厂测FAN风量设定(仅厂测)         | 写1038H-103BH                               | `{accepted:true,fan:1,value:600}`（裸对象）                                                            |
| POST | `/api/factory/valve`                   | `valve`(1-3)+`status`(0-2)                                                   | 厂测阀门状态设定(仅厂测)        | 写103CH-103EH                               | `{accepted:true,valve:1,status:2}`（裸对象）                                                           |
| POST | `/api/maintenance/filter`              | `filter1-3`/`humidityModule`/`ief`(小时)/`wholeUnit`(天)，至少一项       | 滤网/保养剩余时间复位           | 写1031H-1036H                               | `{accepted:true,updated:["filter1"]}`（裸对象）                                                        |
| POST | `/api/device/factory-reset`            | `confirm`:true（必填）                                                         | 恢复出厂（只写，高危）          | 写1040H(写1)                                | `{accepted:true}`（裸对象）                                                                            |
| POST | `/api/factory/fan-flow`                | `fan`(1-4)+`circulation`("external"/"internal")+`gear`(1-6)+`value`(int) | FAN内外循环档位风量标定(仅厂测) | 写1041H-1070H                               | `{accepted:true,fan:1,circulation:"external",gear:1,value:300}`（裸对象）                              |
| POST | `/api/factory/damper`                  | `damper`(1-3)+`direction`(0/1)/`steps`(int)，至少一项                      | 风阀方向/步数设定(仅厂测)       | 写1071H-1076H                               | `{accepted:true,damper:1,updated:["direction","steps"]}`（裸对象）                                     |
| POST | `/api/super-pure/switch`               | `on`(bool,必填)                                                                | 超净模式开关                    | 写1002H                                     | `{code:0,message:"success",data:{accepted:true,on:true}}`                                              |
| GET  | `/api/super-pure/status`               | 无                                                                               | 超净模式状态                    | 1002H                                       | `{superPureOn:true}`                                                                                   |
| POST | `/api/device/power`                    | `power`(bool,缺省true)                                                         | 一键开关机                      | 开机写1001H=1/关机写1001H-1003H=0           | `{accepted:true,power:true}`（裸对象）                                                                 |
| POST | `/api/device/mode`                     | `mode`(int,0-5,缺省1)                                                          | 新风运行模式切换                | 写1007H(需1001H=1)                          | `{code:0,message:"success",data:{accepted:true,mode:2}}`                                               |
| POST | `/api/device/leave-home`               | `on`(bool,必填)                                                                | 一键离家开关                    | 写1006H                                     | `{accepted:true,on:true}`（裸对象）                                                                    |
| GET  | `/api/device/leave-home/status`        | 无                                                                               | 一键离家状态                    | 读1006H缓存                                 | `{leaveHomeOn:true}`（裸对象）                                                                         |
| GET  | `/api/device/unit-run-mode/status`     | 无                                                                               | 整机运行模式                    | 读100AH缓存                                 | `{wholeUnitRunMode:1}`（裸对象）                                                                       |
| GET  | `/api/device/factory-test/status`      | 无                                                                               | 厂测模式状态                    | 读1030H缓存                                 | `{factoryTestMode:0,factoryTestActive:false}`（裸对象）                                                |
| GET  | `/api/device/air-conditioner/presence` | 无                                                                               | 空调有无                        | —(产品级静态)                              | `{hasAirConditioner:false}`（裸对象）                                                                  |
| GET  | `/api/device/floor-heating/presence`   | 无                                                                               | 地暖有无                        | —(产品级静态)                              | `{hasFloorHeating:false}`（裸对象）                                                                    |
| GET  | `/api/device/status`                   | 无                                                                               | 设备信息+控制状态               | 读缓存(1000H-1012H等)                       | `{code:0,message:"Success",data:{device:{...},control:{...}}}`                                         |
| GET  | `/api/modbus/read`                     | `address`(必填),`count`(缺省1,1-125)                                         | 读保持寄存器                    | 任意(03H)                                   | `{address,addressDec,count,values,hexValues}`                                                          |
| POST | `/api/modbus/write`                    | `address`,`value`(hex/dec)                                                   | 写单个保持寄存器                | 任意(06H)                                   | `{address,addressDec,value,hexValue,success:true}`                                                     |
| GET  | `/api/rtc/time`                        | 无                                                                               | 读 RTC 时间                     | 读101BH-101FH缓存                           | `{code:0,message:"success",data:{year,month,day,hour,minute,second,week,format,formatted[,meridiem]}}` |
| POST | `/api/rtc/time`                        | `time`/`timestamp` + 可选`format`(0/1)                                     | 设置 RTC 时间                   | 写101BH-101FH(10H,打包5寄存器;严格日历校验) | `{code:0,message:"success",data:{setTime,regValues,format,accepted:true}}`                             |
| GET  | `/api/idle/environment`                | 无                                                                               | 室内外环境数据                  | 读200DH-201AH缓存                           | `{code:200,data:{indoorReturnAir,outdoorAir,supplyAir,airQuality}}`                                    |
| GET  | `/api/idle/air-quality-reminder`       | 无                                                                               | 室内外空气评价提醒              | 读200FH/2013H缓存                           | `{code:200,data:{indoorPM25,outdoorPM25,indoorLevel,outdoorLevel,reminder}}`                           |

### 外部 API 接口

> `/getWeather`、`/getLocation` 为 ⏸ 暂不可用（规划改由 emc6069 模组提供数据接口，模组侧接口目前暂无），不列入已实现清单，见第十章。

### 系统硬件接口（真实 sysfs）

| 方法 | 路径                     | 参数                               | 功能                  | 寄存器           | 返回数据                                                                |
| ---- | ------------------------ | ---------------------------------- | --------------------- | ---------------- | ----------------------------------------------------------------------- |
| POST | `/setScreenSleep`      | `sleep`(缺省1)                   | 屏幕休眠/唤醒命令入队 | —(固定本机接口) | `{sleep:1,accepted:true}`                                             |
| GET  | `/getScreenBrightness` | 无                                 | 查询背光亮度快照      | —(sysfs/ioctl)  | `{min,max,current,available,pending,success,error}`                   |
| POST | `/setScreenBrightness` | `brightness`(必填，设备原生量程) | 亮度命令入队          | —(sysfs/ioctl)  | `{min,max,accepted:true}`                                             |
| GET  | `/getTempHumi`         | 无                                 | 温湿度传感器数据      | —(sysfs hwmon)  | `{temperature:26.6,humidity:49.7}`（真实 GXHTC3，失败回退 25.5/60.0） |
| GET  | `/getSensorSerial`     | 无                                 | 传感器序列号          | —(sysfs i2c)    | `{serial:"0x0887",available:true}`（真实 GXHTC3 serial_id）           |

### 基础服务接口

| 方法 | 路径                   | 参数 | 功能           | 寄存器   | 返回数据                                                                                                              |
| ---- | ---------------------- | ---- | -------------- | -------- | --------------------------------------------------------------------------------------------------------------------- |
| GET  | `/api/ping`          | 无   | 存活检测       | —       | `{pong:true}`                                                                                                       |
| GET  | `/api/health`        | 无   | 健康检查       | —       | `{status:"ok",server:"running",port:8080,uptime:"unknown"}`                                                         |
| GET  | `/api/version`       | 无   | 版本信息       | —       | `{version:"1.3.0",name:"BeiAng8Panel",...}`                                                                         |
| GET  | `/api/paths`         | 无   | 已注册路由列表 | —       | `{paths:[...]}`                                                                                                     |
| GET  | `/api/protocol/info` | 无   | 协议元信息     | —(静态) | `{code:0,message:"success",data:{protocolVersion:"V1.22",deviceAddress:209,supportedFunctionCodes,registerRanges}}` |

> 📌 **注**：`/api/rtc/time` GET 已升级为 ✅ 真实（读 101BH-101FH 周期采集缓存，见第六章 §7）。

---

## 快速参考表

| 路径                                     | 方法     | 状态 | 说明                                                                                                              |
| ---------------------------------------- | -------- | ---- | ----------------------------------------------------------------------------------------------------------------- |
| `/api/device/status`                   | GET      | ✅   | 设备状态 + 控制状态（内存数据）                                                                                   |
| `/api/device/power`                    | POST     | ✅   | 开关机（开机单写1001H=1，关机10H组写1001H-1003H全0；互斥联动由设备端执行）                         |
| `/api/device/mode`                     | POST     | ✅   | 新风运行模式切换（真实写 1007H，需 1001H=1；同 /api/freshair/runmode）                                            |
| `/api/device/leave-home`               | POST     | ✅   | 一键离家开关（真实写 1006H，v1.22）                                                                               |
| `/api/device/leave-home/status`        | GET      | ✅   | 一键离家状态（读 1006H 缓存，v1.3.9 新增）                                                                        |
| `/api/device/unit-run-mode/status`     | GET      | ✅   | 整机运行模式（读 100AH 缓存，v1.3.10 新增）                                                                       |
| `/api/device/factory-test/status`      | GET      | ✅   | 厂测模式状态（读 1030H 缓存，v1.3.11 新增）                                                                       |
| `/api/device/air-conditioner/presence` | GET      | ✅   | 空调有无（产品级静态 false，4CP 无空调，v1.4.2 新增）                                                             |
| `/api/device/floor-heating/presence`   | GET      | ✅   | 地暖有无（产品级静态 false，4CP 无地暖，v1.4.2 新增）                                                             |
| `/api/device/unit-run-mode`            | POST     | ✅   | 整机运行模式（真实写 100AH，v1.22：0-5）                                                                          |
| `/api/freshair/switch`                 | POST     | ✅   | 新风模块开关（真实写 1001H）                                                                                      |
| `/api/freshair/status`                 | GET      | ✅   | 新风状态（缓存：1001H/1007H/1008H/100CH/2003H/2004H，v1.3.3 起 6 字段）                                           |
| `/api/humidity-module/switch`          | POST     | ✅   | 调湿模块开关（真实写 1003H）                                                                                      |
| `/api/humidity-module/status`          | GET      | ✅   | 调湿状态（缓存：1003H/100FH）                                                                                     |
| `/api/super-pure/switch`               | POST     | ✅   | 超净模式开关（真实写 1002H）                                                                                      |
| `/api/super-pure/status`               | GET      | ✅   | 超净模式状态（缓存：1002H）                                                                                       |
| `/api/freshair/speed`                  | POST     | ✅   | 新风风速设定（真实写 1008H，需 1001H=1 且 1007H∈{0,1,2,4}）                                                      |
| `/api/freshair/runmode`                | POST     | ✅   | 新风运行模式设置（真实写 1007H，需 1001H=1）                                                                      |
| `/api/humidity-module/target`          | POST     | ✅   | 目标湿度设定（真实写 100FH，范围 30-70）                                                                          |
| `/api/humidity-module/humidify`        | POST     | ✅   | 加湿开关（真实写 1004H，1003H 调湿开启时只读）                                                                    |
| `/api/humidity-module/dehumidify`      | POST     | ✅   | 除湿开关（真实写 1005H，1003H 调湿开启时只读）                                                                    |
| `/api/freshair/exhaust-speed`          | POST     | ✅   | 排风风量档位（真实写 1009H，协议预留）                                                                            |
| `/api/freshair/stepless`               | POST     | ✅   | 无极风量控制开关（真实写 100BH）                                                                                  |
| `/api/freshair/duty`                   | POST     | ✅   | 风量占空比（真实写 100CH/100DH/100EH，0-100）                                                                     |
| `/api/device/target-temperature`       | POST     | ✅   | 目标温度设定（真实写 1010H，16.0-31.0℃×10）                                                                     |
| `/api/device/plasma-disinfect`         | POST     | ✅   | 等离子消毒开关（真实写 1011H）                                                                                    |
| `/api/device/aux-heat`                 | POST     | ✅   | 电辅热选择（真实写 1013H，0-3）                                                                                   |
| `/api/humidity-module/intensity`       | POST     | ✅   | 加湿/除湿强度（真实写 1014H，0-2）                                                                                |
| `/api/device/sa-fan-ratio`             | POST     | ✅   | SA风量与增压风机比例（真实写 1015H，×10）                                                                        |
| `/api/device/fan-delay-off`            | POST     | ✅   | 关机后延时关风机时间（真实写 1020H，分钟）                                                                        |
| `/api/device/compressor`               | POST     | ✅   | 压缩机设定（真实写 1028H-102AH，分组可选参数）                                                                    |
| `/api/device/factory-test`             | POST     | ✅   | 厂测模式（真实写 1030H；开启需 confirm=true，仅产线调试）                                                         |
| `/api/device/pressure-switch`          | POST     | ✅   | 高/低压开关（真实写 102BH/102CH，仅厂测模式可写）                                                                 |
| `/api/factory/fan`                     | POST     | ✅   | 厂测FAN风量设定（真实写 1038H-103BH，仅厂测模式可写）                                                             |
| `/api/factory/valve`                   | POST     | ✅   | 厂测阀门状态设定（真实写 103CH-103EH，仅厂测模式可写）                                                            |
| `/api/maintenance/filter`              | POST     | ✅   | 滤网/保养剩余时间复位（真实写 1031H-1036H，单位小时/天）                                                          |
| `/api/device/factory-reset`            | POST     | ✅   | 恢复出厂（真实写 1040H=1，需 confirm=true，高危）                                                                 |
| `/api/factory/fan-flow`                | POST     | ✅   | FAN内外循环档位风量标定（真实写 1041H-1070H，仅厂测模式可写）                                                     |
| `/api/factory/damper`                  | POST     | ✅   | 风阀方向/步数设定（真实写 1071H-1076H，仅厂测模式可写）                                                           |
| `/api/idle/environment`                | GET      | ✅   | 室内/室外/送风环境数据（数据采集线程周期 Modbus 读取，接口读缓存）                                                |
| `/api/idle/air-quality-reminder`       | GET      | ✅   | 室内外空气评价提醒（待机页面，依据周期采集的 200FH/2013H）                                                        |
| `/api/idle/status`                     | GET      | ❌   | 待机状态（未实现桩）                                                                                              |
| `/api/idle/control`                    | POST     | ❌   | 唤醒设备（未实现桩）                                                                                              |
| `/api/manual/status`                   | GET      | ❌   | 手动模式状态（未实现桩）                                                                                          |
| `/api/manual/control`                  | POST     | ❌   | 设置手动模式参数（未实现桩）                                                                                      |
| `/api/smart/status`                    | GET      | ❌   | 智能模式状态（未实现桩）                                                                                          |
| `/api/smart/control`                   | POST     | ❌   | 设置智能模式参数（未实现桩）                                                                                      |
| `/api/system/settings`                 | GET/POST | ❌   | 系统设置（未实现桩）                                                                                              |
| `/api/maintenance/status`              | GET      | ❌   | 滤网/维护状态（未实现桩）                                                                                         |
| `/api/maintenance/filter/reset`        | POST     | ❌   | 重置滤网寿命（未实现桩）                                                                                          |
| `/api/maintenance/fan/clear`           | POST     | ❌   | 清除风机运行时间（模拟）                                                                                          |
| `/api/engineering/status`              | GET      | ❌   | 工程模式数据（未实现桩）                                                                                          |
| `/api/engineering/control`             | POST     | ❌   | 工程模式控制（占位）                                                                                              |
| `/api/history/trend`                   | GET      | ✅   | 历史趋势桶序列 day/week/month（室内/外温湿/PM2.5/CO₂，UDISK 采样落盘）                                           |
| `/api/history/status`                  | GET      | ✅   | 历史采样与存储诊断状态                                                                                            |
| `/api/memwatch/status`                 | GET      | ✅   | 内存水位监控状态（MemAvailable/分级处置/事件记录）                                                                |
| `/api/modbus/read`                     | GET      | ✅   | 读保持寄存器（真实 03H）                                                                                          |
| `/api/modbus/write`                    | POST     | ✅   | 写单个保持寄存器（真实 06H）                                                                                      |
| `/api/modbus/write-multiple`           | POST     | ❌   | 批量写寄存器（模拟，未下发）                                                                                      |
| `/api/modbus/read-discrete`            | GET      | ❌   | 读离散输入（模拟）                                                                                                |
| `/api/device/capabilities`             | GET      | ⚠️ | 设备能力（模拟）                                                                                                  |
| `/api/device/faults`                   | GET      | ⚠️ | 故障状态（模拟）                                                                                                  |
| `/api/device/faults/clear`             | POST     | ❌   | 清除故障（模拟）                                                                                                  |
| `/api/device/off-mode/air-quality`     | GET      | ⚠️ | 关机下空气检测设置（模拟）                                                                                        |
| `/api/device/off-mode/air-quality`     | POST     | ❌   | 设置关机检测参数（模拟）                                                                                          |
| `/api/humidification/status`           | GET      | ⚠️ | 加湿系统状态（模拟）                                                                                              |
| `/api/humidification/control`          | POST     | ❌   | 设置加湿参数（模拟）                                                                                              |
| `/api/rtc/time`                        | GET      | ✅   | RTC 时间（读 101BH-101FH 缓存；12h 制 hour 归一 24h+meridiem）                                                    |
| `/api/rtc/time`                        | POST     | ✅   | 设置 RTC 时间（真实写设备 101BH-101FH，结构体打包）                                                               |
| `/api/ota/status`                      | GET      | ✅   | OTA 升级状态总览（版本/进度/状态机）                                                                              |
| `/api/ota/start`                       | POST     | ✅   | 立即更新/重试（确认模组开始 http 传输）                                                                           |
| `/api/ota/cancel`                      | POST     | ✅   | 下次再说/退出（可清理已下载文件）                                                                                 |
| `/api/protocol/info`                   | GET      | ✅   | 协议信息（静态元数据）                                                                                            |
| `/getSensors`                          | GET      | ⚠️ | 全部传感器数据（模拟）                                                                                            |
| `/getAirQuality`                       | GET      | ⚠️ | 空气质量数据（模拟）                                                                                              |
| `/getTempHumi`                         | GET      | ✅   | 温湿度（真实 GXHTC3 sysfs hwmon）                                                                                 |
| `/setScreenSleep`                      | POST     | ✅   | 屏幕休眠/唤醒（真实 sysfs）                                                                                       |
| `/getScreenBrightness`                 | GET      | ✅   | 屏幕背光亮度（真实 sysfs）                                                                                        |
| `/setScreenBrightness`                 | POST     | ✅   | 设置屏幕背光亮度（真实 sysfs）                                                                                    |
| `/getWifiInfo`                         | GET      | ✅   | WiFi 扫描结果缓存（兼容路径）                                                                                     |
| `/getConnectedWifi`                    | GET      | ✅   | WiFi 当前状态缓存（兼容路径）                                                                                     |
| `/wifiOpen`                            | POST     | ✅   | WiFi 开关命令入队（兼容路径）                                                                                     |
| `/connectWifi`                         | POST     | ✅   | WiFi 连接命令入队（兼容路径）                                                                                     |
| `/disconnectWifi`                      | POST     | ✅   | WiFi 断开命令入队（兼容路径）                                                                                     |
| `/setHumanPresenceRadar`               | POST     | ✅   | 人感雷达开关（TRMK222 UART，命令文件→daemon）                                                                    |
| `/getHumanPresenceRadar`               | GET      | ✅   | 人感雷达状态（TRMK222 daemon 状态文件）                                                                           |
| `/setAQILed`                           | POST     | ✅   | AQI 指示灯（9路RGB 呼吸效果，rgb_daemon FIFO，回退 sysfs）                                                        |
| `/setSpeaker`                          | POST     | ❌   | 扬声器开关（模拟）                                                                                                |
| `/getWeather`                          | GET      | ⏸   | 实时天气（**暂不可用**：改由 emc6069 模组提供，接口暂无；原 libcurl 出网路径在无 Linux 网络出口架构下 500） |
| `/getLocation`                         | GET      | ⏸   | 区域信息（**暂不可用**：同上）                                                                              |
| `/api/ping`                            | GET      | ✅   | 存活检测                                                                                                          |
| `/api/health`                          | GET      | ✅   | 健康检查                                                                                                          |
| `/api/version`                         | GET      | ✅   | 版本信息                                                                                                          |
| `/api/paths`                           | GET      | ✅   | 已注册路由列表                                                                                                    |

---

## 一、设备控制 API

### 1. 获取设备状态 `GET /api/device/status` ✅

读取 `DataManager` 缓存的设备信息与控制状态。

| 项目           | 说明                                                                      |
| -------------- | ------------------------------------------------------------------------- |
| **参数** | 无                                                                        |
| **实现** | `HomePage::getHomeData()`，读取内存中的 `GatewayGeneralDataStructure` |

**实际响应**：

```json
{
  "code": 0,
  "message": "Success",
  "data": {
    "device": {
      "factoryFlag": "BA",
      "deviceModel": "4CP",
      "version": "1.01",
      "deviceAddress": 209
    },
    "control": {
      "switchOn": false,
      "runMode": 0,
      "leaveHomeOn": false,
      "wholeUnitRunMode": 0,
      "autoCirculationDisplay": 0,
      "iefPurification": false,
      "fanGear": 0,
      "fanMaxGear": 6,
      "auxHeat": 0,
      "humidificationOn": false,
      "dehumidificationOn": false
    }
  }
}
```

**字段说明**：

- `device.factoryFlag` (string): 工厂标志（"BA"）
- `device.deviceModel` (string): 机型
- `device.version` (string): 固件版本（输入寄存器 2002H 原始值÷100，如 0101→"1.01"）
- `device.deviceAddress` (int): 设备地址（默认 209）
- `control.switchOn` (bool): 开关状态
- `control.runMode` (int): 运行模式（见枚举 `AirCirculationMode`/`OperationMode`，0-5）
- `control.leaveHomeOn` (bool): 一键离家开关（1006H，v1.22 由手动/自动改为一键离家）
- `control.wholeUnitRunMode` (int): 整机运行模式（100AH，v1.22 新增：0无/手动 1标准 2会客 3干爽 4温润 5旅行）
- `control.autoCirculationDisplay` (int): 1007H 为自动模式(3)时的实际内外循环显示（201DH：0内循环 1内循环/混风 2全热新风/节能新风）
- `control.iefPurification` (bool): IEF 净化开关
- `control.fanGear` (int): 风量档位（0-6）
- `control.fanMaxGear` (int): 最大风量档位（真实读自输入寄存器 2003H；示例设备为 6）
- `control.auxHeat` (int): 电辅热（0=关 / 1=辅热1 / 2=辅热2 / 3=辅热1和2）
- `control.humidificationOn` (bool): 加湿开关
- `control.dehumidificationOn` (bool): 除湿开关

**curl**：`curl "http://localhost:8080/api/device/status"`

### 2. 快捷电源控制 `POST /api/device/power` ✅

| 项目             | 说明                                                                                                            |
| ---------------- | --------------------------------------------------------------------------------------------------------------- |
| **请求体** | `{"power": true}` （`power` 布尔，缺省 `true`）                                                           |
| **实现**   | `ModbusCommandModule::submitModuleState`：开机单写 06H `1001H=1`；关机 10H 组写 `1001H/1002H/1003H=0,0,0` |

**实际响应**（裸对象，无 `code` 外层）：

```json
{ "accepted": true, "power": true }
```

> 📌 **当前语义**：模块开关单写对应寄存器，互斥联动由 4CP 设备按 v1.22 执行，写后读回反映实际状态；快捷开机单写 `1001H=1`，快捷关机写入 `1001H..1003H=0,0,0`。
> ⚠️ **失败场景**：命令队列不可用/保持寄存器缓存未建立 → HTTP 503。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"power":true}' "http://localhost:8080/api/device/power"`

### 3. 快捷模式切换 `POST /api/device/mode` ✅

| 项目             | 说明                                                                                                     |
| ---------------- | -------------------------------------------------------------------------------------------------------- |
| **请求体** | `{"mode": 1}` （`mode` 整数，缺省 `1`，范围 `0-5`）                                              |
| **实现**   | `ModbusCommandModule::submitFreshControl` → 06H 写 `1007H`（与 `/api/freshair/runmode` 同一路径） |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "mode": 2 } }
```

> ⚠️ **注意**：此处的 `mode` 参数对应**新风运行模式 `runMode`（空气循环模式 0-5）**，并非「待机/手动/智能」工作模式。真实写设备，**前置条件 `1001H=1`**（新风模块开启），否则 HTTP 400 `{"code":400,"message":"新风模块未开启，该控制项只读"}`；`mode` 超出 0-5 → HTTP 400 `{"code":400,"message":"运行模式必须在0-5之间"}`。
>
> 🆕 **v1.22 相关**：整机运行模式（0无/手动 1标准 2会客 3干爽 4温润 5旅行）请使用 `POST /api/device/unit-run-mode`（真实写 100AH）；一键离家开关使用 `POST /api/device/leave-home`（真实写 1006H）。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"mode":2}' "http://localhost:8080/api/device/mode"`

### 4. 新风模块开关 `POST /api/freshair/switch` ✅

真实写入保持寄存器 **1001H**：开启写 `1`、关闭写 `0`；互斥联动由 4CP 设备按 v1.22 执行。

| 项目             | 说明                                                          |
| ---------------- | ------------------------------------------------------------- |
| **请求体** | `{"on": true}` （`on` 布尔，必填）                        |
| **实现**   | `ModbusCommandModule::submitModuleSwitch` → 06H 单写 1001H |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "on": true } }
```

> ⚠️ **失败场景**：`on` 缺失或非布尔 → HTTP 400 `{"code":400,"message":"参数 on（布尔）必填"}`；命令队列不可用/缓存未建立 → HTTP 503。
>
> 📌 **相关协议**：1001H 仅与 1002H（超净）互斥，与 1003H（调湿）可共存。后端只下发 1001H 单寄存器写，设备端负责联动；联动结果经读回反映（生效需数秒）；1001H 关闭后 1007H/1008H 变为只读。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/freshair/switch"`

### 5. 查询新风状态 `GET /api/freshair/status` ✅

读取 `DataManager` 缓存中的新风模块控制状态（数据采集线程周期 Modbus 读取刷新）。

**实际响应**（裸对象，v1.3.3 起按规格返回 6 个寄存器字段）：

```json
{
  "freshAirModuleOn": true,   // 1001H 新风模块开关
  "runMode": 2,               // 1007H 新风运行模式（0内循环 1内循环/混风 2全热新风/节能新风 3自动 4旁通/换气 5睡眠）
  "fanGear": 3,               // 1008H 风量档位（0-6）
  "freshFanDutyCycle": 65,    // 100CH 新风风量占空比（0-100%，寄存器值即百分比，v1.3.3 新增）
  "fanMaxGear": 3,            // 2003H 新风模式风量最大档位
  "fanMaxGearRecirc": 5       // 2004H 内循环/混风模式风量最大档位
}
```

| 字段                  | 寄存器 | 说明                                                                                  |
| --------------------- | ------ | ------------------------------------------------------------------------------------- |
| `freshAirModuleOn`  | 1001H  | 新风模块开关（bool）                                                                  |
| `runMode`           | 1007H  | 运行模式（0 内循环，1 内循环/混风，2 全热新风/节能新风，3 自动，4 旁通/换气，5 睡眠） |
| `fanGear`           | 1008H  | 风量档位（0-6；写权限=1001H=1 且 1007H∈{0,1,2,4}）                                   |
| `freshFanDutyCycle` | 100CH  | 新风风量占空比（0-100%，v1.3.3 新增）                                                 |
| `fanMaxGear`        | 2003H  | 新风模式风量最大档位（1008H 写校验上限之一）                                          |
| `fanMaxGearRecirc`  | 2004H  | 内循环/混风模式风量最大档位（1008H 写校验上限之一）                                   |

> 📌 v1.3.3 移除了旧字段 `leaveHomeOn`（1006H，一键离家经 `/api/device/leave-home` 控制）与 `autoCirculationDisplay`（201DH）。

**curl**：`curl "http://localhost:8080/api/freshair/status"`

### 6. 调湿模块开关 `POST /api/humidity-module/switch` ✅

真实写入保持寄存器 **1003H**：开启写 `1`、关闭写 `0`；互斥联动由 4CP 设备按 v1.22 执行。

| 项目             | 说明                                                          |
| ---------------- | ------------------------------------------------------------- |
| **请求体** | `{"on": true}` （`on` 布尔，必填）                        |
| **实现**   | `ModbusCommandModule::submitModuleSwitch` → 06H 单写 1003H |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "on": true } }
```

> ⚠️ **失败场景**：`on` 缺失或非布尔 → HTTP 400 `{"code":400,"message":"参数 on（布尔）必填"}`；命令队列不可用/缓存未建立 → HTTP 503。
>
> 📌 **相关协议**：1003H 仅与 1002H（超净）互斥（与新风 1001H 可共存）。后端只下发 1003H 单寄存器写，设备端负责联动；调湿开启时 1004H（加湿）、1005H（除湿）变为只读。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/humidity-module/switch"`

### 7. 查询调湿模块状态 `GET /api/humidity-module/status` ✅

读取 `DataManager` 缓存中的调湿模块状态（数据采集线程周期 Modbus 读取刷新）。

**实际响应**（裸对象）：

```json
{
  "humidityModuleOn": true,     // 1003H 调湿模块开关
  "humidificationOn": false,    // 1004H 加湿开关
  "dehumidificationOn": false,  // 1005H 除湿开关
  "targetHumidity": 50          // 100FH 目标湿度设定（30-70）
}
```

| 字段                   | 寄存器 | 说明                                           |
| ---------------------- | ------ | ---------------------------------------------- |
| `humidityModuleOn`   | 1003H  | 调湿模块开关（bool）                           |
| `humidificationOn`   | 1004H  | 加湿开关（bool；1003H 开启时只读，由设备控制） |
| `dehumidificationOn` | 1005H  | 除湿开关（bool；1003H 开启时只读，由设备控制） |
| `targetHumidity`     | 100FH  | 目标湿度设定（%，范围 30-70）                  |

**curl**：`curl "http://localhost:8080/api/humidity-module/status"`

### 8. 超净模式开关 `POST /api/super-pure/switch` ✅

真实写入保持寄存器 **1002H**：开启写 `1`、关闭写 `0`；互斥联动由 4CP 设备按 v1.22 执行。

| 项目             | 说明                                                          |
| ---------------- | ------------------------------------------------------------- |
| **请求体** | `{"on": true}` （`on` 布尔，必填）                        |
| **实现**   | `ModbusCommandModule::submitModuleSwitch` → 06H 单写 1002H |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "on": true } }
```

> ⚠️ **失败场景**：`on` 缺失或非布尔 → HTTP 400 `{"code":400,"message":"参数 on（布尔）必填"}`；命令队列不可用/缓存未建立 → HTTP 503。
>
> 📌 **相关协议**：1002H 与 1001H（新风）、1003H（调湿）互斥——后端只下发 1002H 单寄存器写，设备端负责联动，联动结果经读回反映（生效需数秒）。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/super-pure/switch"`

### 9. 查询超净模式状态 `GET /api/super-pure/status` ✅

读取 `DataManager` 缓存中的超净模式开关状态（数据采集线程周期 Modbus 读取刷新）。

**实际响应**（裸对象）：

```json
{
  "superPureOn": true   // 1002H 超净模式开关
}
```

| 字段            | 寄存器 | 说明                 |
| --------------- | ------ | -------------------- |
| `superPureOn` | 1002H  | 超净模式开关（bool） |

**curl**：`curl "http://localhost:8080/api/super-pure/status"`

### 10. 新风风速设定 `POST /api/freshair/speed` ✅

真实写入保持寄存器 **1008H**（风量档位）。**可写前置条件**：`1001H=1`（新风模块开启）且 `1007H∈{0,1,2,4}`（内循环/混风/全热新风/旁通换气）；`1007H=3`（自动）或 `5`（睡眠）时 1008H 只读。

| 项目             | 说明                                                                                                            |
| ---------------- | --------------------------------------------------------------------------------------------------------------- |
| **请求体** | `{"speed": 3}` （`speed` 整数，必填，范围 `0-6`）                                                         |
| **实现**   | `ModbusCommandModule::submitFreshControl` → 06H 写 1008H（策略层白名单 `1007H∈{0,1,2,4}` + 档位上限校验） |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "speed": 3 } }
```

> ⚠️ **失败场景**：
>
> - `speed` 缺失/非整数 → HTTP 400 `{"code":400,"message":"参数 speed（整数）必填"}`
> - `speed` 超出 0-6 → HTTP 400 `{"code":400,"message":"风量档位必须在0-6之间"}`
> - **新风模块未开启**（1001H=0）→ HTTP 400 `{"code":400,"message":"新风模块未开启，该控制项只读"}`
> - **自动/睡眠运行模式**（1007H=3 或 5）→ HTTP 400 `{"code":400,"message":"当前运行模式(1007H=3自动/5睡眠)下风量档位只读"}`
> - **超过当前模式档位上限**（模式2受 2003H、模式0/1/4受 2004H 约束）→ HTTP 400 `{"code":400,"message":"风量档位超过设备当前模式的最大档位"}`
> - 网关不可用 → HTTP 503；寄存器写入失败 → HTTP 500
>
> 📌 **相关协议**：4CP 新风模式最大档为 3 档，其他最大可控为 5 档，超净模式开启时显示为 6 档——前端应根据 `2003H`/`2004H` 的档位上限约束可选项。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"speed":3}' "http://localhost:8080/api/freshair/speed"`

### 11. 新风运行模式设置 `POST /api/freshair/runmode` ✅

真实写入保持寄存器 **1007H**（新风模块运行模式）。**可写前置条件**：`1001H=1`（新风模块开启）；否则 1007H 只读。

| 项目             | 说明                                                                           |
| ---------------- | ------------------------------------------------------------------------------ |
| **请求体** | `{"mode": 2}` （`mode` 整数，必填，范围 `0-5`）                          |
| **实现**   | `ModbusCommandModule::submitFreshControl` → 06H 写 1007H（策略层 0-5 校验） |

**mode 取值**（v1.22 扩展为 0-5）：

| mode | 含义                                  |
| ---- | ------------------------------------- |
| 0    | 内循环                                |
| 1    | 内循环/混风                           |
| 2    | 全热新风/节能新风                     |
| 3    | 自动模式（实际内外循环由 201DH 显示） |
| 4    | 旁通/换气                             |
| 5    | 睡眠模式                              |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "mode": 2 } }
```

> ⚠️ **失败场景**：
>
> - `mode` 缺失/非整数 → HTTP 400 `{"code":400,"message":"参数 mode（整数）必填"}`
> - `mode` 超出 0-5 → HTTP 400 `{"code":400,"message":"运行模式必须在0-5之间"}`
> - **新风模块未开启**（1001H=0）→ HTTP 400 `{"code":400,"message":"新风模块未开启，该控制项只读"}`
> - 网关不可用 → HTTP 503；寄存器写入失败 → HTTP 500
>
> 📌 **相关协议**：仅 1001H 开启时可写。风量档位 1008H 的写权限 = `1001H=1 且 1007H∈{0,1,2,4}`；切到 1007H=3（自动）或 5（睡眠）后 1008H 转为只读。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"mode":2}' "http://localhost:8080/api/freshair/runmode"`

### 12. 目标湿度设定 `POST /api/humidity-module/target` ✅

真实写入保持寄存器 **100FH**（目标湿度设定）。

| 项目             | 说明                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------ |
| **请求体** | `{"humidity": 50}` （`humidity` 整数，必填，范围 `30-70`）                     |
| **实现**   | `ModbusCommandModule::submitSingleWrite` → 06H 写 100FH（HTTP 层 30-70 范围校验） |

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "accepted": true, "humidity": 50 } }
```

> ⚠️ **失败场景**：
>
> - `humidity` 缺失/非整数 → HTTP 400 `{"code":400,"message":"参数 humidity（整数）必填"}`
> - `humidity` 超出 30-70 → HTTP 400 `{"code":400,"message":"目标湿度必须在30-70之间"}`
> - 网关不可用 → HTTP 503；寄存器写入失败 → HTTP 500
>
> 📌 **相关协议**：目标湿度设定与调湿模块开关（1003H）独立——设定后即使 1003H 当前关闭，值仍会保存。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"humidity":50}' "http://localhost:8080/api/humidity-module/target"`

### 12a. 加湿开关 `POST /api/humidity-module/humidify` ✅

真实写入保持寄存器 **1004H**（加湿开关）。**可写前置条件**：`1003H=0`（调湿模块关闭）；调湿模块开启时 1004H/1005H 由设备内部控制、界面只读。

| 项目             | 说明                                                          |
| ---------------- | ------------------------------------------------------------- |
| **请求体** | `{"on": true}` （`on` 布尔，必填）                        |
| **实现**   | `ModbusCommandModule::submitHumiditySwitch` → 06H 写 1004H |

**实际响应**（裸对象）：`{ "accepted": true, "on": true }`

> ⚠️ **失败场景**：`on` 缺失/非布尔 → HTTP 400；**调湿模块开启**（1003H=1）→ HTTP 400 `{"code":400,"message":"调湿模块开启(1003H=1)，加湿/除湿开关只读"}`；命令队列不可用 → HTTP 503。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/humidity-module/humidify"`

### 12b. 除湿开关 `POST /api/humidity-module/dehumidify` ✅

真实写入保持寄存器 **1005H**（除湿开关）。前置条件与失败场景同上（1003H 开启时只读）。

| 项目             | 说明                                                          |
| ---------------- | ------------------------------------------------------------- |
| **请求体** | `{"on": true}` （`on` 布尔，必填）                        |
| **实现**   | `ModbusCommandModule::submitHumiditySwitch` → 06H 写 1005H |

**实际响应**（裸对象）：`{ "accepted": true, "on": true }`

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/humidity-module/dehumidify"`

### 12c. 排风风量档位 `POST /api/freshair/exhaust-speed` ✅（协议预留寄存器）

真实写入保持寄存器 **1009H**（排风风量档位，协议标注预留）。协议未定义写前置条件，仅做 0-6 范围校验；设备实际行为以固件为准。

| 项目             | 说明                                                       |
| ---------------- | ---------------------------------------------------------- |
| **请求体** | `{"speed": 2}` （`speed` 整数，必填，范围 `0-6`）    |
| **实现**   | `ModbusCommandModule::submitSingleWrite` → 06H 写 1009H |

**实际响应**（裸对象）：`{ "accepted": true, "speed": 2 }`

> ⚠️ **失败场景**：`speed` 缺失/非整数或超出 0-6 → HTTP 400；命令队列不可用 → HTTP 503。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"speed":2}' "http://localhost:8080/api/freshair/exhaust-speed"`

### 13. 一键离家开关 `POST /api/device/leave-home` ✅ / `GET /api/device/leave-home/status` ✅（v1.22 新增）

真实写入保持寄存器 **1006H**。v1.22 中 1006H 由"新风模块手动/自动"改为"一键离家开关"。

| 项目                  | 说明                                                                |
| --------------------- | ------------------------------------------------------------------- |
| **POST 请求体** | `{"on": true}` （`on` 布尔，必填）                              |
| **实现**        | `ModbusCommandModule::submitSingleWrite` → 06H 写 1006H          |
| **GET**         | 读周期采集缓存，返回`{"leaveHomeOn":true}`（裸对象，v1.3.9 新增） |

**POST 实际响应**（裸对象）：

```json
{ "accepted": true, "on": true }
```

**GET 实际响应**（裸对象）：

```json
{ "leaveHomeOn": true }
```

> ⚠️ **失败场景**：`on` 缺失或非布尔 → HTTP 400；命令队列不可用 → HTTP 503。
>
> ⚠️ **设备侧行为注意**（2026-09-03 台架实测）：4CP 设备固件会对 1006H 做**自主翻转**（无面板写操作时寄存器也会 0↔1 变化，疑似设备内部离家逻辑/定时）。面板读写链路本身正确（06H 帧可正常落位、读回跟随）；排障时先连续裸读寄存器确认是否设备侧自翻转，勿误判面板写失效。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"on":true}' "http://localhost:8080/api/device/leave-home"`

### 14. 整机运行模式 `POST /api/device/unit-run-mode` ✅ / `GET /api/device/unit-run-mode/status` ✅（v1.22 新增）

真实写入保持寄存器 **100AH**。v1.22 中 100AH 由"增压风量档位(预留)"改为"整机运行模式"。

| 项目                  | 说明                                                                   |
| --------------------- | ---------------------------------------------------------------------- |
| **POST 请求体** | `{"mode": 1}` （`mode` 整数，必填，范围 `0-5`）                  |
| **实现**        | `ModbusCommandModule::submitSingleWrite` → 06H 写 100AH             |
| **GET**         | 读周期采集缓存，返回`{"wholeUnitRunMode":1}`（裸对象，v1.3.10 新增） |

**mode 取值**：

| mode | 含义                  |
| ---- | --------------------- |
| 0    | 无（对应8寸屏：手动） |
| 1    | 标准                  |
| 2    | 会客                  |
| 3    | 干爽                  |
| 4    | 温润                  |
| 5    | 旅行                  |

**POST 实际响应**（裸对象）：

```json
{ "accepted": true, "mode": 1 }
```

**GET 实际响应**（裸对象）：

```json
{ "wholeUnitRunMode": 1 }
```

> ⚠️ **失败场景**：`mode` 缺失/非整数 → HTTP 400；超出 0-5 → HTTP 400；命令队列不可用 → HTTP 503。
>
> ⚠️ **设备侧行为注意**（2026-09-03 台架实测）：设备对 100AH 的场景切换为**异步执行**——先 ACK 写帧，内部忙于切换时新写入会被缓冲延后应用（实测出现过"写 2 未生效、下一写 0 后变成 2"的延迟落位）。连续设定整机模式建议间隔数秒并读回确认。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"mode":1}' "http://localhost:8080/api/device/unit-run-mode"`

### 15. 风量与环境设定接口组（v1.22 补全）✅

以下接口均为"参数校验 → 写命令队列（06H）→ 写后回读确认"的同一模式，无协议写前置条件：

| 接口                                    | 寄存器            | 请求体                                   | 范围/换算                                                   |
| --------------------------------------- | ----------------- | ---------------------------------------- | ----------------------------------------------------------- |
| `POST /api/freshair/stepless`         | 100BH             | `{"on":true}`                          | 无极风量控制开关 0/1                                        |
| `POST /api/freshair/duty`             | 100CH/100DH/100EH | `{"fresh":60,"exhaust":50,"boost":40}` | 占空比 0-100；至少一项，未提供的通道不写                    |
| `POST /api/device/target-temperature` | 1010H             | `{"temperature":25.0}`                 | 16.0-31.0℃；寄存器存实际温度×10（160-310），响应附`raw` |
| `POST /api/device/plasma-disinfect`   | 1011H             | `{"enabled":true}`                     | 等离子消毒开关 0/1                                          |
| `POST /api/device/aux-heat`           | 1013H             | `{"mode":1}`                           | 0关/1辅热1/2辅热2/3辅热1+2（运行状态读 201CH）              |
| `POST /api/humidity-module/intensity` | 1014H             | `{"intensity":1}`                      | 0弱/1中/2强                                                 |
| `POST /api/device/sa-fan-ratio`       | 1015H             | `{"ratio":1.8}`                        | 实际值×10 写入（1.8→18），响应附`raw`                   |
| `POST /api/device/fan-delay-off`      | 1020H             | `{"minutes":5}`                        | 0-65535 分钟                                                |

**实际响应**（统一**裸对象**格式，以 target-temperature 为例）：

```json
{ "accepted": true, "temperature": 25.0, "raw": 250 }
```

> ⚠️ **失败场景**：参数缺失/类型错误/超出范围 → HTTP 400（含具体范围提示）；命令队列不可用 → HTTP 503。
>
> 📌 **相关协议**：
>
> - 1016H-101AH 为预留寄存器，后端不读不写；
> - 1013H 的**设定值**经 `/api/runtime/snapshot` 的 `deviceControlParams.auxHeatSettingRaw` 发布，**运行状态**为输入寄存器 201CH（`controlStatus.auxHeat`）；
> - **1024H 设备地址无语义接口**（故意不暴露）：修改后设备立即切换 Modbus 从站地址，后端 `device.address` 配置不会跟随，会导致通信失联；确需修改时用 `/api/modbus/write` 裸写并同步改配置重启。

### 16. 压缩机 / 厂测 / 滤网复位接口组（v1.22 补全）✅

| 接口                                    | 寄存器      | 请求体                                                      | 说明                                                                                                      |
| --------------------------------------- | ----------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `POST /api/device/compressor`         | 1028H-102AH | `{"eevOpening":300,"frequencySet":60,"frequencyMax":90}`  | 分组可选参数（至少一项）：开度0-500、频率0-90Hz、上限60-95Hz                                              |
| `POST /api/device/factory-test`       | 1030H       | `{"enabled":true,"confirm":true}`                         | 100=测试模式；**开启必须携带 `confirm:true`**，正常业务勿用；`{"enabled":false}` 退出           |
| `GET /api/device/factory-test/status` | 1030H缓存   | —                                                          | 裸对象`{factoryTestMode, factoryTestActive}`；`active` 即 `1030H==100` 判定，v1.3.11 新增           |
| `POST /api/device/pressure-switch`    | 102BH/102CH | `{"switch":"high","on":true}`                             | 🔒仅厂测模式（1030H=100）可写，否则 400                                                                   |
| `POST /api/factory/fan`               | 1038H-103BH | `{"fan":1,"value":600}`                                   | 🔒仅厂测模式可写                                                                                          |
| `POST /api/factory/valve`             | 103CH-103EH | `{"valve":1,"status":2}`                                  | 🔒仅厂测模式可写；0关/1半开/2全开                                                                         |
| `POST /api/maintenance/filter`        | 1031H-1036H | `{"filter1":2000,"wholeUnit":365}`                        | 复位滤网提醒；`filter1-3`/`humidityModule`/`ief` 单位**小时**，`wholeUnit` 单位**天** |
| `POST /api/device/factory-reset`      | 1040H       | `{"confirm":true}`                                        | ⚠️只写高危：整机恢复出厂、参数全重置；**必须 confirm=true**，业务层严禁随意调用                   |
| `POST /api/factory/fan-flow`          | 1041H-1070H | `{"fan":1,"circulation":"external","gear":1,"value":300}` | 🔒仅厂测模式可写；产线标定参数，业务层只操作 1008H 档位                                                   |
| `POST /api/factory/damper`            | 1071H-1076H | `{"damper":1,"direction":0,"steps":2000}`                 | 🔒仅厂测模式可写；与阀门状态设定（103CH-103EH）配套的步进电机参数                                         |

**实际响应**（统一**裸对象** `{accepted:true,...}` 格式，分组接口附 `updated` 数组；400/503 错误为 `{code,message}` 封装）。

> 📌 **厂测锁**：🔒 接口在后端就按缓存中 `1030H==100`（`factoryTestSettings.factoryTestActive`）做前置校验，未进厂测模式直接拒绝（HTTP 400 `"厂测模式未开启(1030H≠100)，该寄存器只读"`）；预留寄存器 102DH-102FH/1037H 后端不读不写；103FH/1040H 为只写命令寄存器，读值无意义、后端不解析发布。厂测范围含 102BH/102CH、1038H-103EH、1041H-1070H、1071H-1076H。

---

## 二、待机与环境数据 API

### 1. 获取环境数据 `GET /api/idle/environment` ✅

返回室内回风(RA)、室外新风(OA)、送风(SA) 的温湿度/PM2.5/CO2，以及 TVOC 与甲醛。数据来源为**数据采集线程周期采集的缓存**：`DataAcquisitionModule` 通过 Modbus 04H 读取输入寄存器 `2000H-203BH` 全量写入 `DataManager`，本接口持数据锁纯读 `m_gatewayData` 缓存，不再实时发起 Modbus 读（网关不可用不影响本接口，仅返回缓存/默认值）。

| 项目           | 说明                                                                                                                                                                                |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **参数** | 无                                                                                                                                                                                  |
| **实现** | `IdlePage::getEnvironmentData()`，读取 `m_gatewayData` 的 RA1/OA/SA/空气质量缓存（RA1=`200DH-2010H`、OA=`2011H-2014H`、SA=`2015H-2018H`、TVOC=`2019H`、甲醛=`201AH`） |

**实际响应**（注意 `code` 为 `200`；所有数值均为四舍五入后的**整数**，无小数部分）：

```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "indoorReturnAir": { "temperature": 25, "humidity": 65, "pm25": 35, "co2": 450 },
    "outdoorAir":      { "temperature": 28, "humidity": 70, "pm25": 42, "co2": 380 },
    "supplyAir":       { "temperature": 25, "humidity": 62, "pm25": 28, "co2": 420 },
    "airQuality":      { "tvoc": 0, "formaldehyde": 0 }
  }
}
```

**字段说明**（均为整数，由原始 float 经 `std::lround` 四舍五入得到）：

- `indoorReturnAir` (object): 室内回风 RA1（200DH-2010H）。`temperature`(℃，整数) / `humidity`(%RH) / `pm25`(μg/m³) / `co2`(ppm)
- `outdoorAir` (object): 室外新风 OA（2011H-2014H），字段同上
- `supplyAir` (object): 送风 SA（2015H-2018H），字段同上
- `airQuality.tvoc` (int): TVOC（2019H）
- `airQuality.formaldehyde` (int): 甲醛（201AH）

**错误响应**（`code` 为 `1003`，随 HTTP 200 返回）：

- 内部异常：`{"code":1003,"message":"Internal server error: <详情>"}`
- ⚠️ 本接口不再因网关不可用/读取失败而报错（纯读缓存），仅可能在异常分支触发上述 1003。

**curl**：`curl "http://localhost:8080/api/idle/environment"`

### 2. 室内外空气评价提醒 `GET /api/idle/air-quality-reminder` ✅

供**待机页面**显示的室内外空气综合评价提醒。依据室内 PM2.5（输入寄存器 `200FH` / RA1）与室外 PM2.5（`2013H` / OA）综合判定。数据与 `/api/idle/environment` 同源——**纯读数据采集线程周期采集的缓存**（`m_gatewayData`），不再实时发起 Modbus 读。

**PM2.5 分级标准**（μg/m³）：优 `0~35` / 良 `36~75` / 中 `76~150` / 差 `151~999`

| 项目           | 说明                                                                         |
| -------------- | ---------------------------------------------------------------------------- |
| **参数** | 无                                                                           |
| **实现** | `IdlePage::getAirQualityReminder()`，读取 `m_gatewayData` 的 RA1/OA 缓存 |

**提醒文案规则**（室内 × 室外 等级组合）：

| 序号 | 室内                                | 室外 | `reminder`                                                                 |
| ---- | ----------------------------------- | ---- | ---------------------------------------------------------------------------- |
| 1    | 优/良                               | 中   | 室内空气质量优良，室外空气质量一般，建议减少室外活动                         |
| 2    | 优/良                               | 差   | 室内空气质量优良，室外空气质量较差，建议减少室外活动                         |
| 3    | 中                                  | 中   | 室内空气质量一般，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动 |
| 4    | 中                                  | 差   | 室内空气质量一般，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动 |
| 5    | 差                                  | 中   | 室内空气质量较差，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动 |
| 6    | 差                                  | 差   | 室内空气质量较差，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动 |
| 7    | 其余组合（含室外为优/良的任意情况） | —   | （空字符串）                                                                 |

**实际响应**（示例：室内 35(优) / 室外 80(中) → 命中规则 1；`code` 为 `200`，与 `/api/idle/environment` 一致）：

```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "indoorPM25": 35,
    "outdoorPM25": 80,
    "indoorLevel": "优",
    "outdoorLevel": "中",
    "reminder": "室内空气质量优良，室外空气质量一般，建议减少室外活动"
  }
}
```

**字段说明**（PM2.5 数值由原始 float 经 `std::lround` 四舍五入为整数；`reminder` 为空字符串时前端不展示提醒）：

- `indoorPM25` (int): 室内 PM2.5（`200FH`，μg/m³）
- `outdoorPM25` (int): 室外 PM2.5（`2013H`，μg/m³）
- `indoorLevel` (string): 室内等级，`优`/`良`/`中`/`差`
- `outdoorLevel` (string): 室外等级，`优`/`良`/`中`/`差`
- `reminder` (string): 综合评价提醒文案，可能为空

**错误响应**（`code` 为 `1003`，随 HTTP 200 返回）：

- 内部异常：`{"code":1003,"message":"Internal server error: <详情>"}`
- ⚠️ 本接口不再因网关不可用/读取失败而报错（纯读缓存），仅可能在异常分支触发上述 1003。

**curl**：`curl "http://localhost:8080/api/idle/air-quality-reminder"`

### 3. 获取待机状态 `GET /api/idle/status` ❌

**实际响应**：`{"code":1006,"message":"Feature not implemented: getIdlePageData"}`

**curl**：`curl "http://localhost:8080/api/idle/status"`

### 4. 唤醒设备 `POST /api/idle/control` ❌

请求体可空。**实际响应**：`{"code":1006,"message":"Feature not implemented: wakeUp"}`

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{}' "http://localhost:8080/api/idle/control"`

---

## 三、模式页面 API（均未实现）

以下接口均返回未实现占位响应 `{"code":1006,"message":"Feature not implemented: <feature>"}`，对应 `*Page` 类中的桩函数。请求体参数会被路由接收但不会被处理。

| 路径                              | 方法 | feature 名                                                                                                     |
| --------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------- |
| `/api/manual/status`            | GET  | `getManualModeData`                                                                                          |
| `/api/manual/control`           | POST | `setManualModeParams`                                                                                        |
| `/api/smart/status`             | GET  | `getSmartModeData`                                                                                           |
| `/api/smart/control`            | POST | `setSmartModeParams`                                                                                         |
| `/api/system/settings`          | GET  | `getSystemSettings`                                                                                          |
| `/api/system/settings`          | POST | `setSystemSettings`                                                                                          |
| `/api/maintenance/status`       | GET  | `getFilterStatus`                                                                                            |
| `/api/maintenance/filter/reset` | POST | `resetFilterLife`                                                                                            |
| `/api/engineering/status`       | GET  | `getEngineeringModeData`                                                                                     |
| ~~`/api/history/data`~~        | GET  | **v1.4.0 已移除**（原未实现桩），由 `/api/history/trend` 与 `/api/history/status` 取代（见第十三章） |

### 工程模式控制 `POST /api/engineering/control` ❌（占位）

与上表不同，此接口由内联处理器返回固定占位，**不是** `code:1006`：

**实际响应**：`{"message":"工程模式控制暂未实现"}`

---

## 四、屏幕控制 API

### 1. 屏幕休眠/唤醒 `POST /setScreenSleep` ✅

| 项目             | 说明                                                                   |
| ---------------- | ---------------------------------------------------------------------- |
| **请求体** | `{"sleep": 1}` （`sleep` 整数，缺省 `1`。`1`=休眠，其它=唤醒） |
| **实现**   | 通过`system()` 写 `/sys/kernel/debug/dispdbg/*` 控制显示           |

**实际响应**（裸对象，无 `code` 外层）：

```json
{ "sleep": 1, "success": true }
```

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"sleep":1}' "http://localhost:8080/setScreenSleep"`

### 2. 查询背光亮度 `GET /getScreenBrightness` ✅

优先读取 `/sys/class/backlight/*/brightness` 与 `max_brightness`；平台没有可用 backlight 节点时再尝试已封装的显示设备接口。

**实际响应**（裸对象）：

```json
{ "min": 0, "max": 220, "current": 110, "available": true, "pending": false, "success": true, "error": "" }
```

未找到安全可读的亮度接口时返回 `available:false` 并保留上一次确认快照，不用伪造的新值覆盖缓存。

**curl**：`curl "http://localhost:8080/getScreenBrightness"`

### 3. 设置背光亮度 `POST /setScreenBrightness` ✅

| 项目             | 说明                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| **请求体** | `{"brightness": 110}`（整数、必填，必须位于本次快照给出的 `min..max`） |

命令通过校验并进入本机设备队列后返回 `accepted:true`，不把入队当作硬件已经生效。工作线程从本次写入所用的同一接口回读，实际值、失败状态和错误信息由 `/api/runtime/snapshot` 或 `GET /getScreenBrightness` 返回。接口不存在时返回 503；数值超出当前设备量程时返回 400。

**实际响应**（裸对象）：

```json
{ "min": 0, "max": 220, "accepted": true }
```

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"brightness":200}' "http://localhost:8080/setScreenBrightness"`

---

## 五、Modbus 寄存器 API

### 1. 读保持寄存器 `GET /api/modbus/read` ✅

| 项目           | 说明                                                                                          |
| -------------- | --------------------------------------------------------------------------------------------- |
| **参数** | `address`（必填，支持十六进制 `0x...` 或十进制）；`count`（缺省 `1`，范围 `1-125`） |
| **实现** | `BeiAng4CPGateway::readHoldingRegister()`（功能码 03H，保持寄存器）                         |

> ⚠️ 历史文档提到 `type`（holding/input/discrete）参数，**当前代码未实现该参数**，一律按保持寄存器读取。

**实际响应**（裸对象）：

```json
{
  "address": "0x1000",
  "addressDec": 4096,
  "count": 2,
  "values": [1, 0],
  "hexValues": ["0x1", "0x0"]
}
```

**错误**：

- 缺 `address`：HTTP 400 `{"code":400,"message":"缺少必需参数: address"}`
- `count` 越界：HTTP 400 `{"code":400,"message":"count 参数必须在 1-125 范围内"}`
- 地址格式非法（纯非数字串，如 `ZZZ`）：HTTP 400 `{"code":400,"message":"参数格式错误: stoi"}`
- 网关不可用 / 读取失败：HTTP 500

> 注意：`0xZZ` 这类"0x + 非法字符"的串**不会**报错——`std::stoi` 会静默解析前导 `0` 为地址 `0x0000`，请求按正常流程继续。

**curl**：

```
curl "http://localhost:8080/api/modbus/read?address=0x1000&count=2"
curl "http://localhost:8080/api/modbus/read?address=4096"
```

### 2. 写单个保持寄存器 `POST /api/modbus/write` ✅

| 项目             | 说明                                                                                               |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| **请求体** | `{"address":"0x1000","value":1}`；`address`/`value` 均支持十六进制字符串、十进制字符串或数字 |
| **实现**   | `BeiAng4CPGateway::writeHoldingRegister()`（功能码 06H）                                         |

**实际响应**（裸对象）：

```json
{ "address": "0x1000", "addressDec": 4096, "value": 1, "hexValue": "0x1", "success": true }
```

**错误**：缺 `address`/`value` 或格式错误返回 HTTP 400；网关/写入失败返回 HTTP 500。

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"address":"0x1000","value":1}' "http://localhost:8080/api/modbus/write"`

### 3. 批量写寄存器 `POST /api/modbus/write-multiple` ❌

| 项目             | 说明                                                                                   |
| ---------------- | -------------------------------------------------------------------------------------- |
| **请求体** | `{"address":"0x1016","values":[2026,8,5]}` （`address` 必填，`values` 非空数组） |

> ❌ 校验参数（缺 `address`/`values` 返回 HTTP 400；网关不可用返回 HTTP 503）后返回模拟"成功"，**未调用 Modbus 10H 下发**（代码内含 TODO）。

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "address": 4118, "count": 3, "success": true, "timestamp": "2026-08-06T..." } }
```

**curl**：`curl -X POST -H "Content-Type: application/json" -d '{"address":"0x1016","values":[2026,8,5]}' "http://localhost:8080/api/modbus/write-multiple"`

### 4. 读离散输入 `GET /api/modbus/read-discrete` ❌

| 项目           | 说明                                                              |
| -------------- | ----------------------------------------------------------------- |
| **参数** | `address`（缺省 `0`）；`count`（缺省 `1`，范围 `1-44`） |

> ❌ 网关不可用返回 HTTP 503，`count` 越界返回 HTTP 400；通过校验后返回全 `0` 模拟值（代码内含 TODO，未调用 Modbus 02H）。当 `address=0 && count>=16` 时额外返回固定的 `bits` 解析对象。

**实际响应**：

```json
{
  "code": 0, "message": "success",
  "data": {
    "address": 0, "count": 16,
    "values": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    "bits": { "hasHumidityMembrane": true, "hasDehumidification": true, "hasIEF": true }
  }
}
```

**curl**：`curl "http://localhost:8080/api/modbus/read-discrete?address=32&count=13"`

---

## 六、扩展功能 API（多为模拟 / 未实现）

以下接口参数会被解析与校验，多数返回**固定模拟数据**或模拟"成功"，未连接真实设备寄存器读写；例外：`POST /api/rtc/time` 已真实写设备（见第 7 小节）。

### 1. 设备能力 `GET /api/device/capabilities` ⚠️

**实际响应**（v1.4.2 按源码更新；能力位来自离散输入 3000H-3001H 周期采集缓存，缓存未就绪返回 HTTP 503）：

```json
{ "code": 0, "message": "success", "data": {
  "hasHumidificationModule": true, "hasDehumidification": true, "hasBypassMode": true,
  "hasIEFPurification": true, "hasDisinfectModule": false, "hasElectricHeating": true,
  "hasFrostProtection": true, "hasFormaldehydeHcho": false,
  "hasAirConditioner": false, "hasFloorHeating": false
}}
```

> `hasAirConditioner` / `hasFloorHeating`（v1.4.2 新增）为**产品级静态值**：4CP 无空调、无地暖（仅新风/调湿/超净三项），协议 v1.22 离散能力表亦无此两位，故不来自寄存器、恒为 `false`；与 `GET /api/device/air-conditioner/presence`、`GET /api/device/floor-heating/presence`（第十五章）同源。

### 2. 故障状态 `GET /api/device/faults` ⚠️

**实际响应**：

```json
{ "code": 0, "message": "success", "data": { "hasFault": false, "faults": [], "lastCheck": "2026-08-06T..." } }
```

> 协议定义的 13 种故障码（离散输入 32-44）见文末「故障码」。

### 3. 清除故障 `POST /api/device/faults/clear` ❌

| 项目             | 说明                                           |
| ---------------- | ---------------------------------------------- |
| **请求体** | `{"faultCodes":[32,33]}` 或 `{"all":true}` |

**实际响应**：

- 传 `{"all":true}`：`{"code":0,"message":"success","data":{"cleared":true,"clearedFaults":[],"timestamp":"..."}}`
- 传 `{"faultCodes":[32,33]}`：`{"code":0,"message":"success","data":{"cleared":true,"clearedFaults":[32,33],"timestamp":"..."}}`（`clearedFaults` 回显传入的故障码）

未提供 `faultCodes` 或 `all` 时返回 HTTP 400。

### 4. 关机下空气检测 `GET /api/device/off-mode/air-quality` ⚠️ / `POST` ❌

- **GET** 实际响应：`{"code":0,"message":"success","data":{"enabled":true,"interval":60,"runtime":2,"lastCheck":"...","nextCheck":"..."}}`
- **POST** 请求体 `{"enabled":true,"interval":60,"runtime":2}`，校验 `interval>=30`、`runtime` 在 1-5；返回 `{"code":0,"message":"success","data":{"success":true,"updated":["enabled","interval","runtime"]}}`（模拟）

### 5. 加湿系统 `GET /api/humidification/status` ⚠️ / `POST /api/humidification/control` ❌

- **GET** 实际响应：`{"code":0,"message":"success","data":{"pumpStatus":true,"drainValve":false,"inletValve":true,"inletFloat":1,"drainFloat":0,"pumpOnTime":30,"pumpOffTime":60,"drainOnTime":10,"drainCount":3}}`
- **POST** 请求体 `{"pumpOnTime":30,"pumpOffTime":60,"drainOnTime":10,"drainCount":3}`，校验范围（10-120 / 10-300 / 5-60 / 1-10）；返回模拟 `{"code":0,"message":"success","data":{"success":true,"updatedParams":[...]}}`

### 6. 清除风机运行时间 `POST /api/maintenance/fan/clear` ❌

| 项目             | 说明                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| **请求体** | `{"fan":"fan1"}` 或 `{"fan":"all"}`（取值 `fan1`-`fan4`、`all`） |

**实际响应**：`{"code":0,"message":"success","data":{"cleared":["fan1"],"timestamp":"..."}}`（模拟，未下发寄存器 1037H-103AH）

### 7. RTC 时间 `GET /api/rtc/time` ✅ / `POST /api/rtc/time` ✅

- **GET**：纯读周期采集缓存（101BH-101FH），实际响应：
  `{"code":0,"message":"success","data":{"year":2026,"month":9,"day":3,"hour":10,"minute":14,"minute":...,"second":32,"week":4,"format":0,"formatted":"2026-09-03 10:14:32"}}`
  - `week`：0=Sunday..6=Saturday；`format`：0=24 小时制 / 1=12 小时制
  - **12 小时制（format=1）时 `hour` 已归一为 24 小时制输出**，并附加 `meridiem`:"AM"/"PM"（寄存器原始值为低 7 位 1-12 + bit7=PM）
- **POST** 请求体：
  - `"time"`：`"YYYY-M-D H:M:S"`（兼容无前导零，如 `2026-8-7 15:31:49`）或 `"timestamp"`：epoch 秒（按本地时区分解）
  - 可选 `"format"`：`0`=24 小时制（默认）/ `1`=12 小时制（由前端设置；**时间值仍按 24 小时制传入**，12h 打包——低 7 位 1-12、bit7=PM（0 点=12AM、12 点=12PM、13-23 点=(hour-12)PM）——由后端换算）
  - **严格日历校验**（v1.3.8）：`mktime` 回程比对，非法日期（如 `2026-2-30`、平年 `2-29`）返回 `{"code":1,"message":"invalid calendar date (e.g. 2026-2-30), rejected without writing registers"}`（HTTP 200，**不写寄存器**）
  - 实现：自动推算星期（0=Sunday）后经 `ModbusCommandModule::submitMultipleWrite` 以 **10H 功能码真实写入 `101BH-101FH`**（10 字节结构体打包 5 寄存器：101BH=年｜101CH=月<<8|日｜101DH=时<<8|分｜101EH=秒<<8|星期｜101FH=格式<<8|对齐；1016H-101AH 预留）
  - 成功：`{"code":0,"message":"success","data":{"setTime":"2026-09-03 13:05:07","regValues":[2026,2307,33029,1796,256],"format":1,"accepted":true}}`
  - 命令队列不可用 → HTTP 503

### 8. 协议信息 `GET /api/protocol/info` ✅

返回准确、固定的协议元数据（非动态读取设备，但内容真实正确）。

**实际响应**：

```json
{ "code": 0, "message": "success", "data": {
  "protocolVersion": "V1.22", "deviceAddress": 209, "deviceModel": "4CP",
  "supportedFunctionCodes": ["03","04","02","06","10"],
  "registerRanges": { "holding": "1000H-1076H", "input": "2000H-203BH", "discrete": "3000H+0-76" }
}}
```

---

## 七、传感器数据 API（部分模拟）

### 1. 全部传感器 `GET /getSensors` ⚠️

**实际响应**：

```json
{ "code": 0, "message": "success", "data": {
  "ra1": { "temperature": 25.5, "humidity": 60, "pm25": 35, "co2": 800 },
  "oa":  { "temperature": 28.0, "humidity": 55, "pm25": 45, "co2": 900 },
  "sa":  { "temperature": 23.0, "humidity": 65, "pm25": 20, "co2": 750 },
  "airQuality": { "tvoc": 150, "formaldehyde": 0.08 }
}}
```

> ⚠️ 固定模拟值。如需真实环境数据，请改用 `GET /api/idle/environment`。

### 2. 空气质量 `GET /getAirQuality` ⚠️

**实际响应**：`{"code":0,"message":"success","data":{"tvoc":150,"formaldehyde":0.08,"pm25":35,"aqi":75,"level":"良好"}}`（固定模拟，`level` 由 `aqi` 推导）

### 3. 温湿度 `GET /getTempHumi` ✅

**实际响应**（裸对象）：`{"temperature":26.6,"humidity":49.7}`

真实读取 GXHTC3 温湿度传感器（I2C 挂载，内核 hwmon 导出）：`/sys/class/hwmon/hwmon0/temp1_input`（毫摄氏度）、`humidity1_input`（千分之一）。读取失败时回退默认值 `25.5`/`60.0`。序列号接口 `GET /getSensorSerial` 同源（`/sys/bus/i2c/devices/1-0070/gxhtc3/serial_id`）。

---

## 八、WiFi 管理 API

WiFi 由独立工作线程顺序执行扫描、连接、断开和状态刷新，底层直接调用 `libemc6069`（emc6069 模组串口由 OTA 管理器常驻持有，见第十二章）。HTTP POST 只表示命令通过校验并成功入队；`enabled/connected/state/IP/scanResults/error` 等实际过程状态统一从 `/api/runtime/snapshot` 读取。页面退出不取消已入队操作。

| 推荐路径                              | 兼容路径              | 方法 | 请求体                                                  | 响应                                                                                                        |
| ------------------------------------- | --------------------- | ---- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `/api/local-device/wifi/enabled`    | `/wifiOpen`         | POST | `{"enabled":true}`，兼容 `open`                     | `{"enabled":true,"open":true,"accepted":true}`（入队）                                                    |
| `/api/local-device/wifi/scan`       | —                    | GET  | —                                                      | **同步聚合**（阻塞≤12s，见下），调用方超时须≥15s                                                    |
| `/api/local-device/wifi/connect`    | `/connectWifi`      | POST | `{"ssid":"X","password":"Y"}`；开放网络密码为空字符串 | `{"ssid":"X","accepted":true}`（入队）                                                                    |
| `/api/local-device/wifi/disconnect` | `/disconnectWifi`   | POST | `{}`，兼容可选 `ssid`（空body合法）                 | `{"ssid":"","accepted":true}`（入队）                                                                     |
| `/api/local-device/wifi/status`     | `/getConnectedWifi` | GET  | —                                                      | `{state,enabled,connected,ssid,ip,rssi,error}`，state含 idle/connecting/connected/failed，供连接过程轮询  |
| —                                    | `/scanWifi`         | POST | `{}`                                                  | `{"accepted":true}`（异步触发，产测App使用；local-device风格请用上面的GET同步版，**POST版已移除**） |
| —                                    | `/getWifiInfo`      | GET  | —                                                      | 当前扫描结果裸数组：`[{"ssid":"X","rssi":-45,"secured":true}]`                                            |

**GET `/api/local-device/wifi/scan` 同步聚合扫描**：触发扫描并阻塞等待完成（最长12s），一次返回
`{"current":{"ssid":"X","connected":true},"networks":[{"ssid":"X","rssi":-45,"secured":true},...]}`
（rssi为原始dBm负值，secured即是否加密）。注意：连接进行中扫描会被WiFi命令队列排队，可能等到超时
仍返回空列表；WiFi总开关关闭时返回409；前端应避免与连接操作并发调用。

**连接成功后自动对时**：WiFi连接确认成功后，后端自动通过模组0x24查询UTC时间并写入系统时间和
全部RTC（含电池RTC），无需前端调用。模组掉线自动重连成功后同样自动对时。

`state` 当前包括 `idle/scanning/connecting/connected/disconnecting/failed/disabled`。系统接口不可用时通过 `available:false + state:disabled + error` 表达。后端不保存密码，也不在日志和运行快照中返回密码；是否记住凭据由前端在连接实际成功后决定。

一次连接的总期限为 20 秒（库内连接指令阻塞至拿到连接结果）。新的连接命令会
抢占正在执行的旧连接和候选扫描，并使旧事务结果失效；断开或关闭同样会终止当前连接。后端不区分
自动连接和手动连接，也不保存 LRU：手动失败后从哪一项恢复由前端重新提交。页面退出本身不发送取消，
因此连接可能在页面返回后成功，最终状态仍从聚合运行快照取得。

OTA 下载/安装期间模组串口被独占，WiFi 指令会被库拒绝：后端识别后不改变 `state`（避免误报
`failed`），仅在 `error` 附带 `OTA transfer in progress`；状态刷新在 OTA 期间自动暂停，恢复后继续。

`POST /api/local-device/wifi/enabled` 传入 `false` 时，关闭和断开是同一次平台操作：命令入队后状态先进入 `disconnecting`，执行成功后发布 `enabled:false, connected:false, state:disabled`并清除 SSID/IP；执行失败则保留上一次确认值并发布错误。HTTP 返回 `accepted` 仍只代表入队，最终结果以聚合运行快照为准。

`POST /api/local-device/wifi/disconnect` 只断开当前连接，不等同于上述关闭：成功后保持
`available:true, enabled:true`，清除当前 SSID/IP/RSSI，状态回到 `idle`；扫描结果不清空，前端保存的
凭据不归后端管理。平台守护进程若在没有 App 连接命令时自行恢复网络，`/api/runtime/snapshot`
仍按实际查询结果发布 `connected`。

### 8.1 RS485 通讯开关 API

RS485（Modbus RTU 主站，对空调主控的串口通讯）独立于WiFi，开关为**全停语义**：

| 路径                                | 方法 | 请求体                | 响应                                  |
| ----------------------------------- | ---- | --------------------- | ------------------------------------- |
| `/api/local-device/rs485/enabled` | POST | `{"enabled":false}` | `{"enabled":false,"accepted":true}` |
| `/api/local-device/rs485/enabled` | GET  | —                    | `{"enabled":true}`                  |

- 关闭 = 依次停止定时任务调度器（期间到期的定时任务**丢弃并记日志**）、下行命令队列、周期轮询；
  开启 = 逆序恢复，任一模块启停失败返回500且不落盘
- 状态持久化到 `/mnt/UDISK/rs485_enable`，进程重启后保持上次的开关状态（无文件默认开启）
- 关闭期间 `/api/modbus/read|write|write-multiple|read-discrete` 快速返回503
  "RS485通讯已关闭"（不等Modbus超时）；`/api/device/*` 等经命令队列的接口同样被拒
- WiFi/OTA不受RS485开关影响

---

## 九、硬件外设 API（模拟 / 部分）

| 路径                       | 方法 | 状态 | 请求体                                                                    | 实际响应                                                                                                                                                             |
| -------------------------- | ---- | ---- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/setHumanPresenceRadar` | POST | ✅   | `{"enable":true}`                                                       | `{"enable":true,"success":true}`                                                                                                                                   |
| `/getHumanPresenceRadar` | GET  | ✅   | —                                                                        | `{"enable":true,"online":true,"distance":52,"velocity":-1,"signal":5279,"gesture":0,"approach":true,"depart":false,"direction":"approach","timestamp":1704710999}` |
| `/setAQILed`             | POST | ✅   | `{"pm25":42}`、`{"level":2}`、`{"level":5}` 或 `{"enabled":true}` | `{"enabled":true,"level":2,"color":"C2DF05","accepted":true}`                                                                                                      |
| `/setSpeaker`            | POST | ❌   | `{"enable":true}`                                                       | `{"enable":true,"success":true}`                                                                                                                                   |

**人感雷达（TRMK222-0 24GHz 毫米波雷达，`✅ 真实硬件`）**

TRMK222 雷达经 CH341 USB 转串口（`/dev/ttyCH341USB0`，115200 8N1）连接，由独立驱动 `trmk222`（包 `package/allwinner/trmk222`）以 daemon 形式常驻处理。后端通过**状态文件 + 命令文件**与其协作，避免多进程并发读写同一串口：

- **状态文件**（`radar.statusFile`，默认 `/mnt/UDISK/beiang8panel/radar_status.json`）：daemon 每查询周期写入，`GET /getHumanPresenceRadar` 读取后返回。
- **命令文件**（`radar.commandFile`，默认 `/tmp/trmk222_cmd`）：`POST /setHumanPresenceRadar` 只写 `on`/`off` 文本，由独占串口的 daemon 消费并执行开关，执行后删除。

`GET /getHumanPresenceRadar` 返回字段：

| 字段          | 类型   | 说明                                                       |
| ------------- | ------ | ---------------------------------------------------------- |
| `enable`    | bool   | 雷达开关状态（由 daemon 查询帧实测）                       |
| `online`    | bool   | 驱动/串口是否在线（状态文件新鲜度）                        |
| `distance`  | int    | 检测距离（cm）                                             |
| `velocity`  | int    | 速度（cm/s，**正=靠近，负=远离**）                   |
| `signal`    | int    | 信号强度                                                   |
| `gesture`   | int    | 摆手手势（1=识别到）                                       |
| `approach`  | bool   | 是否正在接近（velocity ≥`approach_vel`）                |
| `depart`    | bool   | 是否正在远离（velocity ≤`depart_vel`）                  |
| `direction` | string | `approach` / `depart` / `none` / `unknown`（离线） |
| `timestamp` | int    | 状态文件写入时间（Unix 秒）                                |

daemon 未运行时 `GET` 返回全离线默认值（`online:false, direction:"unknown"`）。

> RTC 时间读写统一使用封装接口：`GET /api/rtc/time`（⚠️ 模拟）与 `POST /api/rtc/time`（✅ 真实写设备 1016H-101FH）。`/setAQILed` 与推荐路径 `/api/local-device/aqi-led/level` 控制当前平台的 9 路成组 RGB：优先向 rgb_daemon FIFO（`/tmp/rgb_test_fifo`）下发三组同色命令实现**呼吸效果**（以 `O_NONBLOCK` 探测读端）；rgb_daemon 未运行时**直接熄灭**（`multi_brightness` 写全黑，不做常亮回退）并上报关闭状态。参数优先级 `pm25` > `level` > `enabled`：
>
> - `pm25`（整数，μg/m³）自动分级：≤35→`1` 优、35~75→`2` 良好、75~150→`3` 中度污染、>150→`4` 重度污染（负值视为 0 关闭）；
> - `level`（0~5）：`0`=关闭（熄灭）、`1`=绿色（05DF72）、`2`=黄绿色（C2DF05）、`3`=黄色（F59E0B）、`4`=红色（EF4444），以上均以 **BREATHE 3 秒周期呼吸**显示；`5`=严重故障告警，红色（EF4444）**FAST_BREATHE 1 秒周期快速呼吸**（`pm25` 分级不会产生 5，仅显式指定）；
> - `enabled`（布尔，`/api/local-device/aqi-led/enabled`）：开启映射到等级 1。
>   该接口按只写处理：非法参数返回 400，入队成功只返回 `accepted`；聚合快照随后发布命令成功/失败，成功时保存最后一次写入的目标等级，不读取节点反推物理灯态。

---

## 十、天气与定位 API ⏸（暂不可用）

> **架构变更说明（2026-09-01）**：本组功能修改为**由 emc6069 模组提供相关数据接口**，模组侧接口**目前暂无**，本组接口整体标记 ⏸ 暂不可用。
>
> 背景与现状：WiFi 由 emc6069 模组承载（offload），Linux 侧仅有 `lo` 接口、无路由，原"libcurl 出网 → 公网 IP 定位 → 和风天气"链路在本硬件架构下无法出网（实测 `/getWeather`、`/getLocation` 返回 HTTP 500 `"获取公网IP失败"`）。下方接口契约保留，待模组数据接口就绪后按新链路重新接入。

### 1. 区域天气 `GET /getWeather` ⏸

根据设备出口公网 IP 自动定位并返回**实时天气**（和风天气 QWeather）。无需传参，位置由 IP 决定。**当前状态：等待模组提供天气数据接口，暂不可用（返回 500）。**

**调用链路**（服务端自动完成，需外网）：

1. 太平洋网 `whois.pconline.com.cn` 取设备出口公网 IP
2. 和风 GeoAPI `/geo/v2/city/lookup?location={ip}` → 经纬度 + 城市
3. 和风 `/weather/v1/current/{lat}/{lon}?lang=zh` → 实时天气
4. 和风 `/weather/v1/daily/{lat}/{lon}?days=1` → 当日最高/最低温

> 结果带 **5 分钟 TTL 缓存**（设备位置固定，缓存命中时直接返回）。任一外部请求失败返回 HTTP 500 + 中文错误信息。历史 `city`/`location` 参数**不再生效**。
>
> ⚠️ **配置要求**：`apiKey`/`apiHost` 由 `config/FactoryConfig.json` 的 `weather` 块读取（示例 `{"weather":{"apiKey":"<key>","apiHost":"https://<子域名>.re.qweatherapi.com"}}`）。**默认配置中该块已被移除**：`apiHost` 有内置默认值，但 `apiKey` 无默认值——未配置 `weather.apiKey` 时接口返回 HTTP 500 `{"code":500,"message":"天气服务未配置（缺少 apiKey 或 apiHost）"}`。

**实际响应**（裸对象）：

```json
{
  "city": "深圳", "temperature": "28", "temperatureMax": "37", "temperatureMin": "27",
  "feelsLike": "32", "weather": "晴", "weathercode": 100,
  "humidity": "77", "wind": "西西南风2级", "updateTime": "2026-08-07T10:30:00+08:00",
  "pressure": 1007.7, "visibility": 22080.0, "uvIndex": 4, "cloudCover": 0.03
}
```

| 字段                                    | 类型   | 说明                                                                                                                                                                                                             |
| --------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `city`                                | string | IP 定位所得城市名                                                                                                                                                                                                |
| `temperature` / `feelsLike`         | string | 实时温度 / 体感温度（℃，四舍五入取整，字符串以兼容旧契约）                                                                                                                                                      |
| `temperatureMax` / `temperatureMin` | string | 当日最高 / 最低温度（℃，四舍五入取整，来自 daily 预报）                                                                                                                                                         |
| `weather`                             | string | 天气现象中文文本（如"晴"）                                                                                                                                                                                       |
| `weathercode`                         | number | 和风天气代码（如`100`=晴、`101`=多云），**语言无关**，供前端按语言查映射表；解析失败为 `0`（前端按"查不到"处理，回退用 `weather`）。完整对照表见 [weather-code-mapping.md](weather-code-mapping.md) |
| `humidity`                            | string | 相对湿度百分比（"77" = 77%）                                                                                                                                                                                     |
| `wind`                                | string | 风向中文 + 风级（如"西西南风2级"）                                                                                                                                                                               |
| `updateTime`                          | string | 响应生成时间（ISO8601 +08:00）                                                                                                                                                                                   |
| `pressure`                            | number | 气压（hPa）                                                                                                                                                                                                      |
| `visibility`                          | number | 能见度（m）                                                                                                                                                                                                      |
| `uvIndex`                             | number | 紫外线指数                                                                                                                                                                                                       |
| `cloudCover`                          | number | 云量（0~1）                                                                                                                                                                                                      |

**curl**：

```
curl "http://localhost:8080/getWeather"
```

### 2. 区域信息 `GET /getLocation` ⏸

**当前状态：等待模组提供定位数据接口，暂不可用（返回 500）。**

原有链路（保留参考）：调用太平洋网 IP 定位接口 `https://whois.pconline.com.cn/ipJson.jsp?ip=&json=true`（GBK 编码，自动转 UTF-8）。结果带 **5 分钟 TTL 缓存**（设备位置固定）。

**实际响应**（裸对象）：

```json
{ "ip": "...", "province": "广东省", "city": "深圳市", "district": "龙岗区", "address": "广东省深圳市龙岗区" }
```

- `address` 在 API 返回为空时由 `province`+`city`+`district` 拼接
- 请求失败 / 解析失败返回 HTTP 500

**curl**：`curl "http://localhost:8080/getLocation"`

---

## 十一、测试与元信息 API

### 1. Ping `GET /api/ping` ✅

**实际响应**（裸对象）：`{"pong":true}`

### 2. 健康检查 `GET /api/health` ✅

**实际响应**（裸对象）：

```json
{ "status": "ok", "server": "running", "port": 8080, "uptime": "unknown" }
```

> `status` 取决于服务器运行状态：运行中为 `"ok"`，未运行时为 `"error"`。`uptime` 当前固定为 `"unknown"`。

### 3. 版本信息 `GET /api/version` ✅

**实际响应**（裸对象）：

```json
{
  "version": "1.2.0",
  "name": "BeiAng8Panel",
  "description": "BeiAng 4CP Air Purifier Controller Panel Backend Service"
}
```

### 4. 路由列表 `GET /api/paths` ✅

返回 libhv 已注册的全部路由字符串（格式 `"METHOD /path"`）。

**实际响应**（裸数组）：

```json
[ "GET /api/device/status", "POST /api/device/power", "GET /api/idle/environment", ... ]
```

---

## 十二、OTA 升级 API（v3.8 新增）✅

整机固件升级（R818 AB 方案）。链路：云端 → emc6069 WiFi 模组（串口 YAT 协议推送）→ 后端经
`libemc6069` 收流并校验（http 边下边传 + 断点续传 + MD5）→ 固件落盘 `/mnt/UDISK/emc6069_ota.bin`
→ 校验通过后 rename 为 `/mnt/UDISK/beiang8panel/ota/firmware.swu` → `swupdate_cmd.sh` 写另一
槽位并**自动重启**；升级失败由 bootloader AB 回滚，重启后 `/etc/version` 回到旧版本号。

版本号约定：`currentVersion` 读取 `/etc/version`（形如 `BAFreshAir8C-0.0.3`）；升级成功依赖新固件
包内版本号递增。下载期间模组串口被 OTA 独占，WiFi 扫描/连接等操作会被后端拒绝（WiFi 状态保持
原值并附带错误说明，详见第八章）。

| 路径                | 方法 | 请求体                    | 说明                                                                                                                                                                                                       |
| ------------------- | ---- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/api/ota/status` | GET  | —                        | OTA 状态总览（唯一数据源）                                                                                                                                                                                 |
| `/api/ota/start`  | POST | `{}`（可省略）          | “立即更新/重试”：有待确认通知则立即确认下载；否则置为待自动确认，模组重推通知时不再弹窗直接续传。**无可用更新（`updateAvailable=false`）→ HTTP 409 `"当前无可用更新"`**（与按钮置灰逻辑一致） |
| `/api/ota/cancel` | POST | `{"cleanup":true}` 可选 | “下次再说”；`cleanup:true` 用于下载失败弹窗“退出”，删除已下载残留文件。**空闲且无可用更新 → HTTP 409 `"当前无可用更新"`**                                                                   |

`GET /api/ota/status` 实际响应（裸对象）：

```json
{
  "available": true,          // OTA 传输层就绪（模组串口初始化成功且功能未被配置关闭）
  "canUpdate": true,          // 便捷字段：网络在线且有新版本且未在下载/安装中（更新按钮可点）
  "updateAvailable": true,    // 模组已推送过新版本通知（取消后仍保持 true，按钮保持高亮）
  "currentVersion": "BAFreshAir8C-0.0.3",
  "targetVersion": "mcu-0.0.4",
  "fwSize": 104857600,        // 目标固件总长（字节），未知为 0
  "fwMd5": "8E8DD18D...",     // 目标固件 MD5，未知为空串
  "state": "downloading",
  "percent": 42,              // 下载进度 0~100
  "downloadedBytes": 44040192,
  "pending": false,           // 确认/重试动作已提交、等待模组响应
  "success": true,
  "error": "",
  "wifiConnected": true
}
```

`state` 取值与产品流程（系统信息页弹窗）的对应关系：

| state                | 含义                                      | 前端表现                                                                                                               |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `idle`             | 无进行中的升级事务                        | 更新按钮按`canUpdate` 置灰/高亮                                                                                      |
| `notifyPending`    | 模组已通知有新版本，等待用户确认          | 弹“有最新可用版本…”确认框（【下次再说】【立即更新】）                                                               |
| `preparing`        | 已确认/重试，等待模组开始传输             | 显示下载中弹窗                                                                                                         |
| `downloading`      | 固件传输中                                | 下载中弹窗，进度条`percent`                                                                                          |
| `downloadComplete` | 下载完成且长度/MD5 校验通过               | 过渡态，随即进入 installing                                                                                            |
| `installing`       | swupdate 写入另一槽位，完成后设备自动重启 | 显示“请勿断电…”弹窗；勿弹网络错误                                                                                   |
| `failed`           | 下载或校验失败                            | 弹失败框（`error` 为提示文案）；【重试】→ `/api/ota/start`，【退出】→ `/api/ota/cancel` + `{"cleanup":true}` |

约束与注意：

- `POST` 返回 `accepted:true` 仅代表请求受理；实际进度以 `GET /api/ota/status` 轮询为准（建议 1s 间隔）。
- **无更新时的 start/cancel 直接 409**（v3.20）：不再走“接受后由模组空查询回 idle”的路径；下载/安装进行中的重复 start 仍视为已受理（200），失败弹窗的“退出”（`cleanup:true`）不受影响。
- `/api/runtime/snapshot` 与 `/api/local-device/status` 的 `localDevice.ota` 节点包含同一份状态。
- `ota.enabled:false`（FactoryConfig）或模组串口初始化失败时 `available:false`，POST 返回 503。
- 升级安装阶段由 `swupdate_cmd.sh` 自动 `reboot -f`，后端不会额外确认；重启后 `/api/ota/status` 的
  `currentVersion` 变化即为升级结果（回滚则保持旧版本号）。
- OTA 期间模组自身固件升级（0x36 通知）会令模组短暂离线 20~30 秒，表现为 WiFi/OTA 查询暂时失败，属正常现象。

---

---

## 十三、历史趋势 API（v1.4.0 新增）✅

数据来源：输入寄存器 `200DH-2014H`（RA1 室内 / OA 室外 各 温度/湿度/PM2.5/CO₂）。
后端 `HistoryRecorder` 独立线程按对齐间隔（默认 600s，可配）从**周期采集缓存**采样（不碰串口），
以 18 字节定长记录追加写 `/mnt/UDISK/beiang8panel/history/samples-YYYYMMDD.bin`（fdatasync 落盘，保留 370 天，断电只丢尾部撕裂记录，重启续写去重）。
查询时读天文件现算桶序列。设计文档：`docs/历史趋势数据存储与接口设计.md`。

### 1. 获取趋势序列 `GET /api/history/trend` ✅

| 参数      | 必填 | 说明                                                                                       |
| --------- | ---- | ------------------------------------------------------------------------------------------ |
| `range` | 是   | `day` / `week` / `month`，非法返回 HTTP 400                                          |
| `date`  | 否   | 锚点日`YYYY-MM-DD`（严格校验，如 2026-02-30 拒绝），缺省=今天。v1 前端不传，预留历史回看 |

**桶语义**（与前端历史页 12/7/31 点模型一一对应）：

| range                  | 桶定义                                                      | 点数         |
| ---------------------- | ----------------------------------------------------------- | ------------ |
| `day`（锚点=今天）   | 滚动 24h：以最近整 2 小时为末桶起点（进行中桶），12 桶 ×2h | 12           |
| `day`（锚点=历史日） | 该自然日 00:00 起 12 桶 ×2h                                | 12           |
| `week`               | 锚点日与其前 6 个自然日                                     | 7            |
| `month`              | 锚点所在月 1 号至锚点日                                     | 锚点日号数 N |

**实际响应**（wrapped 模式 A；板上实测，温度 1 位小数，湿/PM2.5/CO₂ 取整数；**null=该桶无有效样本**）：

```json
{
  "code": 0,
  "data": {
    "range": "day", "intervalSeconds": 7200, "anchorDate": "2026-09-03",
    "timestamps": [1788350400, "...共12项,每桶起始UTC秒..."],
    "indoor":  { "temperature": [null,"...",26.9], "humidity": [null,"...",52], "pm25": [null,"...",77], "co2": [null,"...",619] },
    "outdoor": { "temperature": [null,"...",22.9], "humidity": [null,"...",64], "pm25": [null,"...",92], "co2": [null,"...",945] },
    "sampleCount": 4, "storageError": null
  },
  "message": "Success"
}
```

- `timestamps`：每桶**起始** UTC epoch 秒，前端本地化格式化；week/month 间隔 86400s。
- `indoor/outdoor.co2` 均提供（2010H/2014H）；当前前端模型仅消费室内 CO₂。
- `sampleCount`：窗口内原始样本数；`storageError`：存储异常描述（UDISK 不可写等），此时各序列为全 null 但 HTTP 仍 200（页面优雅降级）。
- 有效性过滤：湿度>100、PM2.5>999、CO₂>9999、|温度|>60℃ 的样本仅从对应序列均值中剔除。

**错误**：`range` 非法或 `date` 格式非法 → HTTP 400 `{"code":400,"message":"..."}`。

### 2. 采样与存储状态 `GET /api/history/status` ✅

排障用：区分"没采到数据"（4CP 离线/缓存不新鲜）与"存储失败"（UDISK 问题）。

**实际响应**（板上实测）：

```json
{ "code": 0,
  "data": {
    "enabled": true, "dataDir": "/mnt/UDISK/beiang8panel/history",
    "sampleIntervalSec": 60, "retentionDays": 370,
    "totalSamples": 7, "oldestDate": 20260903, "newestDate": 20260903,
    "lastSampleTime": "2026-09-03 19:41:00",
    "storageBytes": 142, "storageError": null
  },
  "message": "Success" }
```

> `storageBytes = 16(文件头) + 18×样本数`；`lastSampleTime` 为运行态，重启后置空至下一次采样。

**配置**（`FactoryConfig.json` → `history` 段）：`enabled` / `dataDir` / `sampleIntervalSec`(60..86400) / `retentionDays`。

---

## 十四、内存水位监控 API（v1.4.1 新增）✅

`MemoryWatchModule` 独立线程按周期（默认 10s）读 `/proc/meminfo` 的 `MemAvailable`，
三级阈值分级处置（配置段 `memwatch`）：

| 档位    | 默认阈值 | 行为                                                                                                               |
| ------- | -------- | ------------------------------------------------------------------------------------------------------------------ |
| warn    | 64MB     | 告警日志（进入记一次，持续每 60s 重复，恢复记 INFO）                                                               |
| restart | 32MB     | 连续 3 次命中 → SIGTERM 重启 flutter_eglfs（PVR 驱动约束：禁 kill -9，等待 ≤15s 退出后按 rc.local 同款命令拉回） |
| reboot  | 16MB     | 连续 3 次命中 → sync+重启设备；或重启 App 后 300s 冷却内水位仍处 restart 档（=重启未解决）升级触发                |

- OTA 进行中（下载/安装）抑制所有动作，仅告警，避免打断升级。
- flutter 收 SIGTERM 后 15s 未退出：不再强杀，下一轮策略升级为重启设备。

### 1. 监控状态 `GET /api/memwatch/status` ✅

**实际响应**（wrapped 模式 A；板上实测）：

```json
{ "code": 0,
  "data": {
    "enabled": true, "checkIntervalSec": 10,
    "warnThresholdMB": 64, "restartAppThresholdMB": 32, "rebootThresholdMB": 16,
    "sustainedChecks": 3, "actionCooldownSec": 300,
    "memAvailableKB": 1850204, "memAvailableMB": 1806.8,
    "level": "normal", "lastCheckTime": "2026-09-04 12:30:00",
    "restartAppCount": 0, "lastRestartAppTime": null,
    "events": ["2026-09-04 12:29:50 WARN MemAvailable=63000KB"]
  },
  "message": "Success" }
```

- `level`: `normal`/`warn`/`restart`/`reboot`（当前水位所处档位）。
- `events`: 最近 8 条事件（告警/恢复/动作），掉电不保，排障看后端日志 `beiang8panel.log`。

**配置**（`FactoryConfig.json` → `memwatch` 段）：`enabled` / `checkIntervalSec` / `warnThresholdMB` / `restartAppThresholdMB` / `rebootThresholdMB` / `sustainedChecks` / `actionCooldownSec`。

## 十五、空调/地暖有无查询 API（v1.4.2 新增）✅

4CP 产品**无空调、无地暖**，仅含新风/调湿/超净三项；协议 v1.22 离散能力表（3000H-3001H）亦未定义此两位。
本组接口为**产品级静态值**（源码宏 `BEIANG_PRODUCT_HAS_AIR_CONDITIONER` / `BEIANG_PRODUCT_HAS_FLOOR_HEATING`，换机型只改 `common/GlobalDefine.h`），
不依赖 Modbus 寄存器缓存，上电即可查、永不 503，供前端决定空调/地暖页面显隐。

### 1. 空调有无 `GET /api/device/air-conditioner/presence` ✅

**实际响应**（裸对象）：

```json
{ "hasAirConditioner": false }
```

### 2. 地暖有无 `GET /api/device/floor-heating/presence` ✅

**实际响应**（裸对象）：

```json
{ "hasFloorHeating": false }
```

**curl**：

```sh
curl "http://localhost:8080/api/device/air-conditioner/presence"
curl "http://localhost:8080/api/device/floor-heating/presence"
```

## 附录 A：错误码说明

`code` 字段（出现于封装响应与错误响应中）：

| code | 含义                                                                  | 来源                                                         | 典型 HTTP 状态 |
| ---- | --------------------------------------------------------------------- | ------------------------------------------------------------ | -------------- |
| 0    | 成功                                                                  | `ApiResponse::success`                                     | 200            |
| 200  | 成功（`/api/idle/environment`、`/api/idle/air-quality-reminder`） | `IdlePage::getEnvironmentData` / `getAirQualityReminder` | 200            |
| 400  | 请求参数错误 / 缺失                                                   | 内联`buildErrorResponse(400,...)`                          | 400            |
| 500  | 服务器内部错误 / 网关失败                                             | 内联`buildErrorResponse(500,...)`                          | 500            |
| 503  | 服务不可用（网关未初始化）                                            | 内联`buildErrorResponse(503,...)`                          | 503            |
| 1001 | 参数无效（`InvalidParameter`）                                      | `ApiResponse::invalidParameter`，带 `parameter` 字段     | 200            |
| 1002 | 设备离线（`DeviceOffline`）                                         | `ApiResponse::deviceOffline`                               | 200            |
| 1003 | 操作失败（`OperationFailed`）                                       | `ApiResponse::error(msg)` 默认码                           | 200            |
| 1004 | 操作超时（`Timeout`）                                               | `ApiResponse::timeout`                                     | 200            |
| 1005 | 内部错误（`InternalError`）                                         | `ApiResponse::internalError`                               | 200            |
| 1006 | 功能未实现（`NotImplemented`）                                      | `ApiResponse::notImplemented`，所有 `*Page` 桩           | 200            |

> `ApiResponse` 产生的业务码（1001-1006）默认随 HTTP 200 返回；内联处理器产生的 400/500/503 **随同值 HTTP 状态码返回**（由 `sendError` 统一设置，见代码）。

---

## 附录 B：数据枚举值

#### 新风运行模式（`runMode`，寄存器 1007H，v1.22 扩展为 0-5）

- `0` 内循环 / `1` 内循环·混风 / `2` 全热新风·节能新风 / `3` 自动模式 / `4` 旁通·换气 / `5` 睡眠

#### 整机运行模式（`wholeUnitRunMode`，寄存器 100AH，v1.22 新增）

- `0` 无（对应8寸屏：手动） / `1` 标准 / `2` 会客 / `3` 干爽 / `4` 温润 / `5` 旅行

#### 一键离家开关（`leaveHomeOn`，寄存器 1006H，v1.22 由手动/自动改为一键离家）

- `0` 关闭 / `1` 开启

#### 自动模式内外循环显示（`autoCirculationDisplay`，输入寄存器 201DH，v1.22 新增）

- `0` 内循环 / `1` 内循环·混风 / `2` 全热新风·节能新风

#### 工作模式（`WorkMode`，系统级，无直接寄存器映射）

- `0` 待机 / `1` 手动 / `2` 智能 / `3` 维护

#### 风量档位（`fanGear`，寄存器 1008H）

- `0` 关闭 / `1-6` 档位 1-6

#### 电辅热运行状态（`auxHeat`，输入寄存器 201CH；设定值写 1013H）

- `0x00` 关闭 / `0x01` 辅热1 / `0x02` 辅热2 / `0x03` 辅热1和2

#### 加湿/除湿强度（寄存器 1014H）

- `0` 弱 / `1` 中 / `2` 强

#### 阀门状态

- `0` 关闭 / `1` 半开 / `2` 全开

#### 设备型号

- `0` 4CP / `1` 全热新风

#### 设备状态（`DeviceStatus`）

- `Offline` / `Online` / `Error` / `Maintenance`

---

## 附录 C：v1.22 寄存器地址速查

#### 保持寄存器（读写，03H/06H/10H，起始 1000H；采集范围 **1000H-1076H**，共 119 个）

- `1000H` 总开关 · `1001H` 新风模块开关 · `1002H` 超净模式开关 · `1003H` 调湿模块开关
- `1004H` 加湿开关 · `1005H` 除湿开关 · `1006H` 一键离家开关(v1.22改) · `1007H` 新风运行模式(0-5) · `1008H` 风量档位(0-6，1001H开启且1007H∈{0,1,2,4}时可写)
- `1009H` 排风风量档位(预留) · `100AH` 整机运行模式(0-5, v1.22改) · `100BH` 无极风量开关 · `100CH`/`100DH`/`100EH` 新风/排风/增压风量占空比
- `100FH` 目标湿度(30-70) · `1010H` 目标温度(160-310，实际×10) · `1011H` 等离子消毒开关 · `1012H` IEF
- `1013H` 电辅热(0x00-0x03) · `1014H` 加湿/除湿强度 · `1015H` SA风量比例(×10)
- `1016H-101AH` 预留 · `101BH-101FH` RTC 时间(10字节结构体打包5寄存器, 0x10功能码) · `1020H` 延时关风机(分钟)
- `1021H`/`1022H`/`1023H` 加湿系统(泵开/关时间、排水开时间) · `1024H` 设备地址(0-254)
- `1025H-1027H` 关机状态下空气品质检测(开关/间隔/运行) · `1028H`/`1029H`/`102AH` 压缩机(膨胀阀开度0-500/运行频率设定0-90Hz/频率上限60-95Hz)
- `102BH`/`102CH` 高/低压开关(仅厂测, v1.22新增) · `102DH-102FH` 预留
- `1030H` 厂测模式(100=测试模式) · `1031H-1036H` 滤网保养时间(初效1/中效2/高效3/加湿模块/IEF/整机)
- `1038H-103BH` 当前FAN1-4风量设定值(仅厂测, v1.22新增) · `103CH-103EH` 阀门1-3状态设定(仅厂测, v1.22新增)
- `103FH` 清除所有风机运行时间(写1) · `1040H` 恢复出厂(写1)
- `1041H-1070H` FAN1-4 外循环/内循环各6档风量设定值(v1.22新增：FAN1外1041H-1046H、FAN1内1047H-104CH，FAN2-FAN4依次类推)
- `1071H-1073H` 风阀1-3方向设定(0/1) · `1074H-1076H` 风阀1-3运行步数设定(v1.22新增)

#### 输入寄存器（只读，04H，起始 2000H；采集范围 **2000H-203BH**，共 60 个）

- `2000H-2002H` 基础信息(工厂标志/机型/版本÷100) · `2003H`/`2004H` 新风模式/内循环混风模式最大档位
- `2005H-2008H` 风机 1-4 档位 · `2009H-200CH` 风机 1-4 RPM
- `200DH-2010H` RA1(温/湿/PM2.5/CO2) · `2011H-2014H` OA · `2015H-2018H` SA
- `2019H` TVOC(mg/m³, ÷100) · `201AH` 甲醛(mg/m³, ÷100) · `201BH` 压缩机运行频率(0-90Hz) · `201CH` 电辅热状态
- `201DH` 自动模式时内外循环显示(0/1/2, v1.22新增) · `201EH`/`201FH` 进风口温/湿(v1.22新增) · `2020H`/`2021H` 出风口温/湿(预留)
- `2022H`/`2023H` 高/低压压力值(bar, ÷100, v1.22新增) · `2024H`/`2025H` 进水/排水浮子
- `2026H` 系统运行时间(天) · `2027H-202AH` FAN1-4累计运转时间
- `202BH`-`202EH` 压缩机排气/吸气/蒸发器盘管/预留温度(v1.22新增) · `202FH` 交流电压检测值(待定)
- `2030H-203BH` 主控板版本时间字符串Char[24](v1.22由2050H-205BH移来)

#### 离散输入（只读，02H，起始 3000H）

- `3000H+0-7` 设备能力(加湿模块/除湿模块/旁通换气模式/IEF/消毒/电加热/防冻/甲醛HCHO)
- `3000H+32-37` 设备状态(循环泵/进水阀/排水泵/压缩机/除霜中/关机状态下空气质量检测中)
- `3000H+64-76` 故障码（见下）

#### 故障码（离散输入 64-76）

`/api/runtime/snapshot` 的 `faults` 节点含 `anyFault`（bit64 故障总标志：1=设备存在故障）与 `active` 明细数组（置位的故障位及名称）。

| 位 | 故障                  | 严重程度 |
| -- | --------------------- | -------- |
| 64 | 新风机异常            | 高       |
| 65 | 排风机异常            | 高       |
| 66 | 增压风机异常          | 高       |
| 67 | 待补充                | -        |
| 68 | 加湿机通讯失联        | 中       |
| 69 | 加湿进水槽浮子警报    | 中       |
| 70 | 加湿排水槽浮子警报    | 中       |
| 71 | 排水后水位不下降      | 中       |
| 72 | 加湿进水槽缺水        | 高       |
| 73 | 电辅热1 过流/过压保护 | 高       |
| 74 | 电辅热2 过流/过压保护 | 高       |
| 75 | 进水槽浮子异常        | 低       |
| 76 | 排水槽浮子异常        | 低       |

---

## 附录 D：URL 编码

HTTP URL 中的非 ASCII 字符（如中文）必须百分号编码。例：`深圳` → `%E6%B7%B1%E5%9C%B3`，`北京` → `%E5%8C%97%E4%BA%AC`。

```dart
// Flutter/Dart
final encoded = Uri.encodeComponent("深圳");
```

```python
# Python
import urllib.parse
encoded = urllib.parse.quote("深圳")
```

---

## 文档更新记录

| 版本 | 日期       | 主要变更                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ---- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 3.29 | 2026-09-11 | 明确模块开关职责边界：后端单写 `1001H`/`1002H`/`1003H`，互斥联动由 4CP 设备按 v1.22 执行，写后读回发布设备实际状态；快捷关机仍使用 10H 将三项写为 0。                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 3.27 | 2026-09-04 | 新增**第十五章 空调/地暖有无查询 API**（v1.4.2）：`GET /api/device/air-conditioner/presence` 与 `GET /api/device/floor-heating/presence`（裸对象，产品级静态 `false`——4CP 无空调无地暖，仅新风/调湿/超净，协议离散能力表无此两位，不依赖寄存器缓存永不 503；宏 `BEIANG_PRODUCT_HAS_*` 于 GlobalDefine.h）；`/api/device/capabilities` data 补充 `hasAirConditioner`/`hasFloorHeating` 静态字段并按源码更正响应示例（能力位读离散 3000H-3001H 缓存，未就绪 503）；同步 curl_test_cases.txt v3.21                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| 3.26 | 2026-09-04 | 新增**第十四章 内存水位监控 API**（v1.4.1）：`GET /api/memwatch/status`；后端 MemoryWatchModule 分级处置 MemAvailable（warn 64MB 日志 / restart 32MB SIGTERM 重启 flutter / reboot 16MB 重启设备，连续 3 次防抖、重启后 300s 冷却升级、OTA 抑制、禁 kill -9）；配置段 memwatch                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 3.25 | 2026-09-04 | 新增**第十三章 历史趋势 API**（v1.4.0）：`GET /api/history/trend?range=day\|week\|month[&date=YYYY-MM-DD]`（wrapped，12/7/N 点桶序列、空桶 null、温度 1 位小数）与 `GET /api/history/status`（采样/存储诊断）；采样源 200DH-2014H 只读缓存、18B/样本落盘 UDISK 日文件、保留 370 天；**移除**未实现桩 `GET /api/history/data`（404）；同步 curl_test_cases.txt |
| 3.24 | 2026-09-03 | 新增`GET /api/device/factory-test/status`（裸对象 `{factoryTestMode,factoryTestActive}`，读 1030H 缓存，v1.3.11）——此前 1030H 读值无任何 HTTP 接口暴露（仅裸读 /api/modbus/read），前端/测试可用 active 字段判断厂测锁接口可写性                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 3.23 | 2026-09-03 | 新增`GET /api/device/unit-run-mode/status`（裸对象 `{wholeUnitRunMode}`，读 100AH 缓存，v1.3.10）；§14 记录 100AH 设备端场景异步落位现象（写 ACK 后延迟应用，连续设定需间隔+读回确认）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 3.22 | 2026-09-03 | 新增`GET /api/device/leave-home/status`（裸对象 `{leaveHomeOn}`，读 1006H 周期采集缓存，v1.3.9）；总览表补 leave-home POST/GET 两行（计数按表行实际统计为 50）；记录 1006H 设备侧自主翻转现象（台架实测：无写操作时寄存器 0↔1 自变化，面板读写链路正常）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 3.21 | 2026-09-03 | 与 curl_test_cases.txt v3.15 交叉核对后的同步更新：`/api/device/power`、`/api/device/mode` 由"仅改内存"升级为**真实写**（v1.3.5 单写语义：开机单写 1001H=1、关机 1001H-1003H 全 0；mode 写 1007H 需 1001H=1）；模块开关（1001H/1002H/1003H）改为**单写+互斥联动由 4CP 设备端自动执行**（移除"超净不能与新风/调湿同时开启"400）；`/api/freshair/status` 更新为 v1.3.3 的 6 字段响应（新增 100CH `freshFanDutyCycle`，移除 1006H/201DH 字段）；控制类响应 `data.success` 统一更正为 `data.accepted`；1008H 写权限收紧为白名单 1007H∈{0,1,2,4}（v1.3.4）并补档位上限 400 场景；RTC 节重写（GET 转真实缓存读、POST 101BH-101FH 打包 5 寄存器、v1.3.8 新增 `format` 小时制参数与严格日历校验）；protocol/info 的 registerRanges 更正为 1000H-1076H/2000H-203BH；附录 B 纠正 fanGear=1008H、auxHeat=201CH、强度=1014H                                                                                                                                       |
| 3.20 | 2026-09-01 | **OTA 无更新时 start/cancel 改为直接 HTTP 409 `"当前无可用更新"`**（与 `canUpdate` 置灰逻辑一致）；保留下载/安装中重复 start 受理、失败弹窗 cleanup 退出、notifyPending 确认三条路径；板端实测修正前 200 → 修正后 409                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 3.19 | 2026-09-01 | **天气/定位标记为 ⏸ 暂不可用**：功能修改为由 emc6069 模组提供数据接口，模组侧接口目前暂无；原 libcurl 出网链路在 Linux 无网络出口（仅 lo 接口）架构下实测 500"获取公网IP失败"；新增 ⏸ 状态标记，两接口移出已实现总览（47→45）；接口契约保留待模组就绪后重接                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 3.18 | 2026-08-31 | 离散输入状态位补全：新增 bit36`除霜中`（`compressorStatus.defrosting`）；`faults` 节点新增 `anyFault` 聚合标志（bit64，存在故障=1）；bit33/34/35/37、故障明细位 64-76、250ms/50ms 时序、开关机不直写 1000H 此前已实现并实测                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 3.17 | 2026-08-31 | 输入寄存器 2000H-2014H 页核对：新增`deviceInfo.version`（2002H 原始值÷100，协议换算）；其余字段（工厂标志/机型/最大档位/FAN 档位与转速/RA1/OA 传感器）解析既有且已实机验证                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 3.16 | 2026-08-31 | 补全最后一段保持寄存器 105BH-1076H：新增`/api/factory/damper`(1071H-1076H 风阀方向 0/1 与步数标定，厂测锁)；厂测锁范围扩展至 0x1076；105BH-1070H FAN3/FAN4 标定此前已由 `/api/factory/fan-flow` 覆盖。**保持寄存器 1000H-1076H 语义接口全覆盖**（1024H 设备地址按高危故意不暴露）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 3.15 | 2026-08-31 | 补全 103DH-1070H 页语义接口：`/api/device/factory-reset`(1040H 只写高危，需 confirm=true)、`/api/factory/fan-flow`(1041H-1070H FAN 内外循环各档风量标定，厂测锁)；厂测锁地址范围扩展覆盖风量标定区；103DH/103EH 阀门2/3 与 103FH 清除计时此前已覆盖                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 3.14 | 2026-08-31 | 补全保持寄存器 1025H-1036H 页语义接口（7 个）：`/api/device/compressor`(1028H-102AH)、`/api/device/factory-test`(1030H，开启需 confirm=true)、`/api/device/pressure-switch`(102BH/102CH，厂测锁)、`/api/factory/fan`(1038H-103BH，厂测锁)、`/api/factory/valve`(103CH-103EH，厂测锁)、`/api/maintenance/filter`(1031H-1036H 复位，小时/天)；策略层新增厂测写前置校验（1030H≠100 拒绝）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 3.13 | 2026-08-31 | 补全保持寄存器 100BH-1020H 的语义写接口（8 个）：`/api/freshair/stepless`(100BH)、`/api/freshair/duty`(100CH/100DH/100EH)、`/api/device/target-temperature`(1010H,×10)、`/api/device/plasma-disinfect`(1011H)、`/api/device/aux-heat`(1013H)、`/api/humidity-module/intensity`(1014H)、`/api/device/sa-fan-ratio`(1015H,×10)、`/api/device/fan-delay-off`(1020H)；快照新增 `deviceControlParams.auxHeatSettingRaw`（1013H 设定值）；1024H 设备地址明确不提供语义接口                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 3.12 | 2026-08-31 | **再次修正 1008H 风量档位写权限**（协议最终确认）：`1001H=1 且 1007H∈{0,1,2,4}`（内循环/混风/全热新风/旁通换气）时可写；`1007H=3`（自动）、`5`（睡眠）只读；1006H 一键离家不再参与该判断（撤销 3.10 版解读）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 3.11 | 2026-08-31 | 新增**`POST /api/humidity-module/humidify`**（写 1004H）与 **`POST /api/humidity-module/dehumidify`**（写 1005H）：调湿模块 1003H 开启时按协议只读并返回 400；新增 **`POST /api/freshair/exhaust-speed`**（写 1009H 排风风量档位，协议预留）；`GET /api/humidity-module/status` 响应补充 `humidificationOn`/`dehumidificationOn`（1004H/1005H）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 3.10 | 2026-08-31 | **修正 1008H 风量档位写权限**为协议确认语义：`1001H=1（新风模块开启）且 1006H=0（一键离家关闭）`才可写（原误实现为 1007H≠3 自动模式拦截）；`/api/freshair/speed` 前置条件与错误提示同步更新                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 3.9  | 2026-08-31 | 升级到**通讯协议 v1.22**：`1006H` 由新风手动/自动改为**一键离家开关**（新增 `POST /api/device/leave-home`，`controlMode` 字段移除、改返回 `leaveHomeOn`）；`1007H` 运行模式扩展 **0-5**（3=自动模式，新增 `201DH` 自动模式内外循环显示）；`100AH` 由增压风量档位(预留)改为**整机运行模式**（新增 `POST /api/device/unit-run-mode`）；RTC 移至 `101BH-101FH`（10字节结构体打包 5 寄存器，0x10 写入）；新增 `102BH`/`102CH` 高低压开关、`1038H-103EH` 厂测 FAN/阀门设定、`1041H-1070H` 风机内外循环各档风量设定、`1071H-1076H` 风阀方向/步数设定；输入寄存器新增 `201DH-2023H`、`202BH-202FH`、`2030H-203BH` 主控板版本时间字符串，采集范围改为 `2000H-203BH`（60 个），保持寄存器采集范围改为 `1000H-1076H`（119 个）；能力位 bit0/2 语义改为加湿模块/旁通换气模式，新增 bit7 甲醛 HCHO、状态位 37 关机空气质量检测中；TVOC/甲醛换算为 mg/m³（÷100）；`/api/freshair/mode` 的 `automatic` 参数兼容映射 mode=3 |
| 3.8  | 2026-08-28 | 新增**第十二章 OTA 升级 API**（`GET /api/ota/status`、`POST /api/ota/start`、`POST /api/ota/cancel`）：经 emc6069 模组串口接收云端固件（http 传输+断点续传+MD5 校验），swupdate AB 整机升级、自动重启、失败回滚；`/api/runtime/snapshot` 与 `/api/local-device/status` 新增 `ota` 节点；WiFi 底层由 fork `emc6069_wifid` 改为直接调用 `libemc6069`（对外接口与状态行为不变），OTA 期间 WiFi 指令被互斥拒绝时不再误报 failed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 3.7  | 2026-08-27 | `/setAQILed` 升级呼吸效果与分级：优先经 rgb_daemon FIFO（`/tmp/rgb_test_fifo`）以 BREATHE（3 秒周期）驱动 9 路 RGB，rgb_daemon 缺席时直接熄灭（`multi_brightness` 全黑并上报关闭状态，不做常亮回退）；新增 `pm25` 参数自动分级（≤35→1 / 35~75→2 / 75~150→3 / >150→4）；等级色更新为 `1`=05DF72 绿、`2`=C2DF05 黄绿、`3`=F59E0B 黄、`4`=EF4444 红（旧紫 9C27B0 废除）；新增 `level=5` 严重故障告警（红色 EF4444，FAST_BREATHE 1 秒快速呼吸）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 3.6  | 2026-08-24 | `POST /setAQILed` 新增可选参数 `color`（6 位十六进制 RRGGBB，产测扩展）：传入时直接以该颜色写 9 路 `/sys/class/led/multi_brightness`，覆盖等级默认色；响应 `color` 字段返回实际写入颜色                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 3.5  | 2026-08-18 | `GET /getTempHumi` 由 ⚠️ 模拟升级为 **✅ 真实**（GXHTC3 sysfs hwmon，失败回退默认值）；`GET /getSensorSerial` 标注真实读取（serial_id）；人感雷达 `/setHumanPresenceRadar`、`/getHumanPresenceRadar` 由 ❌ 未实现升级为 **✅ 真实**（TRMK222-0 24GHz 毫米波雷达，状态文件 + 命令文件接入，返回 `enable/online/distance/velocity/signal/gesture/approach/depart/direction/timestamp`）；`/setAQILed` 由 enable/color 改为 level(0~4) 真实写 9 路 RGB                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 3.4  | 2026-08-14 | 升级到**通讯协议 v1.21**：保持寄存器全面重排（总开关/新风模块/超净/调湿模块开关模型，1000H-1040H）；输入寄存器 2003H/2004H 拆分为新风/内循环最大档位、201BH/201CH 改压缩机频率/电辅热状态、2026H-202AH 运行时间重排；离散输入能力扩展到 0-6、状态 32-35、故障码移至 64-76；通讯参数改为命令间隔≥250ms、超时50ms                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 3.3  | 2026-08-07 | 删除旧版裸 RTC 接口`GET /getRTCTime` 与 `POST /setRTCTime`（与 v1.20 的 `/api/rtc/time` 功能重复）；RTC 读写统一使用 `GET/POST /api/rtc/time`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| 3.2  | 2026-08-07 | `POST /api/rtc/time` 与 `POST /setRTCTime` 由模拟升级为**真实写设备**（10H 写 1016H-101FH），纠正 POST 请求体参数为 `time`/`timestamp`；`GET /api/idle/environment` 与 `air-quality-reminder` 改为**纯读周期采集缓存**（不再实时 Modbus 读），错误响应随之更新；`/getWeather` 标注需配置 `weather.apiKey`（默认配置已移除 weather 块）；附录 C 输入寄存器范围更正为 `2000H-205BH`；`/api/device/status` 的 `fanMaxGear` 标注为真实读取（2003H）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 3.1  | 2026-08-06 | 新增`GET /api/idle/air-quality-reminder`：依据室内(`200FH`)/室外(`2013H`) PM2.5 综合判定的待机页面空气评价提醒接口（7 种情形规则、分级标准与字段说明）；同步更新快速参考表、响应封装说明与错误码表                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 3.0  | 2026-08-06 | 以**当前源码实际行为**全面重写：纠正各端点实现状态（大量原标"已实现"实为未实现桩或模拟数据）；补全真实返回字段与响应结构；说明三种响应封装不一致性；新增 `/api/idle/environment`；修正章节编号与错误码；标注仅改内存未下发设备等部分实现项                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| 2.0  | 2026-08-05 | 面向 v1.20 协议的目标规范版（含较多尚未落地的字段描述）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 1.x  | 2024-07    | 初版 API 文档                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |

---

**文档版本**: 3.29
**最后更新**: 2026-09-11
**软件版本**: 1.4.2
**协议版本**: V1.22

*BeiAng8Panel — 4CP / 全热新风设备控制面板后端服务*
