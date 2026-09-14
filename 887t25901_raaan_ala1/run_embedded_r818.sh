#!/bin/sh

# ===== 用户配置区：板端路径或显示方式变化时只需优先检查/修改这里 =====
# Runtime 根目录
FLUTTER_R818_BOARD_RUNTIME_ROOT="${FLUTTER_R818_BOARD_RUNTIME_ROOT:-/arm-flutter-3.3.7-r818}"
# Runner 类型和旋转角度
FLUTTER_R818_RENDERER="${FLUTTER_R818_RENDERER:-eglfs}"
FLUTTER_R818_ROTATION="${FLUTTER_R818_ROTATION:-90}"
# 可选：指定 Runner、App 名或 App 绝对目录；留空时由脚本推导
FLUTTER_R818_RUNNER="${FLUTTER_R818_RUNNER:-}"
FLUTTER_BOARD_APP_NAME="${FLUTTER_BOARD_APP_NAME:-}"
FLUTTER_BOARD_APP_ROOT="${FLUTTER_BOARD_APP_ROOT:-}"
# 实际配置内容使用外置目录，必须与对应的编译脚本 build_*.sh 的编译值一致。
# App 安装目录内仍始终保留空 config/。
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-/mnt/UDISK/app/config}"
# 配置部署契约：启动前必须已把 output/config/ 内容转移到 FLUTTER_BOARD_CONFIG_ROOT，App 内部 config/ 只保留空目录。
# ===== 用户配置区结束；下面是运行逻辑 =====

set -eu

# R818 板端 App 直接运行入口。
#
# 职能：
#   1. 自己解析 Runtime、App、Runner、渲染器和旋转参数。
#   2. 自己设置 Engine/动态库所需环境。
#   3. 直接启动 App，不依赖 Runtime 的 flutter_run.sh 才能运行。
#
# 默认部署约定：
#   Runtime: ${FLUTTER_R818_BOARD_RUNTIME_ROOT}/
#   App:     ${FLUTTER_R818_BOARD_RUNTIME_ROOT}/apps/<APP_NAME>/
#   Runner:  ${FLUTTER_R818_RUNNER}，留空时按渲染器自动推导
#   App config dir: ${APP_ROOT}/config/（保留空目录）
#   Config content: ${FLUTTER_BOARD_CONFIG_ROOT}/
#   Rotation: 90
#
# 大概成功路径：
#   Linux x86_64 构建主机准备 Flutter 3.3.7 + R818 Runtime/gen_snapshot
#   -> ./build_embedded_r818.sh
#   -> 校验 output/MD5SUMS 和 AArch64 lib/libapp.so
#   -> 把完整 output/ 部署到 Runtime/apps/<APP_NAME>/
#   -> 在 R818 板端执行本脚本。
#
# 三种材料情景也可从本脚本反推：
#   只有 Runtime：可运行 apps/ 中已有 App；部署本工程还缺 App 工程和构建环境。
#   只有 App：还缺匹配 Runtime、Linux x86_64 gen_snapshot/ICU 和 Flutter 3.3.7。
#   Runtime + App：构建环境到位后生成 output/，完整部署后即可用本脚本启动。
#
# 用法：
#   ./run_embedded_r818.sh
#       运行与当前工程目录同名的已部署 App。
#   ./run_embedded_r818.sh APP_NAME
#       运行 Runtime/apps/APP_NAME。
#   ./run_embedded_r818.sh /绝对路径/to/app_bundle
#       直接运行指定 App bundle，例如当前工程的 output/。
#
# 路径和显示参数统一在文件最上方“用户配置区”修改，也可在执行前用同名环境变量覆盖。
#
# 多 App/开机启动可任选一种完整入口；两者职能允许重复：
#   本脚本 APP_NAME
#   ${FLUTTER_R818_BOARD_RUNTIME_ROOT}/flutter_run.sh APP_NAME
# 两种入口允许职能重合；开机配置中只保留一条有效命令。
# Runtime 根目录不再使用旧 run.sh 或 current_app。

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DEFAULT_APP_NAME="${PROJECT_ROOT##*/}"
RUNTIME_ROOT="${FLUTTER_R818_BOARD_RUNTIME_ROOT}"
RENDERER="${FLUTTER_R818_RENDERER}"
ROTATION="${FLUTTER_R818_ROTATION}"
RUNNER="${FLUTTER_R818_RUNNER:-${RUNTIME_ROOT}/bin/flutter_${RENDERER}}"

if [ "$#" -gt 0 ]; then
  case "$1" in
    /*) APP_ROOT="$1" ;;
    *) APP_ROOT="${RUNTIME_ROOT}/apps/$1" ;;
  esac
elif [ -n "${FLUTTER_BOARD_APP_ROOT}" ]; then
  APP_ROOT="${FLUTTER_BOARD_APP_ROOT}"
else
  APP_NAME="${FLUTTER_BOARD_APP_NAME:-${DEFAULT_APP_NAME}}"
  APP_ROOT="${RUNTIME_ROOT}/apps/${APP_NAME}"
fi

APP_CONFIG_ROOT="${APP_ROOT}/config"
BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT}"

export FLUTTER_RUNTIME_ROOT="${RUNTIME_ROOT}"
export LD_LIBRARY_PATH="${RUNTIME_ROOT}/lib:/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LANG="${LANG:-en_US.UTF-8}"

mkdir -p "${APP_CONFIG_ROOT}" "${BOARD_CONFIG_ROOT}"
chmod 0777 -R "${APP_CONFIG_ROOT}" "${BOARD_CONFIG_ROOT}"

if [ "${ROTATION}" = "0" ]; then
  exec "${RUNNER}" "${APP_ROOT}"
fi
exec "${RUNNER}" -r "${ROTATION}" "${APP_ROOT}"
