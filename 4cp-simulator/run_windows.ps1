param(
    [ValidateSet("release", "debug")]
    [string]$Mode = "release"
)

# -----------------------------------------------------------------------------
# 用户配置区：模拟器串口参数，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
$SerialPort = if ($env:FOURCP_SERIAL_PORT) { $env:FOURCP_SERIAL_PORT } else { "COM5" }
$BaudRate = if ($env:FOURCP_BAUD_RATE) { $env:FOURCP_BAUD_RATE } else { "9600" }
$DeviceAddress = if ($env:FOURCP_DEVICE_ADDRESS) { $env:FOURCP_DEVICE_ADDRESS } else { "0xD1" }
# -----------------------------------------------------------------------------

# 运行 build_windows.bat 已生成的 Windows PC 模拟器。
# 此处配置只用于本次启动，不修改源码或编译产物。

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDirectory = Join-Path $Root "logs"
$LogFile = Join-Path $LogDirectory "run_windows.log"
$OutputMode = if ($Mode -eq "release") { "Release" } else { "Debug" }
$BinaryName = "4CP_Simulator"
$Executable = Join-Path $Root "build\windows\$OutputMode\$BinaryName.exe"

if (!(Test-Path $Executable)) {
    throw "Missing build output. Run: build_windows.bat $Mode"
}
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

Write-Host "Starting: $Executable"
Write-Host "Serial port: $SerialPort"
Write-Host "Baud rate: $BaudRate"
Write-Host "Device address: $DeviceAddress"
Write-Host "Log file: $LogFile"

Push-Location (Split-Path -Parent $Executable)
try {
    & $Executable -p $SerialPort -b $BaudRate -a $DeviceAddress `
        -s "modbus-slave-response" 2>&1 | `
        Tee-Object -FilePath $LogFile -Append
    $ExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $ExitCode
