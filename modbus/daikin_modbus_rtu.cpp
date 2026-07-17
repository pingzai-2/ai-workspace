#include "daikin_modbus_rtu.hpp"

#include <errno.h>
#include <modbus.h>
#include <stdio.h>

static modbus_t* ctx = NULL;

int open_modbus_connect(void)
{
	int rc;
    ctx = modbus_new_rtu("/dev/ttyS3", 19200, 'E', 8, 1);
    if (ctx == NULL) {
        printf("Unable to create the libmodbus context\n");
        return -1;
    }

    modbus_set_debug(ctx, DEBUG_EN);

	rc = modbus_set_slave(ctx, DAIKIN_SLAVE_ID);
	if (rc == -1) {
		fprintf(stderr, "Invalid slave ID\n");
		//modbus_free(ctx);
		return -1;
    }

    modbus_set_response_timeout(ctx, 1, 0);

    if (modbus_connect(ctx) == -1) {
        printf("Connection failed: %s\n", modbus_strerror(errno));
        modbus_free(ctx);
        return -1;
    }

    printf("open_modbus_connect successful\n");
    return 0;
}

int close_modbus_connect(void)
{
    if (ctx != NULL) {
        modbus_close(ctx);
        modbus_free(ctx);
        ctx = NULL;
    }

    return 0;
}

void set_power(int power)
{
	modbus_write_register(ctx, 40022 - DAIKIN_HR_ADDRESS, power); return;

    uint16_t reg;

    int rc = modbus_read_registers(ctx, 40022 - DAIKIN_HR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read power status failed: %s\n", modbus_strerror(errno));
        return;
    }

    if (power == 0) {
        reg &= ~(1 << 3);
    } else {
        reg |= (1 << 3);
    }

    rc = modbus_write_register(ctx, 40022 - DAIKIN_HR_ADDRESS, reg);
    if (rc == -1) {
        printf("Write power status failed: %s\n", modbus_strerror(errno));
        return;
    }
}

void get_power(int* power)
{
    uint16_t reg;

    int rc = modbus_read_registers(ctx, 40022 - DAIKIN_HR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read power status failed: %s\n", modbus_strerror(errno));
        return;
    }

    *power = (reg >> 3) & 0x01;
}

void get_temperature(int* temp)
{
    int mode;
    get_mode(&mode);

    uint16_t reg;

    int rc = modbus_read_input_registers(ctx, 30042 - DAIKIN_IR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read temperature failed: %s\n", modbus_strerror(errno));
        return;
    }

    if (mode == 1) {
        // heat 取8~14bit
        *temp = (reg >> 7) & 0x7F;
    } else if (mode == 2) {
        // cool 取0~6bit
        *temp = (reg >> 0) & 0x7F;
    } else {
        // other
    }
}

void set_temperature(int temp)
{
    int mode;
    get_mode(&mode);

    // 将temp写入到reg 8~14bit
    uint16_t reg = (temp & 0x7F) << 7;

    int rc = 0;

    if (mode == 1) {
        // heat
        rc = modbus_write_register(ctx, 40024 - DAIKIN_HR_ADDRESS, reg);
    } else if (mode == 2) {
        // cool
        rc = modbus_write_register(ctx, 40023 - DAIKIN_HR_ADDRESS, reg);
    } else {
        // other
    }

    if (rc == -1) {
        printf("Write temperature failed: %s\n", modbus_strerror(errno));
        return;
    }
}

void get_mode(int* mode)
{
    uint16_t reg;

    int rc = modbus_read_input_registers(ctx, 30030 - DAIKIN_IR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read mode failed: %s\n", modbus_strerror(errno));
        return;
    }

    // 取8~10bit
    *mode = (reg >> 7) & 0x07;
}

void set_mode(int mode)
{
    uint16_t reg;

    int rc = modbus_read_registers(ctx, 40022 - DAIKIN_HR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read mode failed: %s\n", modbus_strerror(errno));
        return;
    }

    // 写入0~2bit
    reg &= ~(0x07 << 0);
    reg |= (mode & 0x07) << 0;

    rc = modbus_write_register(ctx, 40022 - DAIKIN_HR_ADDRESS, reg);
    if (rc == -1) {
        printf("Write mode failed: %s\n", modbus_strerror(errno));
        return;
    }
}

int flow_speed_judge(int setting, int tap)
{
    if (setting == 0) {
        // Manual
        if (tap == 1) {
            // low
            return 0;
        } else if (tap == 3) {
            // mid
            return 1;
        } else if (tap == 5) {
            // high
            return 2;
        }
    } else if (setting == 1) {
        // Auto
        if (tap == 1) {
            // auto low
            return 3;
        } else if (tap == 3) {
            // auto mid
            return 4;
        } else if (tap == 5) {
            // auto high
            return 5;
        }
    } else if (setting == 2) {
        // Multi/AirSide
        return 6;
    }

	return 0;
}

void get_flow_speed(int* speed)
{
    int mode;
    get_mode(&mode);

    uint16_t reg;

    int rc = modbus_read_input_registers(ctx, 30032 - DAIKIN_IR_ADDRESS, 1, &reg);
    if (rc == -1) {
        printf("Read flow speed failed: %s\n", modbus_strerror(errno));
        return;
    }

    int auto_munual_multi_setting;
    int fan_tap;

    if (mode == 1) {
        // heat
        // 取12~13bit
        auto_munual_multi_setting = (reg >> 11) & 0x03;
        // 取8~11bit
        fan_tap = (reg >> 7) & 0x0F;
        *speed = flow_speed_judge(auto_munual_multi_setting, fan_tap);
    } else if (mode == 2) {
        // cool
        // 取4~5bit
        auto_munual_multi_setting = (reg >> 3) & 0x03;
        // 取0~3bit
        fan_tap = (reg >> 0) & 0x0F;
        *speed = flow_speed_judge(auto_munual_multi_setting, fan_tap);
    } else {
        // other
    }
}