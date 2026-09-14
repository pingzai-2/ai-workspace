# BeiAng8Panel 配置文件说明

## 配置文件位置

- **默认配置**: `config/FactoryConfig.json`
- **运行时加载**: 程序启动时自动加载
- **命令行指定**: `./BeiAng8Panel -c /path/to/config.json`

---

## 配置文件结构

```json
{
  "version": "1.0.0",
  "device": { ... },
  "serial": { ... },
  "network": { ... },
  "dataAcquisition": { ... },
  "display": { ... },
  "system": { ... },
  "modes": { ... }
}
```

---

## 详细配置说明

### 1. version - 版本信息

```json
"version": "1.0.0"
```

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 配置文件版本号，用于兼容性检查 |

---

### 2. device - 设备配置

```json
"device": {
  "name": "BeiAng 4CP Controller",
  "model": "R818-EVB2",
  "address": 209,
  "protocolVersion": "v1.10"
}
```

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| name | string | "BeiAng 4CP Controller" | - | 设备名称 |
| model | string | "R818-EVB2" | - | 设备型号 |
| address | integer | 209 | 1-247 | **Modbus 设备地址** (0xD1 = 209) |
| protocolVersion | string | "v1.10" | - | 通信协议版本 |

**重要说明**:
- `address` 是 Modbus RTU 通信的从站地址
- 地址范围: 1-247 (0x00-0xF7)
- 标准地址: 209 (0xD1)，如需修改请确保与设备物理地址一致

---

### 3. serial - 串口配置

```json
"serial": {
  "port": "/dev/ttyS0",
  "baudRate": 9600,
  "dataBits": 8,
  "stopBits": 1,
  "parity": "N",
  "timeout": 500,
  "commandInterval": 1000
}
```

| 字段 | 类型 | 默认值 | 可选值 | 说明 |
|------|------|--------|--------|------|
| port | string | "/dev/ttyS0" | "/dev/ttyS0", "/dev/ttyS1", ... | 串口设备路径 |
| baudRate | integer | 9600 | 4800, 9600, 19200, 38400, 57600, 115200 | 波特率 |
| dataBits | integer | 8 | 5, 6, 7, 8 | 数据位 |
| stopBits | integer | 1 | 1, 2 | 停止位 |
| parity | string | "N" | "N"(无), "O"(奇), "E"(偶) | 奇偶校验 |
| timeout | integer | 500 | 100-5000 | Modbus 响应超时(毫秒) |
| commandInterval | integer | 1000 | 500-5000 | **命令间隔时间**(毫秒) |

**Modbus RTU 标准配置**:
- 波特率: 9600
- 数据位: 8
- 停止位: 1
- 校验: 无校验 (N)
- 命令间隔: ≥500ms (协议要求)

---

### 4. network - 网络配置

```json
"network": {
  "httpHost": "0.0.0.0",
  "httpPort": 8080,
  "wifiSSID": "",
  "wifiPassword": "",
  "useDHCP": true,
  "ipAddress": "192.168.1.100",
  "netmask": "255.255.255.0",
  "gateway": "192.168.1.1"
}
```

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| httpHost | string | "0.0.0.0" | HTTP 服务器监听地址 (0.0.0.0 = 所有接口) |
| httpPort | integer | 8080 | HTTP 服务器端口 |
| wifiSSID | string | "" | WiFi SSID (预留) |
| wifiPassword | string | "" | WiFi 密码 (预留) |
| useDHCP | boolean | true | 是否使用 DHCP |
| ipAddress | string | "192.168.1.100" | 静态 IP 地址 (useDHCP=false 时生效) |
| netmask | string | "255.255.255.0" | 子网掩码 |
| gateway | string | "192.168.1.1" | 默认网关 |

---

### 5. dataAcquisition - 数据采集配置

```json
"dataAcquisition": {
  "interval": 1000,
  "maxRetryCount": 5,
  "autoReconnect": true
}
```

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| interval | integer | 1000 | 500-60000 | **数据采集周期**(毫秒) |
| maxRetryCount | integer | 5 | 1-20 | 连续失败最大重试次数 |
| autoReconnect | boolean | true | - | 超过重试次数后自动重连 |

