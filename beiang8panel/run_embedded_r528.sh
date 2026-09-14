#!/bin/sh

# ===== 用户配置区：板端路径变化时只需优先检查/修改这里 =====
BEIANG_R528_BOARD_APPS_ROOT="${BEIANG_R528_BOARD_APPS_ROOT:-/mnt/UDISK}"
BEIANG_R528_BOARD_APP_NAME="${BEIANG_R528_BOARD_APP_NAME:-}"
BEIANG_R528_BOARD_APP_ROOT="${BEIANG_R528_BOARD_APP_ROOT:-}"
BEIANG_R528_EXECUTABLE_NAME="${BEIANG_R528_EXECUTABLE_NAME:-BeiAng8Panel}"
BEIANG_R528_CONFIG_NAME="${BEIANG_R528_CONFIG_NAME:-FactoryConfig.json}"
BEIANG_R528_CONFIG_2_NAME="${BEIANG_R528_CONFIG_2_NAME:-FactoryConfig_2.json}"
BEIANG_R528_CONFIG_3_NAME="${BEIANG_R528_CONFIG_3_NAME:-FactoryConfig_3.json}"
BEIANG_R528_CONFIG_4_NAME="${BEIANG_R528_CONFIG_4_NAME:-FactoryConfig_4.json}"
# ===== 用户配置区结束；下面是运行逻辑 =====

set -eu

# R528 板端 App 直接运行入口。
#
# 职能：
#   1. 自己解析 App 根目录、可执行文件和配置文件路径。
#   2. 自己设置 App 运行所需环境。
#   3. 直接启动 App，不依赖其它启动脚本才能运行。
#
# 默认部署约定：
#   Apps:       ${BEIANG_R528_BOARD_APPS_ROOT}/
#   App:        ${BEIANG_R528_BOARD_APPS_ROOT}/<APP_NAME>/
#   Executable: ${APP_ROOT}/${BEIANG_R528_EXECUTABLE_NAME}
#   Config:     ${APP_ROOT}/${BEIANG_R528_CONFIG_NAME}
#
# 大概成功路径：
#   Linux x86_64 构建主机准备 R528 SDK/交叉编译器环境
#   -> ./build_embedded_r528.sh
#   -> 校验 output/MD5SUMS 和 ARM EABI5 BeiAng8Panel
#   -> 把完整 output/ 部署到 ${BEIANG_R528_BOARD_APPS_ROOT}/<APP_NAME>/
#   -> 在 R528 板端执行本脚本。
#
# 用法：
#   ./run_embedded_r528.sh
#       运行与当前工程目录同名的已部署 App。
#   ./run_embedded_r528.sh APP_NAME
#       运行 ${BEIANG_R528_BOARD_APPS_ROOT}/APP_NAME。
#   ./run_embedded_r528.sh /绝对路径/to/app_bundle
#       直接运行指定 App bundle，例如当前工程的 output/。
#
# 路径参数统一在文件最上方“用户配置区”修改，也可在执行前用同名环境变量覆盖。
#
# 多 App/开机启动统一使用本脚本 APP_NAME。
# 开机配置中只保留一条有效命令。

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DEFAULT_APP_NAME="${PROJECT_ROOT##*/}"
APPS_ROOT="${BEIANG_R528_BOARD_APPS_ROOT}"

if [ "$#" -gt 0 ]; then
  case "$1" in
    /*) APP_ROOT="$1" ;;
    *) APP_ROOT="${APPS_ROOT}/$1" ;;
  esac
elif [ -n "${BEIANG_R528_BOARD_APP_ROOT}" ]; then
  APP_ROOT="${BEIANG_R528_BOARD_APP_ROOT}"
else
  APP_NAME="${BEIANG_R528_BOARD_APP_NAME:-${DEFAULT_APP_NAME}}"
  APP_ROOT="${APPS_ROOT}/${APP_NAME}"
fi

APP_EXECUTABLE="${APP_ROOT}/${BEIANG_R528_EXECUTABLE_NAME}"
APP_CONFIG="${APP_ROOT}/${BEIANG_R528_CONFIG_NAME}"
APP_CONFIG_2="${APP_ROOT}/${BEIANG_R528_CONFIG_2_NAME}"
APP_CONFIG_3="${APP_ROOT}/${BEIANG_R528_CONFIG_3_NAME}"
APP_CONFIG_4="${APP_ROOT}/${BEIANG_R528_CONFIG_4_NAME}"

export LANG="${LANG:-en_US.UTF-8}"

cd "${APP_ROOT}"
exec "${APP_EXECUTABLE}" \
  -c "${APP_CONFIG}" \
  -c "${APP_CONFIG_2}" \
  -c "${APP_CONFIG_3}" \
  -c "${APP_CONFIG_4}"
