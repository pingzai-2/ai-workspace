param(
    [ValidateSet("release", "debug")]
    [string]$Mode = "release"
)

# -----------------------------------------------------------------------------
# 用户配置区：Windows PC 运行窗口尺寸，可在执行前用同名环境变量覆盖
# -----------------------------------------------------------------------------
$WindowWidth = if ($env:FLUTTER_WINDOW_WIDTH) { $env:FLUTTER_WINDOW_WIDTH } else { "800" }
$WindowHeight = if ($env:FLUTTER_WINDOW_HEIGHT) { $env:FLUTTER_WINDOW_HEIGHT } else { "500" }
# -----------------------------------------------------------------------------

# 运行 build_windows.bat 已生成的 Windows PC 应用。
# 此处配置只用于运行前准备和显示，不能改变已编译 App；必须与 build_windows.bat 的编译值一致。

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigRoot = if ($env:FLUTTER_BOARD_CONFIG_ROOT) {
    $env:FLUTTER_BOARD_CONFIG_ROOT
} else {
    Join-Path $Root "config"
}
$OutputMode = if ($Mode -eq "release") { "Release" } else { "Debug" }
$CMakeLists = Join-Path $Root "windows\CMakeLists.txt"
$BinaryMatch = Select-String -Path $CMakeLists -Pattern 'set\(BINARY_NAME\s+"([^"]+)"\)' | Select-Object -First 1
if ($null -eq $BinaryMatch) {
    throw "Cannot read BINARY_NAME from $CMakeLists"
}
$BinaryName = $BinaryMatch.Matches[0].Groups[1].Value
$Executable = Join-Path $Root "build\windows\runner\$OutputMode\$BinaryName.exe"

if (!(Test-Path $Executable)) {
    throw "Missing build output. Run: build_windows.bat $Mode"
}
New-Item -ItemType Directory -Force -Path $ConfigRoot | Out-Null
$env:FLUTTER_WINDOW_WIDTH = $WindowWidth
$env:FLUTTER_WINDOW_HEIGHT = $WindowHeight

Write-Host "Starting: $Executable"
Write-Host "Config directory: $ConfigRoot"
Write-Host "Window size: ${WindowWidth}x${WindowHeight}"

Start-Process -FilePath $Executable `
    -WorkingDirectory (Split-Path -Parent $Executable) -Wait