**工作流程**:
1. 每 `interval` 毫秒采集一次设备数据
2. 采集失败时计数 +1
3. 连续失败达到 `maxRetryCount` 时：
   - 如 `autoReconnect=true`，自动断开重连
   - 如 `autoReconnect=false`，停止采集

---

### 5.1 ota - OTA 升级配置

```json
"ota": {
  "enabled": true,
  "serialPort": "/dev/ttyS1",
  "baudRate": 115200,
  "workDir": "/mnt/UDISK/beiang8panel/ota"
}
```

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| enabled | boolean | true | OTA 功能开关；false 时模组串口不被本程序占用 |
| serialPort | string | /dev/ttyS1 | emc6069 模组串口，本程序常驻持有（OTA 推送需要） |
| baudRate | integer | 1500000 | 模组串口波特率，须与模组固件一致（当前模组固件为 1.5M） |
| workDir | string | /mnt/UDISK/beiang8panel/ota | 固件工作目录（swupdate 读取 firmware.swu 的位置） |

**说明**:
- OTA 经 emc6069 模组接收云端固件，收尾由 `swupdate_cmd.sh` 做 AB 整机升级并自动重启
- 下载中固件固定落在 `/mnt/UDISK/emc6069_ota.bin`（库内编译期路径）；需保证 workDir 所在分区剩余空间大于固件包
- OTA 传输期间模组串口被独占，WiFi 扫描/连接等操作会被拒绝
- HTTP 接口见 `docs/HTTP_API.md` 第十二章（`/api/ota/*`）

---

### 6. display - 显示配置

```json
"display": {
  "brightness": 80,
  "screenSaverTime": 300,
  "autoSleep": true,
  "autoSleepTime": 600
}
```

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| brightness | integer | 80 | 0-100 | 屏幕亮度 (%) |
| screenSaverTime | integer | 300 | 0-3600 | 屏幕保激活时间(秒)，0=禁用 |
| autoSleep | boolean | true | - | 是否启用自动睡眠 |
| autoSleepTime | integer | 600 | 60-7200 | 自动睡眠时间(秒) |

---

### 7. system - 系统配置

```json
"system": {
  "language": "zh-CN",
  "timezone": "Asia/Shanghai",
  "logLevel": 1
}
```

| 字段 | 类型 | 默认值 | 可选值 | 说明 |
|------|------|--------|--------|------|
| language | string | "zh-CN" | "zh-CN", "en-US" | 界面语言 |
| timezone | string | "Asia/Shanghai" | IANA 时区 | 系统时区 |
| logLevel | integer | 1 | 0-4 | **日志级别** (0=DEBUG, 1=INFO, 2=WARNING, 3=ERROR, 4=FATAL) |

---

### 8. modes - 工作模式配置

#### 8.1 manual - 手动模式

```json
"manual": {
  "defaultFanSpeed": 2,
  "uvLightEnabled": false,
  "ionizerEnabled": false
}
```

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| defaultFanSpeed | integer | 2 | 0-6 | 默认风机档位 (0=关闭, 1-6=档位) |
| uvLightEnabled | boolean | false | - | 默认 UV 灯状态 |
| ionizerEnabled | boolean | false | - | 默认离子发生器状态 |

#### 8.2 smart - 智能模式

```json
"smart": {
  "defaultScene": 0,
  "targetPM25": 35.0,
  "targetCO2": 1000.0,
  "sleepTimeStart": 1320,
  "sleepTimeEnd": 420
}
```

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| defaultScene | integer | 0 | 0-3 | 默认智能场景 (0=自动, 1=睡眠, 2=强力, 3=安静) |
| targetPM25 | float | 35.0 | 0-500 | 目标 PM2.5 (μg/m³) |
| targetCO2 | float | 1000.0 | 400-5000 | 目标 CO2 (ppm) |
| sleepTimeStart | integer | 1320 | 0-1439 | 睡眠模式开始时间 (分钟，1320=22:00) |
| sleepTimeEnd | integer | 420 | 0-1439 | 睡眠模式结束时间 (分钟，420=07:00) |

**时间格式说明**:
- 以午夜 0 点为 0 分钟
- 1320 分钟 = 22 × 60 + 0 = 22:00
- 420 分钟 = 7 × 60 + 0 = 07:00

---

## 配置示例

