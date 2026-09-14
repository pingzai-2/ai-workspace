/*
 * emc6069_control.h
 *
 * EMC6069 WiFi模组串口通信模块 - YAT协议
 * 通过UART与EMC6069模组通信，提供WiFi控制、时间获取等接口
 *
 *  Created on: Aug 14, 2026
 *      Author: cwf
 */

#ifndef EMC6069_CONTROL_H
#define EMC6069_CONTROL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>

/* YAT 协议最大payload长度:
 * 普通指令≤1024, 但MCU OTA的0x39 http固件帧数据最多2048字节 + 10字节头
 * (Total4+Offset4+Size2), 故取2064 */
#ifndef YAT_MAX_PAYLOAD
#define YAT_MAX_PAYLOAD 2064
#endif

/* ============================================================
 * 打印日志总开关 (控制端: OTA日志与 emc6069.c 的WiFi交互日志共用)
 *
 * 1=开启(默认): printf/fprintf(stderr)/WIFI_LOG 输出同时写入日志文件
 *    EMC6069_OTA_LOG_PATH (固定大小 EMC6069_OTA_LOG_MAX_SIZE, 超限清空重写),
 *    控制台输出保持不变;
 * 0=关闭: 仅输出控制台, 不创建日志文件。
 * 编译期可用 -DEMC6069_LOG_ENABLE=0 覆盖本默认值
 * ============================================================ */
#ifndef EMC6069_LOG_ENABLE
#define EMC6069_LOG_ENABLE 1
#endif

#if EMC6069_LOG_ENABLE
/* OTA日志文件路径与大小上限 (字节), 仅在日志开启时生效 */
#ifndef EMC6069_OTA_LOG_PATH
#define EMC6069_OTA_LOG_PATH "/mnt/UDISK/emc6069.log"
#endif
#ifndef EMC6069_OTA_LOG_MAX_SIZE
#define EMC6069_OTA_LOG_MAX_SIZE (10 * 1024 * 1024)
#endif
#endif /* EMC6069_LOG_ENABLE */

/* WiFi连接后定时上报固件版本(0x32)的周期 (秒), 0=关闭自动上报;
 * 默认24小时; 测试时可临时改小或编译期 -D 覆盖 */
#ifndef EMC6069_OTA_VERSION_POLL_SEC
#define EMC6069_OTA_VERSION_POLL_SEC (24 * 60 * 60)
#endif

/* ============================================================
 * 网络状态枚举
 * ============================================================ */
typedef enum {
    EMC6069_NET_INIT          = 0,  /* 初始状态 */
    EMC6069_NET_PROVISIONING  = 1,  /* 配网状态 */
    EMC6069_NET_CONNECTING    = 2,  /* 正在连接路由器 */
    EMC6069_NET_CONNECTED      = 3,  /* 已连接路由器 */
} emc6069_net_status_t;

/* ============================================================
 * WiFi状态枚举 (0x11 网络状态通知: 模组主动下发, 仅3种状态)
 * ============================================================ */
typedef enum {
    EMC6069_WIFI_DISCONNECT = 0,  /* 0x00 路由器连接断开 */
    EMC6069_WIFI_CONNECTED  = 1,  /* 0x01 路由器连接成功 */
    EMC6069_WIFI_CONNECTING = 2,  /* 0x02 配网状态下，模组收到手机发来的SSID，开始连接路由器 */
} emc6069_wifi_status_t;

/* ============================================================
 * AP扫描结果
 * ============================================================ */
#ifndef SSID_MAX_LEN
#define SSID_MAX_LEN 32
#endif

#define EMC6069_MAX_AP_RESULTS 20

#define EMC6069_WIFI_CONNECT_TIMEOUT  20

/* 加密方式位掩码（与模组 +WSCAN 结果行的 sec 字段对应） */
typedef enum {
	WIFI_SEC_NONE = 0, //OPEN	开放无密码
	WIFI_SEC_WEP = 1,  //WEP	WEP（老旧基本不用）
	WIFI_SEC_WPA_PSK = 2,  //WPA‑PSK	WPA1 个人
	WIFI_SEC_WPA2_PSK = 3, //WPA2‑PSK	WPA2‑PSK (AES)，最常见
	WIFI_SEC_WPA_WPA2_PSK = 4,//WPA‑PSK + WPA2‑PSK	混合模式（路由器默认）
	WIFI_SEC_WPA3_PSK = 5,  //WPA3‑PSK	WPA3 个人（Wi‑Fi6 模组才会出现，EMC6069 支持）
	WIFI_SEC_WPA2_WPA3_PSK = 6,//WPA2‑PSK + WPA3‑PSK	WPA2/WPA3 混合
} emc6069_wifi_secure_t;

/* 扫描结果（高级扫描响应 ap_adv_list_t: ssid[32]+bssid[6]+channel+security+rssi, 每条41字节） */
typedef struct {
    char     ssid[SSID_MAX_LEN + 1];
    uint8_t  bssid[6];    /* BSSID (MAC地址) */
    uint8_t  channel;     /* 信道 */
    int8_t   rssi;
    int      key_mgmt;    /* WiFi安全类型(security字段): 0=开放, 1=WEP, 2=WPA, 3=WPA2, ... */
} emc6069_wifi_scan_result_t;

/* WiFi状态信息（合并网络状态 + WiFi信息） */
typedef struct {
    emc6069_net_status_t status;    /* 网络状态 */
    int8_t               rssi;      /* 信号强度 (dBm)，未连接时为0 */
    char                 ssid[33];  /* 已连接网络名称(0x18)，未连接时为空 */
    char                 mac[18];   /* MAC地址，未连接时为空 */
    char                 ip[16];    /* IP地址，未连接时为空 */
} emc6069_wifi_status_info_t;

