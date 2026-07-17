#include <stdio.h>

// 模式
enum MODE {
    MODE_COOL = 0,
    MODE_DRY,
    MODE_FAN,
    MODE_HEAT,
    MODE_AUTO,
    MODE_MAX
};

// 风速
enum FLOW_SPEED {
    FLOW_SPEED_LOW = 0,
    FLOW_SPEED_MID,
    FLOW_SPEED_HIGH,
    FLOW_SPEED_AUTO_LOW,
    FLOW_SPEED_AUTO_MID,
    FLOW_SPEED_AUTO_HIGH,
    FLOW_SPEED_AIR,
    FLOW_SPEED_MAX
};

// 区域
enum ZONE {
    ZONE_LOUNGE = 0,
    ZONE_KITCHEN,
    ZONE_OFFICE,
    ZONE_BED,
    ZONE_MAX
};

/**
 * @brief 开关机
 *
 * @param power 1为开机，0为关机
 */
void setPower(int power);

/**
 * @brief 获取开关机状态
 *
 * @param power 1为开机，0为关机
 */
void getPower(int* power);

/**
 * @brief 设置温度
 *
 * @param temp 温度
 */
void setTemp(int temp);

/**
 * @brief 获取温度
 *
 * @param temp 温度
 */
void getTemp(int* temp);

/**
 * @brief 设置风速
 *
 * @param speed 风速
 */
void setSpeed(int speed);

/**
 * @brief 获取风速
 *
 * @param speed 风速
 */
void getSpeed(int* speed);

/**
 * @brief 设置模式
 *
 * @param mode 模式
 */
void setMode(int mode);

/**
 * @brief 获取模式
 *
 * @param mode 模式
 */
void getMode(int* mode);

/**
 * @brief 设置区域开关
 *
 * @param zone 区域
 * @param flag 1为开，0为关
 */
void setZone(int zone, int flag);

/**
 * @brief 获取区域开关
 *
 * @param zone 区域
 * @param flag 1为开，0为关
 */
void getZone(int zone, int* flag);