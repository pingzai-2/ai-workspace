#!/bin/bash

PWD=`pwd`
libmodbus_path=libmodbus-r818

mkdir -p $libmodbus_path

./autogen.sh

./configure \
--host=aarch64-linux-gnu \
--prefix=$PWD/$libmodbus_path \
--enable-shared \
--enable-static