/* UTC时间结构 */
typedef struct {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int weekday;
} emc6069_utc_time_t;

/* OTA事件类型 */
typedef enum {
    EMC6069_OTA_EVT_DOWNLOAD_START    = 0,  /* OTA下载开始 (offset=断点续传起点) */
    EMC6069_OTA_EVT_DOWNLOAD_PROGRESS = 1,  /* OTA下载进度更新 (百分比变化时上报) */
    EMC6069_OTA_EVT_DOWNLOAD_COMPLETE = 2,  /* OTA下载完成 (长度/MD5校验已通过) */
    EMC6069_OTA_EVT_INSTALL_START     = 3,  /* OTA安装开始 (执行swupdate前, 设备将重启);
                                             * 安装由应用自行完成时 (关闭模块内安装流程) 不产生该事件 */
    EMC6069_OTA_EVT_DOWNLOAD_FAILED   = 4,  /* OTA下载/校验失败 */
    EMC6069_OTA_EVT_FW_NOTIFY         = 5,  /* 0x38固件更新通知到达 (手动确认模式下
                                             * 由此事件通知UI, 应用确认后调 emc6069_ota_confirm_update) */
} emc6069_ota_event_t;

/* OTA事件数据 (percent由模块按 total/offset 计算填充) */
typedef struct {
    uint32_t    total;     /* 固件总长度 (字节), 未知为0 */
    uint32_t    offset;    /* 已下载长度 (字节) */
    uint32_t    percent;   /* 下载百分比 0~100 (PROGRESS事件为主要用途) */
    const char *fw_ver;    /* 固件版本, 可能为空 */
    const char *fw_path;   /* 固件保存路径 (下载完成/安装开始时有效) */
    const char *fw_md5;    /* 固件MD5 (FW_NOTIFY事件有效), 可能为空 */
} emc6069_ota_event_data_t;

/* 串口初始化 */
int emc6069_init(const char *device, int baud);

/* 重新设置串口波特率 (Ymodem OTA传输前/后切换), 返回0=成功, -1=失败 */
int emc6069_set_baud(int baud);

/* 获取当前波特率 */
int emc6069_get_baud(void);

/* 关闭串口 */
void emc6069_close(void);

/* 重启模组 */
int emc6069_reboot(void);

/* WiFi开关 (on_off: 1=开, 0=关) */
int emc6069_wifi_power(int on_off);

/* WiFi扫描 (0x14 0x01高级扫描, 结果含BSSID/信道/安全类型) */
int emc6069_wifi_scan(emc6069_wifi_scan_result_t *ap_list);

/* WiFi连接 */
int emc6069_wifi_connect(const char *ssid, const char *pwd);

/* WiFi断开 (ssid: 指定WiFi名称) */
int emc6069_wifi_disconnect(const char *ssid);

/* 获取UTC时间,写入系统时间和RTC (0=成功, 1=系统时间已更新但RTC失败, -1=失败) */
int emc6069_sync_time_to_system(void);

/* 获取WiFi状态信息：如果已连接路由器，返回MAC地址和IP地址 */
int emc6069_get_wifi_status(emc6069_wifi_status_info_t *info);

/* ============================================================
 * 0x11 网络状态通知回调（模组主动下发）
 * ============================================================ */
/* 回调函数：status=WiFi状态(0x11: 0=断开, 1=连接成功, 2=收到SSID开始连接),
 * userdata=注册时的自定义参数
 * 注意：回调在接收线程上下文中执行，禁止在回调内做阻塞操作或等待库函数返回 */
typedef void (*emc6069_net_status_cb_t)(emc6069_wifi_status_t status, void *userdata);

/* 注册0x11网络状态下发通知回调 */
int emc6069_register_net_status_cb(emc6069_net_status_cb_t cb, void *userdata);

/* 取消注册0x11网络状态下发通知回调 */
int emc6069_unregister_net_status_cb(void);

/* 事件回调: 在OTA接收线程/OTA线程中执行, 勿阻塞 */
typedef void (*emc6069_ota_listener_cb_t)(emc6069_ota_event_t evt,
                                          const emc6069_ota_event_data_t *data,
                                          void *user_data);

//用于R818升级，R528需要删除此宏开关
#define EMC6069_R818_OTA_SWU_PATH

/* 注册监听器, 返回监听器句柄 (>=1), -1=失败(已满或参数无效); 可注册多个 */
int  emc6069_ota_listener_add(emc6069_ota_listener_cb_t cb, void *user_data);

/* 注销监听器 (handle为add返回值; 无效句柄静默忽略) */
void emc6069_ota_listener_remove(int handle);

/* ============================================================
 * 0x38固件更新通知的二次确认
 * ============================================================ */
/* 应用收到 EMC6069_OTA_EVT_FW_NOTIFY 事件、用户确认升级后调用本函数回复0x38:
 *   choice: 0=Ymodem, 1=http
 * 返回: 0=已回复, -1=失败(无待确认通知/已有传输进行中/choice非法) */
int emc6069_ota_confirm_update(int choice);

/* 用户取消升级: 清除待确认状态, 不回复0x38 (与 confirm_update(-1) 等效, 语义更清晰)
 * 返回: 0=已取消, -1=无待确认通知/非二次确认模式 */
int emc6069_ota_cancel_update(void);

#ifdef __cplusplus
}
#endif // extern "C"

#endif /* EMC6069_CONTROL_H */
