#include <stdio.h>

#define DAIKIN_SLAVE_ID 1
#define DAIKIN_IR_ADDRESS 30001
#define DAIKIN_HR_ADDRESS 40001
#define DEBUG_EN 1

/**
 * @brief open modbus connect
 */
int open_modbus_connect(void);

/**
 * @brief close modbus connect
 */
int close_modbus_connect(void);

/**
 * @brief power on/off
 * @param power 0:off, 1:on
 */
void set_power(int power);

/**
 * @brief get power status
 * @param power 0:off, 1:on
 */
void get_power(int* power);

/**
 * @brief set temperature
 * @param temp 16~30
 */
void set_temperature(int temp);

/**
 * @brief get temperature
 * @param temp 16~30
 */
void get_temperature(int* temp);

/**
 * @brief set mode
 * @param mode 0:fan, 1:dry, 2:auto, 3:cool, 4:heat
 */
void set_mode(int mode);

/**
 * @brief get mode
 * @param mode 0:fan, 1:heat, 2:cool, 3:auto, 7:dry
 */
void get_mode(int* mode);

/**
 * @brief set flow speed
 * @param speed 0:low, 1:mid, 2:high, 3:auto low, 4:auto mid, 5:auto high, 6:airside
 */
void set_flow_speed(int speed);

/**
 * @brief get flow speed
 * @param speed 0:low, 1:mid, 2:high, 3:auto low, 4:auto mid, 5:auto high, 6:airside
 */
void get_flow_speed(int* speed);

/**
 * @brief set zone on/off
 * @param direction 0~7:zone1~8
 * @param flag 0:off, 1:on
 */
void set_zone(int zone, int flag);

/**
 * @brief get zone on/off status
 * @param direction 0~7:zone1~8
 * @param flag 0:off, 1:on
 */
void get_zone(int zone, int* flag);
