#!/bin/sh

# ===== 用户配置区：新主机只需优先检查/修改这里 =====
FLUTTER337_SDK_PATH="${FLUTTER337_SDK_PATH:-/opt/flutter_3.3.7}"
FLUTTER_R528_RUNTIME_ROOT="${FLUTTER_R528_RUNTIME_ROOT:-/opt/flutter-runtime-r528}"
FLUTTER_R528_GEN_SNAPSHOT="${FLUTTER_R528_GEN_SNAPSHOT:-${FLUTTER_R528_RUNTIME_ROOT}/tools/gen_snapshot}"
FLUTTER_R528_BOARD_RUNTIME_ROOT="${FLUTTER_R528_BOARD_RUNTIME_ROOT:-/arm-flutter-3.3.7-r528}"
# R528 App 的可写配置目录；该值会在编译时写入 App。
FLUTTER_BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT:-/mnt/UDISK/app/config}"
# 配置部署契约：output/config/ 是消费转移输入；通用 App 推送后必须把内容转移到 FLUTTER_BOARD_CONFIG_ROOT。
# 转移完成后按本 App 策略清空 App 内部配置内容，并保留空 config/ 目录。
# ===== 用户配置区结束；下面是构建逻辑 =====

# Flutter App 的 R528 ARMv7 AOT 构建；公共 Runtime 与各 App 输出相互独立。
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_NAME="${FLUTTER_BOARD_APP_NAME:-${PROJECT_ROOT##*/}}"
RUNTIME_ROOT="${FLUTTER_R528_RUNTIME_ROOT}"
GEN_SNAPSHOT="${FLUTTER_R528_GEN_SNAPSHOT}"
BUILD_ROOT="${PROJECT_ROOT}/.r528-build"
ASSET_DIR="${BUILD_ROOT}/flutter_assets"
DILL_DIR="${BUILD_ROOT}/dill"
OUTPUT_ROOT="${PROJECT_ROOT}/output"
OUTPUT_CANDIDATE="${PROJECT_ROOT}/.output-candidate.$$"
BOARD_CONFIG_ROOT="${FLUTTER_BOARD_CONFIG_ROOT}"

fail() {
  printf 'R528 编译失败：%s\n' "$*" >&2
  exit 1
}

[ -n "${FLUTTER337_SDK_PATH}" ] || fail "请设置 FLUTTER337_SDK_PATH，指向 Linux x86_64 Flutter 3.3.7 SDK"
[ -n "${RUNTIME_ROOT}" ] || fail "请设置 FLUTTER_R528_RUNTIME_ROOT，指向含 tools/gen_snapshot 的 R528 Runtime"
[ "$(uname -s)" = "Linux" ] || fail "必须在 Linux x86_64 构建机执行"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "当前构建机不是 x86_64" ;;
esac
[ -x "${FLUTTER337_SDK_PATH}/bin/flutter" ] || fail "缺少 Flutter SDK：${FLUTTER337_SDK_PATH}"
[ "$(cat "${FLUTTER337_SDK_PATH}/version")" = "3.3.7" ] || fail "Flutter SDK 必须是 3.3.7"
[ -x "${GEN_SNAPSHOT}" ] || fail "缺少 R528 ARMv7 gen_snapshot：${GEN_SNAPSHOT}"
[ -f "${PROJECT_ROOT}/pubspec.yaml" ] || fail "缺少 pubspec.yaml"
[ -f "${PROJECT_ROOT}/lib/main.dart" ] || fail "缺少 lib/main.dart"
mkdir -p "${PROJECT_ROOT}/config"

PACKAGE_NAME="$(awk -F: '/^name:[[:space:]]*/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "${PROJECT_ROOT}/pubspec.yaml")"
[ -n "${PACKAGE_NAME}" ] || fail "无法读取 pubspec.yaml 中的包名"
ENTRYPOINT="package:${PACKAGE_NAME}/main.dart"