### 基本配置 (出厂默认)

```json
{
  "version": "1.0.0",
  "device": {
    "address": 209
  },
  "serial": {
    "port": "/dev/ttyS0",
    "baudRate": 9600,
    "dataBits": 8,
    "stopBits": 1,
    "parity": "N"
  }
}
```

### 高级配置 (完整)

```json
{
  "version": "1.0.0",
  "device": {
    "name": "BeiAng 4CP Controller",
    "model": "R818-EVB2",
    "address": 209,
    "protocolVersion": "v1.10"
  },
  "serial": {
    "port": "/dev/ttyS0",
    "baudRate": 9600,
    "dataBits": 8,
    "stopBits": 1,
    "parity": "N",
    "timeout": 500,
    "commandInterval": 1000
  },
  "network": {
    "httpHost": "0.0.0.0",
    "httpPort": 8080
  },
  "dataAcquisition": {
    "interval": 1000,
    "maxRetryCount": 5,
    "autoReconnect": true
  },
  "system": {
    "logLevel": 1
  }
}
```

### 多设备配置 (不同地址)

```json
{
  "device": {
    "address": 10
  },
  "serial": {
    "port": "/dev/ttyS1",
    "baudRate": 19200
  }
}
```

---

## 配置验证

程序在每个进程启动时只读取一次配置。配置会先完成结构、类型和范围校验，
校验通过后才提交为该进程的运行态快照。无效配置不会使用默认串口或默认端口
继续运行，而是停用对应进程；原配置文件不会被自动修复或覆盖。

| 参数 | 验证规则 |
|------|----------|
| device.address | 出现时必须为 1-247 |
| serial.port / transport.endpoint | 必须是非空字符串；`transport.endpoint: null` 表示停用该路 |
| serial.baudRate / transport.baudRate | 必须是正整数 |
| serial.dataBits / transport.dataBits | 5-8 |
| serial.stopBits / transport.stopBits | 1-2 |
| serial.parity / transport.parity | 单字符 N/O/E |
| serial.timeout / transport.timeout | 0-60000 毫秒 |
| network.httpHost | 必须是非空字符串 |
| network.httpPort | 1-65535，多个进程不能重复 |

进程 1 兼容 `serial` 配置；其它通信进程使用通用 `transport` 配置。
同一 endpoint 不能被多个进程重复使用。串口实际打开时还会做轻量独占检查，
端点不存在、被占用或运行中出现 `EIO/ENODEV` 等硬件错误时，该路停止。

---

## 配置热更新

当前版本**不支持**运行时热更新配置。配置只在进程启动时读取一次；修改配置后需要：

1. 更新 `config/FactoryConfig.json`
2. 重启对应的 BeiAng8Panel 进程

退出时不会自动保存 JSON。未来若增加受控运行时配置接口，只在实际修改成功后显式保存，
并使用临时文件、原子替换和读回校验；保存失败时保留原文件。

---

## 故障排查

### 问题：设备连接失败

**检查项**:
1. `device.address` 是否与设备物理地址一致
2. `serial.port` 路径是否正确
3. 串口权限：`ls -l /dev/ttyS0`
4. 波特率、校验位是否与设备匹配

**解决方案**:
```bash
# 添加串口权限
sudo chmod 666 /dev/ttyS0

# 或将用户加入 dialout 组
sudo usermod -a -G dialout $USER
```

### 问题：HTTP 无法访问

**检查项**:
1. `network.httpPort` 是否被占用
2. 防火墙是否阻止端口

**解决方案**:
```bash
# 检查端口占用
netstat -tlnp | grep 8080

# 修改端口
# 编辑 config/FactoryConfig.json，修改 "httpPort": 8080
```

---

## 配置备份与恢复

### 备份
```bash
cp config/FactoryConfig.json config/FactoryConfig.json.backup
```

### 恢复
```bash
cp config/FactoryConfig.json.backup config/FactoryConfig.json
```

### 恢复出厂设置
```bash
cp config/FactoryConfig.json.example config/FactoryConfig.json
```

---

## 更多信息

- **协议文档**: 参考 BeiAng 4CP Modbus 协议 v1.10
- **API 文档**: HTTP REST API 接口说明
- **日志文件**: `logs/beiang8panel.log`
