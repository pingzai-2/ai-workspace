#!/bin/sh

# ===== 用户配置区：新主机只需优先检查/修改这里 =====
# 先在 R528 SDK 根目录执行对应脚本导出环境。
BEIANG_R528_STAGING="${BEIANG_R528_STAGING:-}"
BEIANG_BUILD_JOBS="${BEIANG_BUILD_JOBS:-}"
# ===== 用户配置区结束；下面是构建逻辑 =====

# BeiAng8Panel 后端的 R528 ARMv7 构建；工程与 SDK 目录相互独立。
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BUILD_ROOT="${PROJECT_ROOT}/.r528-build"
DEPS_BUILD_DIR="${BUILD_ROOT}/deps-build"
DEPS_PREFIX="${BUILD_ROOT}/deps"
APP_BUILD_DIR="${BUILD_ROOT}/app"
TOOLCHAIN_FILE="${BUILD_ROOT}/r528-toolchain.cmake"
OUTPUT_ROOT="${PROJECT_ROOT}/output"
OUTPUT_CANDIDATE="${PROJECT_ROOT}/.output-candidate.$$"
APP_EXECUTABLE="${OUTPUT_CANDIDATE}/BeiAng8Panel"

fail() {
  printf 'R528 编译失败：%s\n' "$*" >&2
  exit 1
}

[ "$(uname -s)" = "Linux" ] || fail "必须在 Linux x86_64 构建机执行"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "当前构建机不是 x86_64" ;;
esac
[ -n "${FLUTTER_R528_SDK_ROOT:-}" ] || fail "请先导入 R528 SDK 环境"
[ -n "${CROSS_COMPILE:-}" ] || fail "R528 SDK 环境没有导出 CROSS_COMPILE"

CC_BIN="$(command -v "${CROSS_COMPILE}gcc" 2>/dev/null || true)"
CXX_BIN="$(command -v "${CROSS_COMPILE}g++" 2>/dev/null || true)"
AR_BIN="$(command -v "${CROSS_COMPILE}ar" 2>/dev/null || true)"
RANLIB_BIN="$(command -v "${CROSS_COMPILE}ranlib" 2>/dev/null || true)"
NM_BIN="$(command -v "${CROSS_COMPILE}nm" 2>/dev/null || true)"
STRIP_BIN="$(command -v "${CROSS_COMPILE}strip" 2>/dev/null || true)"
READELF_BIN="$(command -v "${CROSS_COMPILE}readelf" 2>/dev/null || true)"
for executable in "$CC_BIN" "$CXX_BIN" "$AR_BIN" "$RANLIB_BIN" "$NM_BIN" "$STRIP_BIN" "$READELF_BIN"; do
  [ -n "$executable" ] && [ -x "$executable" ] || fail "R528 交叉工具链不完整"
done
[ "$($CC_BIN -dumpmachine)" = "arm-openwrt-linux-gnueabi" ] || fail "当前环境不是 R528 工具链"

if [ -n "$BEIANG_R528_STAGING" ]; then
  STAGING_DIR="$BEIANG_R528_STAGING"
