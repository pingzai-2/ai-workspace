# OTA 升级测试指引（adb 接口测试）

适用固件：2026-08-28 之后构建的版本（含 OTA 后端、通用 DMA、1024 分包库）。
测试前提：云平台已注册 OTA 任务（模块名 `mcu`、目标版本高于设备当前版本、
固件文件已上传、任务已启动），并已知一个可用的 **2.4G** WiFi 的 SSID 和密码。

## 一、主流程（按顺序执行）

### 1. 连接确认
```sh
adb devices
# 期望：设备列出且状态为 device
```

### 2. 基础状态检查
```sh
adb shell cat /etc/version                                      # 记录当前版本(基线)
adb shell "ps | grep BeiAng8Panel | grep -v grep"               # 后端应在运行
adb shell "grep baudRate /mnt/UDISK/beiang8panel/FactoryConfig.json"
# 第一处 baudRate 是 ota 的，应为 1500000
```

若 ota.baudRate 不是 1500000（重刷固件后常见），按此流程修正——**必须 kill -9**：
普通 kill 会让后端退出时把内存中的旧配置写回，覆盖你的修改：
```sh
adb shell "kill -9 \$(pidof BeiAng8Panel); sleep 1; \
  sed -i 's/\"baudRate\": 115200/\"baudRate\": 1500000/' \
  /mnt/UDISK/beiang8panel/FactoryConfig.json; \
  (trap '' HUP; /usr/bin/BeiAng8Panel >/tmp/beiang.log 2>&1 &); sleep 8; \
  grep -o 'started on /dev/ttyS1 @[0-9]*' /tmp/beiang.log"
# 期望输出：started on /dev/ttyS1 @1500000
```

### 3. 关闭前端应用（防止自动重连 WiFi 抢占扫描/通知）
```sh
adb shell "killall flutter_eglfs"
```

### 4. 连接 WiFi（SSID/密码按实际环境修改，须为 2.4G 网络）
```sh
adb shell "printf '{\"ssid\":\"MDD-SW\",\"password\":\"sw123456\"}' > /tmp/conn.json; \
  curl -s -X POST -H 'Content-Type: application/json' \
  --data-binary @/tmp/conn.json http://127.0.0.1:8080/api/local-device/wifi/connect"
# 期望：{"accepted":true,"ssid":"..."}，约 20 秒内完成
```

### 5. 确认 WiFi 与云平台连接
```sh
adb shell "curl -s http://127.0.0.1:8080/api/local-device/status" \
  | grep -o '"connected":[a-z]*,"connectedSsid":"[^"]*"'
# 期望："connected":true 且有 SSID

adb shell "grep -E '0x21|0x32' /mnt/UDISK/emc6069.log | tail -3"
# 期望：出现 "服务器连接成功" 与 "上报: mcu-x.y.z"
```

### 6. 等待云端推送并确认 OTA 通知（连接后约 0.5~2 分钟）
```sh
adb shell "curl -s http://127.0.0.1:8080/api/ota/status"
# 期望："updateAvailable":true、"state":"notifyPending"、"canUpdate":true
# （产品形态下此时前端弹出①更新确认框，更新按钮高亮）
```
> 一直 updateAvailable:false → 检查云平台：模块名必须是 `mcu`、
> 目标版本必须大于设备当前版本、任务必须已启动。

### 7. 启动进度记录（每 10 秒采样，写入 /mnt/UDISK 重启不丢）
```sh
adb shell "rm -f /mnt/UDISK/ota_progress.log; (trap '' HUP; while true; do \
  echo \"\$(date +%H:%M:%S)|\$(curl -s -m 3 http://127.0.0.1:8080/api/ota/status)\" \
  >> /mnt/UDISK/ota_progress.log; sleep 10; done >/dev/null 2>&1 &); date +%H:%M:%S"
```

### 8. 触发下载（对应前端"立即更新"按钮）
```sh
adb shell "curl -s -X POST -H 'Content-Type: application/json' \
  -d '{}' http://127.0.0.1:8080/api/ota/start; date +%H:%M:%S"
# 期望：{"accepted":true}；state 依次 preparing → downloading
```

