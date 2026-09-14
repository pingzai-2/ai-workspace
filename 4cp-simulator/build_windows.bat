@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem 4CP Simulator Windows PC 本机构建入口。
rem Requires Visual Studio C++ Desktop tools and CMake; build stays offline.

rem ---------------------------------------------------------------------------
rem 用户配置区：按本机实际路径修改下面的绝对路径
rem ---------------------------------------------------------------------------
set "CMAKE_EXE_PATH=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "VS_BASE=C:\Program Files (x86)"

set "VSVARS=%VS_BASE%\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
rem ---------------------------------------------------------------------------

for %%I in ("%~dp0.") do set "ROOT_DIR=%%~fI"
set "BUILD_DIR=%ROOT_DIR%\build\windows"
set "BINARY_NAME=4CP_Simulator"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=release"

if /I "%MODE%"=="-h" goto usage_ok
if /I "%MODE%"=="--help" goto usage_ok
if /I not "%MODE%"=="release" if /I not "%MODE%"=="debug" goto bad_mode
if /I "%MODE%"=="release" set "OUTPUT_MODE=Release"
if /I "%MODE%"=="debug" set "OUTPUT_MODE=Debug"

if not exist "%CMAKE_EXE_PATH%" goto cmake_missing
call :_add_path "%CMAKE_EXE_PATH%"
if not exist "%VSVARS%" goto vsvars_missing

echo %BINARY_NAME% Windows PC build: %MODE% offline

set "TMPBAT=%ROOT_DIR%\_build_tmp.bat"
del "%TMPBAT%" 2>nul
> "%TMPBAT%" echo @echo off
>> "%TMPBAT%" echo call "!VSVARS!" x64 ^>nul
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] VS env failed ^& exit /b 1^)
>> "%TMPBAT%" echo cd /d "!ROOT_DIR!"
>> "%TMPBAT%" echo "!CMAKE_EXE_PATH!" -S "!ROOT_DIR!" -B "!BUILD_DIR!" -G "Visual Studio 18 2026" -A x64
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] CMake configure failed ^& exit /b 1^)
>> "%TMPBAT%" echo "!CMAKE_EXE_PATH!" --build "!BUILD_DIR!" --config !OUTPUT_MODE! --parallel
>> "%TMPBAT%" echo if errorlevel 1 ^(echo [ERROR] Build failed ^& exit /b 1^)
>> "%TMPBAT%" echo exit /b 0

pushd "%ROOT_DIR%"
cmd /c "%TMPBAT%"
set "BUILD_ERR=%ERRORLEVEL%"
del "%TMPBAT%" 2>nul
popd
if %BUILD_ERR% neq 0 exit /b %BUILD_ERR%

if not exist "%BUILD_DIR%\%OUTPUT_MODE%\%BINARY_NAME%.exe" (
  echo [ERROR] Build output not found.
  exit /b 1
)
if not exist "%BUILD_DIR%\%OUTPUT_MODE%\modbus.dll" (
  echo [ERROR] Bundled libmodbus runtime not found.
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