else
  STAGING_DIR=
  staging_count=0
  for candidate in "${FLUTTER_R528_SDK_ROOT}"/out/*/staging_dir; do
    [ -d "$candidate" ] || continue
    if [ -f "$candidate/target/usr/include/curl/curl.h" ] && \
       { [ -e "$candidate/target/usr/lib/libcurl.so" ] || [ -f "$candidate/target/usr/lib/libcurl.a" ]; }; then
      STAGING_DIR="$candidate"
      staging_count=$((staging_count + 1))
    fi
  done
  [ "$staging_count" -eq 1 ] || fail "SDK out 中可用 staging 数量不是 1，请设置 BEIANG_R528_STAGING"
fi

TOOLCHAIN_BIN="$(CDPATH= cd -- "$(dirname -- "$CC_BIN")" && pwd)"
TOOLCHAIN_ROOT="$(CDPATH= cd -- "$TOOLCHAIN_BIN/.." && pwd)"
TARGET_SYSROOT="${TOOLCHAIN_ROOT}/arm-openwrt-linux-gnueabi"
[ -d "$TARGET_SYSROOT" ] || fail "R528 sysroot 不存在：$TARGET_SYSROOT"

if [ -x /usr/local/bin/cmake ]; then
  CMAKE_CMD=/usr/local/bin/cmake
else
  CMAKE_CMD=cmake
fi
for command_name in "$CMAKE_CMD" make file md5sum autoreconf; do
  command -v "$command_name" >/dev/null 2>&1 || [ -x "$command_name" ] || fail "缺少 $command_name"
done
if [ -z "$BEIANG_BUILD_JOBS" ]; then
  BEIANG_BUILD_JOBS="$(nproc)"
fi

cleanup_candidate() {
  rm -rf "${OUTPUT_CANDIDATE}"
}
trap cleanup_candidate EXIT HUP INT TERM

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}" "${OUTPUT_CANDIDATE}"

cat >"${TOOLCHAIN_FILE}" <<'EOF'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER "$ENV{CC}")
set(CMAKE_CXX_COMPILER "$ENV{CXX}")
set(CMAKE_AR "$ENV{AR}")
set(CMAKE_NM "$ENV{NM}")
set(CMAKE_RANLIB "$ENV{RANLIB}")
set(CMAKE_STRIP "$ENV{STRIP}")
set(CMAKE_SYSROOT "$ENV{BEIANG_R528_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "$ENV{BEIANG_R528_SYSROOT}" "$ENV{STAGING_DIR}/target")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
EOF

ARMV7_FLAGS="-march=armv7-a -mtune=cortex-a7 -mfpu=neon -mfloat-abi=hard"
export CC="$CC_BIN"
export CXX="$CXX_BIN"
export AR="$AR_BIN"
export RANLIB="$RANLIB_BIN"
export NM="$NM_BIN"
export STRIP="$STRIP_BIN"
export STAGING_DIR
export CFLAGS="${CFLAGS:-} $ARMV7_FLAGS"
export CXXFLAGS="${CXXFLAGS:-} $ARMV7_FLAGS"
export BEIANG_R528_SYSROOT="$TARGET_SYSROOT"
export BEIANG_HOST_TRIPLET=arm-openwrt-linux-gnueabi
export BEIANG_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
export BEIANG_BUILD_JOBS CMAKE_CMD

"${PROJECT_ROOT}/scripts/verify_text_eol.sh"
"${PROJECT_ROOT}/scripts/build_offline_deps.sh" arm64 "${DEPS_BUILD_DIR}" "${DEPS_PREFIX}"

"${CMAKE_CMD}" -S "${PROJECT_ROOT}" -B "${APP_BUILD_DIR}" \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_NATIVE=OFF \
  -DENABLE_HTTP_SERVER=ON \
  -DBUILD_TESTING=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_spdlog=ON \
  -DSTAGING_DIR="${STAGING_DIR}" \
  -DBEIANG_DEPS_PREFIX="${DEPS_PREFIX}" \
  -DBEIANG_OUTPUT_DIR="${OUTPUT_CANDIDATE}"
"${CMAKE_CMD}" --build "${APP_BUILD_DIR}" --parallel "${BEIANG_BUILD_JOBS}"

[ -x "${APP_EXECUTABLE}" ] || fail "产物不存在：${APP_EXECUTABLE}"
cp -f "${PROJECT_ROOT}/config/FactoryConfig.json" "${OUTPUT_CANDIDATE}/FactoryConfig.json"
cp -f "${PROJECT_ROOT}/config/FactoryConfig_2.json" "${OUTPUT_CANDIDATE}/FactoryConfig_2.json"
cp -f "${PROJECT_ROOT}/config/FactoryConfig_3.json" "${OUTPUT_CANDIDATE}/FactoryConfig_3.json"
cp -f "${PROJECT_ROOT}/config/FactoryConfig_4.json" "${OUTPUT_CANDIDATE}/FactoryConfig_4.json"
if [ -f "${PROJECT_ROOT}/LocationList/China-City-List-latest.csv" ]; then
  cp -f "${PROJECT_ROOT}/LocationList/China-City-List-latest.csv" "${OUTPUT_CANDIDATE}/China-City-List-latest.csv"
fi

file "${APP_EXECUTABLE}" | grep -q 'ELF 32-bit.*ARM.*EABI5' || fail "BeiAng8Panel 不是 ARM EABI5"
"${READELF_BIN}" -l "${APP_EXECUTABLE}" | grep -q '/lib/ld-linux-armhf.so.3' || fail "动态加载器不匹配 R528"
"${READELF_BIN}" -A "${APP_EXECUTABLE}" | grep -q 'Tag_ABI_VFP_args: VFP registers' || fail "BeiAng8Panel 不是 ARM hard-float ABI"

(
  cd "${OUTPUT_CANDIDATE}"
  find . -type f ! -name MD5SUMS -print0 | sort -z | xargs -0 md5sum >MD5SUMS
  md5sum -c MD5SUMS >/dev/null
)

rm -rf "${OUTPUT_ROOT}"
mv "${OUTPUT_CANDIDATE}" "${OUTPUT_ROOT}"
rm -rf "${BUILD_ROOT}"
trap - EXIT HUP INT TERM

printf 'R528 BeiAng8Panel 编译成功：%s\n' "${OUTPUT_ROOT}"
file "${OUTPUT_ROOT}/BeiAng8Panel"
