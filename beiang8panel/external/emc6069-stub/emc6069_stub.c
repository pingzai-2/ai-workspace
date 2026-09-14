/*
 * emc6069_stub.c
 *
 * PC/macOS 原生调试构建用的 libemc6069 桩实现。
 * 板端交叉构建链接 SDK staging 里的真实 libemc6069.so；
 * 原生构建没有模组串口，这里全部以失败返回，使 OtaManager/WifiManager
 * 按“不可用”路径运行（与板上未接模组的表现一致）。
 *
 * 注意: 本目录的 emc6069.h 是 package/allwinner/emc6069-wifi/src/emc6069.h
 * 的副本，vendor 头文件更新时需同步。
 */

#include "emc6069.h"

int emc6069_init(const char *device, int baud)
{
    (void)device;
    (void)baud;
    return -1;
}

int emc6069_set_baud(int baud)
{
    (void)baud;
    return -1;
}

int emc6069_get_baud(void)
{
    return -1;
}

void emc6069_close(void)
{
}

int emc6069_reboot(void)
{
    return -1;
}

int emc6069_wifi_power(int on_off)
{
    (void)on_off;
    return -1;
}

int emc6069_wifi_scan(emc6069_wifi_scan_result_t *ap_list)
{
    (void)ap_list;
    return -1;
}

int emc6069_wifi_connect(const char *ssid, const char *pwd)
{
    (void)ssid;
    (void)pwd;
    return -1;
}

int emc6069_wifi_disconnect(const char *ssid)
{
    (void)ssid;
    return -1;
}

int emc6069_sync_time_to_system(void)
{
    return -1;
}

int emc6069_get_wifi_status(emc6069_wifi_status_info_t *info)
{
    (void)info;
    return -1;
}

int emc6069_register_net_status_cb(emc6069_net_status_cb_t cb, void *userdata)
{
    (void)cb;
    (void)userdata;
    return -1;
}

int emc6069_unregister_net_status_cb(void)
{
    return 0;
}

int emc6069_ota_listener_add(emc6069_ota_listener_cb_t cb, void *user_data)
{
    (void)cb;
    (void)user_data;
    return -1;
}

void emc6069_ota_listener_remove(int handle)
{
    (void)handle;
}

int emc6069_ota_confirm_update(int choice)
{
    (void)choice;
    return -1;
}

int emc6069_ota_cancel_update(void)
{
    return -1;
}
