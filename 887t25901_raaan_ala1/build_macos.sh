#!/bin/sh

# Flutter App macOS 统一构建入口。
# 固定使用工程外的 Flutter 3.3.7 和其 JDK 11 环境脚本。

# -----------------------------------------------------------------------------
# 用户配置区：首次使用只需要修改下面这一行
# -----------------------------------------------------------------------------

# Flutter 3.3.7 SDK 的绝对路径，目录内必须有 use_jdk11_flutter337.sh。
FLUTTER337_SDK_PATH="/Users/as/Desktop/docu/workspace/flutter_3.3.7"
# macOS 配置目录可在执行前通过 FLUTTER_BOARD_CONFIG_ROOT 覆盖。

# -----------------------------------------------------------------------------
# 用户配置区结束：下方通常不需要修改
# -----------------------------------------------------------------------------

set -eu

# CocoaPods/Ruby 在 C、POSIX 等 ASCII locale 下无法正规化工程路径。
# 构建入口固定为 macOS 自带的 UTF-8 locale，避免受用户终端语言设置影响。
LANG="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
export LANG LC_ALL

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-$ROOT_DIR/config}"
APP_INFO_CONFIG="$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig"
FLUTTER337_SDK="${FLUTTER337_SDK:-$FLUTTER337_SDK_PATH}"
BUNDLED_PUB_CACHE="$ROOT_DIR/third_party/pub-cache"
if [ -n "${FLUTTER337_PUB_CACHE:-}" ]; then
  PUB_CACHE_DIR="$FLUTTER337_PUB_CACHE"
elif [ -d "$BUNDLED_PUB_CACHE/hosted" ]; then
  PUB_CACHE_DIR="$BUNDLED_PUB_CACHE"
else
  PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
fi
OFFLINE="${FLUTTER337_OFFLINE:-1}"
MODE="${1:-release}"

usage() {
  cat <<'EOF'
用法：
  ./build_macos.sh [release|debug]

示例：
  # 首次使用先修改本脚本顶部的 FLUTTER337_SDK_PATH
  ./build_macos.sh
  ./build_macos.sh debug
  # 高级用法：临时覆盖脚本顶部配置
  FLUTTER337_SDK=/path/to/flutter_3.3.7 ./build_macos.sh release
  FLUTTER337_PUB_CACHE=/path/to/pub-cache ./build_macos.sh release
  FLUTTER337_OFFLINE=0 ./build_macos.sh debug
  FLUTTER_BOARD_CONFIG_ROOT=/writable/config ./build_macos.sh debug
EOF
}

case "$MODE" in
  release)
    PRODUCT_MODE_DIR="Release"
    ;;
  debug)
    PRODUCT_MODE_DIR="Debug"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "错误：不支持的构建模式：$MODE" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
  echo "错误：此脚本只用于 macOS 本机构建。" >&2
  exit 1
fi

case "$FLUTTER337_SDK" in
  /*) ;;
  *)
    echo "错误：Flutter SDK 必须使用绝对路径。" >&2
    echo "请打开 build_macos.sh，修改顶部的 FLUTTER337_SDK_PATH。" >&2
    echo "当前配置：$FLUTTER337_SDK" >&2
    exit 1
    ;;
esac

FLUTTER337_SDK="$(CDPATH= cd -- "$FLUTTER337_SDK" 2>/dev/null && pwd -P)" || {
  echo "错误：找不到 Flutter 3.3.7 SDK：$FLUTTER337_SDK" >&2
  echo "请打开 build_macos.sh，修改顶部的 FLUTTER337_SDK_PATH。" >&2
  exit 1
}
FLUTTER_ENV_SCRIPT="$FLUTTER337_SDK/use_jdk11_flutter337.sh"

if [ ! -f "$FLUTTER_ENV_SCRIPT" ]; then
  echo "错误：找不到 Flutter/JDK 11 环境脚本：$FLUTTER_ENV_SCRIPT" >&2
  echo "请确认 build_macos.sh 顶部配置的是 Flutter 3.3.7 SDK 目录。" >&2
  exit 1
fi
if [ ! -d "$PUB_CACHE_DIR/hosted" ]; then
  echo "错误：找不到 Pub 缓存：$PUB_CACHE_DIR" >&2
  echo "可通过 FLUTTER337_PUB_CACHE=/path/to/cache 指定。" >&2
  exit 1
fi
command -v xcodebuild >/dev/null 2>&1 || {
  echo "错误：缺少 xcodebuild，请先安装并选择 Xcode。" >&2
  exit 1
}
command -v pod >/dev/null 2>&1 || {
  echo "错误：缺少 CocoaPods 的 pod 命令。" >&2
  exit 1
}
[ -f "$APP_INFO_CONFIG" ] || {
  echo "错误：缺少 macOS App 配置：$APP_INFO_CONFIG" >&2
  exit 1
}
PRODUCT_NAME="$(awk -F= '/^[[:space:]]*PRODUCT_NAME[[:space:]]*=/ {sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]\r]+$/, ""); print; exit}' "$APP_INFO_CONFIG")"
[ -n "$PRODUCT_NAME" ] || {
  echo "错误：无法从 $APP_INFO_CONFIG 读取 PRODUCT_NAME。" >&2
  exit 1
}
mkdir -p "$FLUTTER_BOARD_CONFIG_ROOT"

echo "$PRODUCT_NAME macOS 构建"
echo "项目目录：$ROOT_DIR"
echo "Flutter SDK：$FLUTTER337_SDK"
echo "Pub 缓存：$PUB_CACHE_DIR"
echo "构建模式：$MODE"
echo "离线解析：$OFFLINE"
echo "配置目录：$FLUTTER_BOARD_CONFIG_ROOT"

(
  cd "$FLUTTER337_SDK"
  . "$FLUTTER_ENV_SCRIPT"
  cd "$ROOT_DIR"

  PUB_CACHE="$PUB_CACHE_DIR"
  export PUB_CACHE

  case "$OFFLINE" in
    1|true|yes)
      # pubspec.lock 和随包缓存均以 pub.dartlang.org 为缓存键；显式固定，
      # 避免调用者环境中的镜像地址导致 --offline 看不到已经随包提供的依赖。
      PUB_HOSTED_URL="https://pub.dartlang.org"
      # 离线模式不允许 Flutter 临时下载 Engine；缺文件时应立即失败并给出真因。
      FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:9"
      export PUB_HOSTED_URL FLUTTER_STORAGE_BASE_URL
      flutter337 pub get --offline
      ;;
    0|false|no)
      flutter337 pub get
      ;;
    *)
      echo "错误：FLUTTER337_OFFLINE 只支持 1/0、true/false 或 yes/no。" >&2
      exit 2
      ;;
  esac

  flutter337 build macos --no-pub "--$MODE" \
    "--dart-define=DASHBOARD_CONFIG_ROOT=$FLUTTER_BOARD_CONFIG_ROOT"
)

APP="$ROOT_DIR/build/macos/Build/Products/$PRODUCT_MODE_DIR/$PRODUCT_NAME.app"
EXECUTABLE="$APP/Contents/MacOS/$PRODUCT_NAME"
if [ ! -x "$EXECUTABLE" ]; then
  echo "错误：构建结束，但未找到可执行产物：$EXECUTABLE" >&2
  exit 1
fi

echo
echo "构建完成：$APP"
