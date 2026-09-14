@echo off
setlocal

echo ========================================
echo   4CP Modbus RTU Simulator Test Launcher
echo   Protocol v1.21
echo ========================================
echo.
echo Connecting: COM10 (Simulator) <-> COM5 (Client)
echo.
echo Make sure the two USB adapters are cross-wired:
echo   COM10 TX -> COM5 RX
echo   COM10 RX -> COM5 TX
echo   COM10 GND -> COM5 GND
echo.
echo Press Ctrl+C in simulator window to stop
echo ========================================
echo.

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "SIM_PATH=%SCRIPT_DIR%build\4CP_Simulator.exe"

echo Starting simulator on COM10...
echo Simulator path: %SIM_PATH%
echo Configuration: 9600 baud, Address 0xD1, Protocol v1.21
echo.

start "4CP_Simulator" "%SIM_PATH%" -p COM10 -b 9600 -a 0xD1

echo Waiting for simulator to initialize...
timeout /t 3 /nobreak >nul

echo.
echo Starting Modbus RTU test client on COM5...
echo.

py test_modbus_rtu.py COM5

echo.
echo ========================================
echo Test complete. Close simulator window when done.
echo ========================================
pause