### 9. 监控下载进度（96.7MB 压缩包约 12~16 分钟，实测 24 分钟@1024包）
```sh
adb shell "tail -3 /mnt/UDISK/ota_progress.log | cut -c1-140"
# 或查单次状态：
adb shell "curl -s http://127.0.0.1:8080/api/ota/status" \
  | grep -oE '"state":"[a-z]+"|"percent":[0-9]+|"downloadedBytes":[0-9]+'
# 下载完成标志：日志出现 "MD5校验" 且 计算=期望；
# 随后 state: downloadComplete → installing
```

### 10. 安装与自动重启（④升级弹窗阶段，请勿断电）
state=installing 后 swupdate 写另一槽位并自动重启（约 2~4 分钟，设备会掉线）。
等待设备重新上线：
```sh
for i in 1 2 3 4 5 6 7 8 9 10; do sleep 20; adb devices | grep -q "device$" && break; done
```

### 11. 升级结果验证
```sh
adb shell cat /etc/version
# 应为 OTA 包的目标版本号

adb shell "grep 'SWUPDATE successful' /mnt/UDISK/swupdate.log | tail -1"
# 应输出：SWUPDATE successful !

adb shell "curl -s http://127.0.0.1:8080/api/ota/status" \
  | grep -o '"currentVersion":"[^"]*"'
# 应等于新版本号，且 state=idle、error 为空
```

### 12. 取回进度记录并恢复前端应用
```sh
adb pull /mnt/UDISK/ota_progress.log .
adb shell "(trap '' HUP; flutter_eglfs -r 90 /usr/bin/bundle/ >/dev/null 2>&1 &)"
```

## 二、异常/分支流程

```sh
# "下次再说"（取消当前通知；更新按钮仍高亮，云重推后需再次取消）
adb shell "curl -s -X POST -H 'Content-Type: application/json' \
  -d '{}' http://127.0.0.1:8080/api/ota/cancel"

# 下载失败弹窗"退出"（删除已下载残留文件）
adb shell "curl -s -X POST -H 'Content-Type: application/json' \
  -d '{\"cleanup\":true}' http://127.0.0.1:8080/api/ota/cancel"

# 下载失败弹窗"重试"（模组重推通知后自动确认续传，无需再弹确认框）
adb shell "curl -s -X POST -H 'Content-Type: application/json' \
  -d '{}' http://127.0.0.1:8080/api/ota/start"
```

## 三、常见问题速查

| 现象 | 原因与处理 |
|------|-----------|
| updateAvailable 一直 false | 云平台任务未注册/未启动；或模块名不是 `mcu`；或目标版本不高于设备版本 |
| WiFi 连接一直失败 | AP 必须 2.4G；先用扫描确认 AP 可见：`curl -s http://127.0.0.1:8080/api/local-device/wifi/scan`（GET同步聚合, POST版已移除） |
| 改过的配置被改回去 | 后端优雅退出会回写内存配置，**改配置前必须 kill -9** |
| 下载停滞在 6144 字节 | 固件里的库是 2048 分包版（模组不支持），换 2026-08-28 17:19 之后构建的固件/包 |
| 状态一直 preparing 不动 | 确认动作未被处理：重启后端（kill -9 后按第 2 步流程拉起），重新 POST /api/ota/start |
| 重启后 WiFi 又连不上 | 前端保存的 WiFi 若不可达会覆盖模组配置，改前端配置文件里 savedWifiNetworks 为可用网络 |

## 四、关键观察点

- 下载吞吐：正常约 70~80KB/s（1.5M 串口逐包等待主导），96.7MB 约 20~24 分钟
- 串口质量：`adb shell cat /sys/devices/platform/soc/uart1/ctrl_info`，
  overrun/frame 应保持 0（DMA 接收）
- 模组日志：`/mnt/UDISK/emc6069.log`（全部收发、校验、重传记录）
- 安装日志：`/mnt/UDISK/swupdate.log`（成功标志 "SWUPDATE successful"）
