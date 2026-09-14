@echo off
chcp 65001 >nul 2>&1

echo ========================================
echo   4CP Simulator - Simple Build
echo ========================================
echo.

:: Clean build directory
if exist build rmdir /s /q build

:: Create build directory
mkdir build
cd build

:: Run CMake (auto-detect generator)
echo Running CMake configuration...
cmake ..
if %errorlevel% neq 0 (
    echo.
    echo CMake configuration failed!
    echo.
    echo Please ensure you have one of the following installed:
    echo   - Visual Studio 2022 or 2019
    echo   - Build Tools for Visual Studio
    echo.
    pause
    exit /b 1
)

:: Build
echo.
echo Building...
cmake --build . --config Release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

cd ..

:: Visual Studio is multi-config and writes Release\; Ninja/MinGW is
:: single-config and writes directly under build\. Accept either CMake layout.
set "OUTPUT_DIR=build\Release"
if exist "build\4CP_Simulator.exe" set "OUTPUT_DIR=build"

if not exist "%OUTPUT_DIR%\4CP_Simulator.exe" (
    echo Build output not found: %OUTPUT_DIR%\4CP_Simulator.exe
    exit /b 1
)
if not exist "%OUTPUT_DIR%\modbus.dll" (
    echo Bundled libmodbus runtime not found: %OUTPUT_DIR%\modbus.dll
    exit /b 1
)

echo.
echo ========================================
echo   Build completed!
echo ========================================
echo.
echo Output: %OUTPUT_DIR%\4CP_Simulator.exe
echo Runtime: %OUTPUT_DIR%\modbus.dll
echo.
echo Run the simulator:
echo   .\%OUTPUT_DIR%\4CP_Simulator.exe -p COM10 -b 9600 -a 0xD1 -s modbus-slave-response
echo.
echo Options:
echo   -p ^<port^>     Serial port (default: COM1)
echo   -b ^<baudrate^> Baud rate (default: 9600)
echo   -a ^<addr^>     Device address (default: 209 / 0xD1)
echo   -s ^<type^>     Communication scheduler
echo.
pause
