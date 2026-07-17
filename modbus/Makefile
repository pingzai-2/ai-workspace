CURRENT_PATH := $(shell pwd)

KERNELDIR := /home/book/docu/R818/lichee/kernel/linux-4.9
LIBMODBUS_DIR := $(realpath ./libmodbus-r818/lib)
LIBMODBUS_INCLUDES := $(realpath ./libmodbus-r818/include/modbus)
OUT	= daikin_modbus

# 找到需要编译的源文件
#SRC_FILES := $(wildcard *.cpp)
SRC_FILES := daikin_modbus_rtu.cpp test_main.cpp

# 将 .cpp 文件列表转换成 .o 文件列表
OBJ_FILES := $(SRC_FILES:.cpp=.o)

all: $(OUT)_so $(OUT)_a

# 编译所有的 .o 文件并链接成最终的应用程序
#$(OUT): $(OBJ_FILES)
#	$(CROSS_COMPILE)g++ -static -g -Wall -o $@ $^

#动态链接的版本
$(OUT)_so: $(OBJ_FILES)
	$(CROSS_COMPILE)g++ -g -Wall -o $@ $^ -I$(LIBMODBUS_INCLUDES) -L$(LIBMODBUS_DIR) -lmodbus -std=c++11

#静态链接版本
$(OUT)_a: $(OBJ_FILES)
	$(CROSS_COMPILE)g++ -static -g -Wall -o $@ $^ -I$(LIBMODBUS_INCLUDES) -L$(LIBMODBUS_DIR) -lmodbus -std=c++11

# 生成每个 .o 文件的规则
%.o: %.cpp
	$(CROSS_COMPILE)g++ -g -Wall -I$(LIBMODBUS_INCLUDES) -c $< -o $@

# 清理目标
clean:
	rm -rf $(OUT)_so $(OUT)_a $(OBJ_FILES)

# 伪目标声明
.PHONY: clean

#aarch64-linux-gnu-g++ -static -o helloword helloword.c