cleanup_candidate() {
  rm -rf "${OUTPUT_CANDIDATE}"
}
trap cleanup_candidate EXIT HUP INT TERM

if [ -z "${PUB_CACHE:-}" ] && [ -d "${PROJECT_ROOT}/third_party/pub-cache" ]; then
  PUB_CACHE="${PROJECT_ROOT}/third_party/pub-cache"
fi
export PUB_CACHE="${PUB_CACHE:-${HOME}/.pub-cache}"
export PUB_HOSTED_URL="https://pub.dartlang.org"
# 防止构建过程意外访问网络；离线缓存不完整时立即失败。
export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:9"
export FLUTTER_SUPPRESS_ANALYTICS=true

cd "${PROJECT_ROOT}"
"${FLUTTER337_SDK_PATH}/bin/flutter" pub get --offline

rm -rf "${BUILD_ROOT}"
mkdir -p "${ASSET_DIR}" "${DILL_DIR}" "${OUTPUT_CANDIDATE}/flutter_assets"

"${FLUTTER337_SDK_PATH}/bin/flutter" build bundle --no-pub \
  --dart-define="R528_FORCE_720_SQUARE=true" \
  --dart-define="DASHBOARD_CONFIG_ROOT=${BOARD_CONFIG_ROOT}" \
  --asset-dir="${ASSET_DIR}"

"${FLUTTER337_SDK_PATH}/bin/dart" \
  --disable-dart-dev \
  "${FLUTTER337_SDK_PATH}/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot" \
  --sdk-root "${FLUTTER337_SDK_PATH}/bin/cache/artifacts/engine/common/flutter_patched_sdk" \
  --target=flutter \
  --no-print-incremental-dependencies \
  -Ddart.vm.profile=false \
  -Ddart.vm.product=true \
  -DR528_FORCE_720_SQUARE=true \
  -D"DASHBOARD_CONFIG_ROOT=${BOARD_CONFIG_ROOT}" \
  --aot \
  --tfa \
  --packages "${PROJECT_ROOT}/.dart_tool/package_config.json" \
  --output-dill "${DILL_DIR}/app.dill" \
  --depfile "${DILL_DIR}/kernel_snapshot.d" \
  "${ENTRYPOINT}"

"${GEN_SNAPSHOT}" \
  --deterministic \
  --snapshot_kind=app-aot-elf \
  --elf="${OUTPUT_CANDIDATE}/libapp.so" \
  --strip \
  "${DILL_DIR}/app.dill"

cp -R "${ASSET_DIR}/." "${OUTPUT_CANDIDATE}/flutter_assets/"
cp -R "${PROJECT_ROOT}/config" "${OUTPUT_CANDIDATE}/config"

file "${OUTPUT_CANDIDATE}/libapp.so" | grep -q 'ELF 32-bit.*ARM.*EABI5' || \
  fail "libapp.so 不是 ARM EABI5"

(
  cd "${OUTPUT_CANDIDATE}"
  # config/ 内容部署到板端外置可写目录；App 安装目录仍须保留空 config/。
  # 配置内容不属于 App 安装目录校验范围。
  find . -type f ! -name MD5SUMS ! -path './config/*' -print0 | sort -z | xargs -0 md5sum >MD5SUMS
  md5sum -c MD5SUMS >/dev/null
)

rm -rf "${OUTPUT_ROOT}"
mv "${OUTPUT_CANDIDATE}" "${OUTPUT_ROOT}"
rm -rf "${BUILD_ROOT}"
trap - EXIT HUP INT TERM

printf 'R528 Flutter App 编译成功：%s\n' "${OUTPUT_ROOT}"
printf 'Package：%s\n' "${PACKAGE_NAME}"
printf '板端配置目录：%s\n' "${FLUTTER_BOARD_CONFIG_ROOT}"
file "${OUTPUT_ROOT}/libapp.so"
