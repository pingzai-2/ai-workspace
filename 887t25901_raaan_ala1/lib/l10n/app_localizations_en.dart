import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get menuSettings => 'System Settings';

  @override
  String get menuMaintenance => 'Device Maintenance';

  @override
  String get menuEngineering => 'Installer Mode';

  @override
  String get settingsBackHint => '※ 返回即自动保存设置';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get networkSettings => 'Network Settings';

  @override
  String get timerSettings => '定时设置';

  @override
  String get systemInfo => 'System Info';

  @override
  String get timeFormat => 'Time Format';

  @override
  String get timeFormat24h => '24 小时';

  @override
  String get timeFormat12h => '12 小时';

  @override
  String get dateSetting => 'Date Settings';

  @override
  String get clockSetting => 'Clock Settings';

  @override
  String get languageSelection => 'Language';

  @override
  String get screenBrightness => 'Screen Brightness';

  @override
  String brightnessPercent(int value) {
    return '$value%';
  }

  @override
  String get priorityMetric => 'Primary Metric';

  @override
  String get aqiIndicator => 'AQI Indicator';

  @override
  String get indicatorLightBrightness => 'Indicator Brightness';

  @override
  String get indicatorLightBright => 'Bright';

  @override
  String get indicatorLightDark => 'Dim';

  @override
  String get presenceRadar => 'Presence Radar';

  @override
  String get screenOffTime => 'Screen Timeout';

  @override
  String screenOffSecondsValue(int seconds) {
    return '${seconds}s';
  }

  @override
  String get airQualityAutoDetection => 'Auto AQI Detection';

  @override
  String get metricTemperature => 'Temp';

  @override
  String get metricHumidity => 'RH';

  @override
  String get metricPm25 => 'PM2.5';

  @override
  String get metricCo2 => 'CO₂';

  @override
  String get metricFormaldehyde => 'HCHO';

  @override
  String get network => 'Network';

  @override
  String get myNetwork => 'My Networks';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get notConnected => '未连接';

  @override
  String get currentNetwork => 'Current Network';

  @override
  String get otherNetworks => 'Other Networks';

  @override
  String get connecting => '连接中';

  @override
  String get wifiConnectingPrefix => 'Connecting to ';

  @override
  String get wifiConnectingSuffix => ' ……';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get timer => 'Timer';

  @override
  String get timeRangeSetting => '时间段设置';

  @override
  String timerRangeValue(String start, String end) {
    return 'Timer On $start~$end';
  }

  @override
  String get repeatCycle => '重复周期';

  @override
  String get everyDay => 'Daily';

  @override
  String get monday => 'Mon';

  @override
  String get tuesday => 'Tue';

  @override
  String get wednesday => 'Wed';

  @override
  String get thursday => 'Thu';

  @override
  String get friday => 'Fri';

  @override
  String get saturday => 'Sat';

  @override
  String get sunday => 'Sun';

  @override
  String get version => 'Version';

  @override
  String get checkUpdate => 'Check Updates';

  @override
  String get update => 'Update';

  @override
  String get noUpdateMessage => '当前已是最新版本';

  @override
  String get systemUptimePrefix => '系统已运行 ';

  @override
  String get systemUptimeSuffix => ' 天';

  @override
  String get clockHourHand => 'Hr';

  @override
  String get clockMinuteHand => 'Min';

  @override
  String get clockSecondHand => 'Sec';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get brightness => '亮度';

  @override
  String get start => '开始';

  @override
  String get end => '结束';

  @override
  String get enterPassword => 'Enter Password';

  @override
  String get passwordError => '※  密码不正确，请重试';

  @override
  String get updateAvailableMessage => '有最新可用版本，更新预计耗时2小时，是否继续？';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updatingMessage => 'Do not power off during update. Device auto‑restarts after completion.';

  @override
  String get updateFailedMessage => 'Version update download failed. Please check your network connection or try again later.';

  @override
  String get exit => 'Exit';

  @override
  String get consumableStatus => 'Consumable Status';

  @override
  String get maintenance => 'Maintenance';

  @override
  String filterName(int index) {
    return 'Filter $index';
  }

  @override
  String get remainingPrefix => '余';

  @override
  String get dayUnit => '天';

  @override
  String get dueForMaintenance => 'Service';

  @override
  String get service => 'Service';

  @override
  String get callServiceProvider => '呼叫服务商';

  @override
  String get nextMaintenanceDate => 'Next Maintenance';

  @override
  String get maintenanceResetMessage => 'This will reset filter service interval. Continue?';

  @override
  String get back => 'Back';

  @override
  String get offline => 'Offline';

  @override
  String get space => 'Space';

  @override
  String get navHome => 'Home';

  @override
  String get navMain => 'Home';

  @override
  String get navSmart => 'Smart';

  @override
  String get navManual => 'Manual';

  @override
  String get navTrends => 'Trends';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSettingsAlt => 'Settings';

  @override
  String get backendOffline => '后端服务离线';

  @override
  String get backendStale => '设备数据陈旧';

  @override
  String get notificationCenter => 'Notifications';

  @override
  String get faultAlert => 'Fault Alert';

  @override
  String get noNotifications => 'No new notifications.';

  @override
  String get noFaults => '当前无故障！';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get deviceAirConditioner => 'A/C';

  @override
  String get deviceFloorHeat => 'Floor Heat';

  @override
  String get deviceFreshAir => 'Vent';

  @override
  String get deviceHumidifier => 'Hum Ctrl';

  @override
  String get devicePure => 'IEF';

  @override
  String get stateCooling => 'Cool';

  @override
  String get stateNotOn => 'Off';

  @override
  String get stateOn => 'On';

  @override
  String get freshAirModeInternalCirculation => 'Recirc';

  @override
  String get fanLevelHigh => 'High';

  @override
  String get iefStarting => 'IEF starting';

  @override
  String get quickPowerAll => 'Master ON/OFF';

  @override
  String get quickLeaveHome => 'Away Mode';

  @override
  String get floorIndoor => 'Indoor';

  @override
  String get floorAll => 'All';

  @override
  String get floorBasement1 => 'B1';

  @override
  String get floorBasement2 => 'B2';

  @override
  String get floor1 => '1st Floor';

  @override
  String get floor2 => '2nd Floor';

  @override
  String get floor3 => '3rd Floor';

  @override
  String get weatherSunny => 'Sunny';

  @override
  String get weatherClearNight => '晴夜';

  @override
  String get weatherMostlyClear => '晴间多云';

  @override
  String get weatherOvercast => 'Overcast';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherDrizzle => '毛毛雨';

  @override
  String get weatherMiddleRain => 'Mod Rain';

  @override
  String get weatherHeavyRain => 'Heavy Rain';

  @override
  String get weatherExtremeRain => 'Rainstorm';

  @override
  String get weatherMostlyClearRain => '晴间多云有雨';

  @override
  String get weatherThunderstorms => 'Thunder Showers';

  @override
  String get weatherDrizzleToMiddleRain => 'Light‑Mod Rain';

  @override
  String get weatherMiddleToHeavyRain => 'Mod‑Heavy Rain';

  @override
  String get weatherLightSnow => 'Light Snow';

  @override
  String get weatherModerateSnow => 'Mod Snow';

  @override
  String get weatherHeavySnow => 'Heavy Snow';

  @override
  String get weatherWindSnow => '风雪';

  @override
  String get weatherSleet => 'Sleet';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherHaze => 'Haze';

  @override
  String get weatherDust => 'Dust';

  @override
  String get weatherSandstorm => '扬沙';

  @override
  String get weatherWindy => 'Windy';

  @override
  String get weatherCyclone => 'Typhoon';

  @override
  String get weatherHail => 'Hail';

  @override
  String get weatherHeatWave => 'High Temp';

  @override
  String get weatherColdWave => 'Low Temp';

  @override
  String get weatherAlert => '天气预警';

  @override
  String get weatherBlizzard => 'Blizzard';

  @override
  String get weatherCodeOrange => '橙色预警';

  @override
  String get weatherCodeRed => '红色预警';

  @override
  String get smartStandard => 'Standard Mode';

  @override
  String get smartGuest => 'Guest Mode';

  @override
  String get smartDry => 'Dry Mode';

  @override
  String get smartHumid => 'Humid Mode';

  @override
  String get smartTravel => 'Vacation Mode';

  @override
  String smartModeActiveHint(String mode) {
    return '※ $mode is active.';
  }

  @override
  String get smartExitMessage => 'This will exit the current smart mode. Continue?';

  @override
  String get manualMode => 'Mode';

  @override
  String get manualFanSpeed => 'Fan Speed';

  @override
  String get manualDuration => 'Duration';

  @override
  String get manualHold => 'Hold';

  @override
  String get manualRoom => '房间';

  @override
  String get manualTimerOn => 'On Timer';

  @override
  String get manualTimerOff => 'Off Timer';

  @override
  String get manualRepeat => '循环';

  @override
  String get manualFreshAirMode => 'Vent Mode';

  @override
  String get manualFreshAirFanSpeed => 'Vent Fan Speed';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeHeating => 'Heat';

  @override
  String get modeFan => 'Fan';

  @override
  String get freshAirModeFullHeatExchange => 'HRV';

  @override
  String get repeatOnce => 'Once';

  @override
  String get repeatWeekdays => 'Weekdays';

  @override
  String get repeatOff => 'Off';

  @override
  String get timerNotSet => 'Timer  Not set';

  @override
  String timerSummaryValue(String start, String end, String repeat) {
    return 'Timer  $start-$end ($repeat)';
  }

  @override
  String runningDeviceCount(int count) {
    return '※ $count device(s) running';
  }

  @override
  String get manualWholeHomeFloorHeat => 'This will control whole‑home floor heat.';

  @override
  String get manualWholeHomeFreshAir => 'This will control whole‑home ventilation.';

  @override
  String get manualWholeHomeHumidity => '将控制全屋湿度';

  @override
  String get manualWholeHomePure => 'Whole‑home IEF is ON.';

  @override
  String get manualExitMessage => '该操作将会退出当前手动模式，是否继续？';

  @override
  String get freshAirTimerSetting => 'Vent Timer';

  @override
  String get humidifierTimerSetting => 'Hum Ctrl Timer';

  @override
  String get floorHeatTimerSetting => 'Floor Heat Timer';

  @override
  String acTimerSettingTitle(String room) {
    return '$room A/C Timer';
  }

  @override
  String acAdjustTitle(String room) {
    return '$room A/C Controls';
  }

  @override
  String floorHeatRoomTimerTitle(String room) {
    return '$room Floor Heat Timer';
  }

  @override
  String get idleNoData => '暂无实时数据';

  @override
  String get idleAdviceGoodGood => '室内外空气质量良好，可适当开窗通风';

  @override
  String get idleAdviceOutdoorBetter => '室外空气质量优于室内，建议适当开窗通风';

  @override
  String get idleAdviceGoodFair => 'Indoor air quality is good, outdoor air quality is fair. Consider limiting outdoor activities.';

  @override
  String get idleAdviceGoodPoor => 'Indoor air quality is good, outdoor air quality is poor. Consider limiting outdoor activities.';

  @override
  String get idleAdviceFairFair => 'Indoor & outdoor air quality is fair. Turn on IEF for better purification efficiency. Consider limiting outdoor activities.';

  @override
  String get idleAdviceFairPoor => 'Indoor air quality is fair, outdoor air quality is poor. Turn on IEF for better purification efficiency. Consider limiting outdoor activities.';

  @override
  String get idleAdvicePoorFair => 'Indoor air quality is poor, outdoor air quality is fair. Turn on IEF for better purification efficiency. Consider limiting outdoor activities.';

  @override
  String get idleAdvicePoorPoor => 'Indoor & outdoor air quality is poor. Turn on IEF for better purification efficiency. Consider limiting outdoor activities.';

  @override
  String get idleOutdoor => 'Outdoor';

  @override
  String get historyWeeklyTitle => 'Week';

  @override
  String get historyTimeTitle => 'Time';

  @override
  String get historyAverageSuffix => ' Average';

  @override
  String get historyDailyView => 'Daily';

  @override
  String get historyWeeklyView => 'Weekly';

  @override
  String get historyMonthlyView => 'Monthly';

  @override
  String get engineeringFreshAirConfig => 'Ventilation Subsystem Config';

  @override
  String get engineeringAcConfig => 'A/C Subsystem Config';

  @override
  String get engineeringFloorHeatConfig => 'Floor Heat Subsystem Config';

  @override
  String get engineeringProductionTestConfig => '产测模式配置';

  @override
  String get engineeringCompleteInstallation => 'Complete Installation';

  @override
  String get engineeringSavingConfig => '正在保存配置…';

  @override
  String get engineeringConfigConfirmed => '本次配置已确认';

  @override
  String get engineeringProductionTestTitle => '产测模式';

  @override
  String get engineeringDeviceSearch => 'Search Devices';

  @override
  String get engineeringNameSettings => 'Name Settings';

  @override
  String get engineeringSaveAndReturn => 'Save & Return';

  @override
  String get engineeringAreaSelect => 'Select Zone';

  @override
  String get engineeringRoomSelect => '房间选择';

  @override
  String get engineeringDeviceName => 'Device Name';

  @override
  String get engineeringConfigAddress => 'Config Address';

  @override
  String get engineeringAreaName => 'Zone Name';

  @override
  String get engineeringRoomName => 'Room Name';

  @override
  String get engineeringTestRun => 'Test Run';

  @override
  String get engineeringAreaId => 'Zone ID';

  @override
  String get engineeringRoomId => '房间ID';

  @override
  String get engineeringAddRoomHint => '点击输入新增房间';

  @override
  String get engineeringAddAreaHint => 'Tap to add a new zone';

  @override
  String get engineeringSettingItem => 'Settings';

  @override
  String get engineeringParameterSettings => 'Parameter Settings';

  @override
  String get engineeringPanelName => '8寸控制屏';

  @override
  String get engineeringTempHumiditySensor => 'Temp/Humidity Sensor';

  @override
  String get engineeringTempHumidityParams => '温度：25℃        湿度：56%';

  @override
  String get engineeringPasswordSetting => 'Installer Mode Password';

  @override
  String get engineeringFilterLife => 'Filter Life';

  @override
  String get engineeringMaintenanceInterval => 'Maintenance Interval';

  @override
  String get engineeringServicePhone => 'Service Contact Number';

  @override
  String engineeringMotorSpeedTitle(int index) {
    return 'Motor $index Speed Settings';
  }

  @override
  String get engineeringCompressorFreq => 'Compressor Freq Settings';

  @override
  String get engineeringRepeatInput => 'Re-enter';

  @override
  String get engineeringNextMaintenanceDays => 'Days Until Next Maintenance';

  @override
  String get engineeringReset => '重置';

  @override
  String get engineeringEnter6DigitPassword => '请输入 6 位数字密码';

  @override
  String get engineeringPasswordMismatch => '两次密码不一致，请重新输入';

  @override
  String get engineeringPasswordMatchConfirm => '两次输入一致，请点击确认';

  @override
  String get engineeringApplied => '本次运行已生效';

  @override
  String get engineeringNewPasswordPrompt => '请输入新的 6 位密码';

  @override
  String get engineeringReenterPasswordPrompt => '请再次输入新的 6 位密码';
}
