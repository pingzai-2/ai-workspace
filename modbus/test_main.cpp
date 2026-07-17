#include <stdio.h>
#include <unistd.h>

#include "daikin_modbus_rtu.hpp"

int main (int argc, char *argv[])
{
	open_modbus_connect();

	while(1)
	{
		set_power(8);
		sleep(10);
		set_power(0);
		sleep(10);
	}

	close_modbus_connect();

    return 0;
}
