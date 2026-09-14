@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Flutter 3.3.7 Windows PC 本机构建入口。
rem 需要 Visual Studio C++ 桌面工具链、CMake 和工程离线 Pub 缓存。

rem ---------------------------------------------------------------------------
rem 用户配置区：按本机实际路径修改下面的绝对路径
rem ---------------------------------------------------------------------------
set "FLUTTER337_SDK_PATH=D:\flutter_3.3.7"
set "CMAKE_EXE_PATH=C:\Program Files\CMake\bin\cmake.exe"
set "VS_BASE=D:\Program Files (x86)"
rem Windows PC 配置目录可在执行前通过 FLUTTER_BOARD_CONFIG_ROOT 覆盖。

set "VSVARS=%VS_BASE%\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
rem ---------------------------------------------------------------------------

set "ROOT_DIR=%~dp0"
if not defined FLUTTER_BOARD_CONFIG_ROOT set "FLUTTER_BOARD_CONFIG_ROOT=%ROOT_DIR%config"
set "BINARY_NAME="
set "OFFLINE_PUB_CACHE=%ROOT_DIR%third_party\pub-cache"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=release"

if /I "%MODE%"=="-h" goto usage_ok
if /I "%MODE%"=="--help" goto usage_ok
if /I not "%MODE%"=="release" if /I not "%MODE%"=="debug" goto bad_mode

for /f tokens^=2^ delims^=^" %%A in ('findstr /B /C:"set(BINARY_NAME " "%ROOT_DIR%windows\CMakeLists.txt"') do set "BINARY_NAME=%%A"
if not defined BINARY_NAME (
  echo [ERROR] Cannot read BINARY_NAME from windows\CMakeLists.txt.
  exit /b 1
)
if not exist "%FLUTTER_BOARD_CONFIG_ROOT%" mkdir "%FLUTTER_BOARD_CONFIG_ROOT%"
if errorlevel 1 (
  echo [ERROR] Cannot create config directory: %FLUTTER_BOARD_CONFIG_ROOT%
  exit /b 1
)

if not exist "%FLUTTER337_SDK_PATH%\bin\flutter.bat" (
  echo [ERROR] Flutter 3.3.7 not found: %FLUTTER337_SDK_PATH%
  echo Edit FLUTTER337_SDK_PATH at the top of build_windows.bat.
  exit /b 1
)
set /p FLUTTER_VERSION=<"%FLUTTER337_SDK_PATH%\version"
if not "%FLUTTER_VERSION%"=="3.3.7" (
  echo [ERROR] Flutter SDK version must be 3.3.7, current: %FLUTTER_VERSION%
  exit /b 1
)
if not exist "%CMAKE_EXE_PATH%" goto cmake_missing
call :_add_path "%CMAKE_EXE_PATH%"
if not exist "%VSVARS%" goto vsvars_missing
if not exist "%OFFLINE_PUB_CACHE%\hosted\pub.dartlang.org" (
  echo [ERROR] Offline Pub cache not found: %OFFLINE_PUB_CACHE%
  exit /b 1
)
set "PUB_CACHE=%OFFLINE_PUB_CACHE%"
set "PUB_HOSTED_URL=https://pub.dartlang.org"
set "FLUTTER_STORAGE_BASE_URL=http://127.0.0.1:9"
set "FLUTTER_SUPPRESS_ANALYTICS=true"

echo %BINARY_NAME% Windows PC build: %MODE% offline
echo Config directory: %FLUTTER_BOARD_CONFIG_ROOT%

set "TMPBAT=%ROOT_DIR%_build_tmp.bat"
del "%TMPBAT%" 2>nul
> "%TMPBAT%" echo @echo off
>> "%TMPBAT%" echo set "PUB_CACHE=!OFFLINE_PUB_CACHE!"
>> "%TMPBAT%" echo set "PUB_HOSTED_URL=https://pub.dartlang.org"
>> "%TMPBAT%" echo set "FLUTTER_STORAGE_BASE_URL=http://127.0.0.1:9"
>> "%TMPBAT%" echo set "FLUTTER_SUPPRESS_ANALYTICS=true"
>> "%TMPBAT%" echo call "!VSVARS!" x64 ^>nul
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] VS env failed ^& exit /b 1^)
>> "%TMPBAT%" echo cd /d "!ROOT_DIR!"
>> "%TMPBAT%" echo call "!FLUTTER337_SDK_PATH!\bin\flutter.bat" pub get --offline
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] pub get failed ^& exit /b 1^)
>> "%TMPBAT%" echo call "!FLUTTER337_SDK_PATH!\bin\flutter.bat" build windows --no-pub --!MODE! --dart-define=DASHBOARD_CONFIG_ROOT=!FLUTTER_BOARD_CONFIG_ROOT!
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] Build failed ^& exit /b 1^)
>> "%TMPBAT%" echo exit /b 0

pushd "%ROOT_DIR%"
cmd /c "%TMPBAT%"
set "BUILD_ERR=%ERRORLEVEL%"
del "%TMPBAT%" 2>nul
popd
if %BUILD_ERR% neq 0 exit /b %BUILD_ERR%

if /I "%MODE%"=="release" set "OUTPUT_MODE=Release"
if /I "%MODE%"=="debug" set "OUTPUT_MODE=Debug"
if not exist "%ROOT_DIR%build\windows\runner\%OUTPUT_MODE%\%BINARY_NAME%.exe" (
  echo [ERROR] Build output not found.
  exit /b 1
)
echo Build completed.
exit /b 0

:bad_mode
echo [ERROR] Mode must be release or debug: %MODE%
goto usage_fail

:usage_ok
call :usage
exit /b 0

:usage_fail
call :usage
exit /b 2

:cmake_missing
echo [ERROR] CMake not found: %CMAKE_EXE_PATH%
echo Edit CMAKE_EXE_PATH at the top of build_windows.bat.
exit /b 1

:_add_path
set "PATH=%~dp1;%PATH%"
exit /b

:vsvars_missing
echo [ERROR] VS vcvarsall not found: %VSVARS%
echo Edit VSVARS at the top of build_windows.bat.
exit /b 1

:usage
echo Usage: build_windows.bat [release^|debug]
echo First use: edit the absolute paths at the top of this file.
exit /b 0
