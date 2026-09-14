import 'app_localizations.dart';

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get menuSettings => '系统设置';

  @override
  String get menuMaintenance => '设备维护';

  @override
  String get menuEngineering => '工程模式';

  @override
  String get settingsBackHint => '※ 返回即自动保存设置';

  @override
  String get generalSettings => '通用设置';

  @override
  String get networkSettings => '网络设置';

  @override
  String get timerSettings => '定时设置';

  @override
  String get systemInfo => '系统信息';

  @override
  String get timeFormat => '时间格式';

  @override
  String get timeFormat24h => '24 小时';

  @override
  String get timeFormat12h => '12 小时';

  @override
  String get dateSetting => '日期设置';

  @override
  String get clockSetting => '时钟设置';

  @override
  String get languageSelection => '语言选择';

  @override
  String get screenBrightness => '屏幕亮度';

  @override
  String brightnessPercent(int value) {
    return '$value %';
  }

  @override
  String get priorityMetric => '优先指标';

  @override
  String get aqiIndicator => 'AQI指示灯';

  @override
  String get indicatorLightBrightness => '指示灯亮度';

  @override
  String get indicatorLightBright => '亮';

  @override
  String get indicatorLightDark => '暗';

  @override
  String get presenceRadar => '人感雷达';

  @override
  String get screenOffTime => '息屏时间';

  @override
  String screenOffSecondsValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get airQualityAutoDetection => '空气品质自动检测';

  @override
  String get metricTemperature => '温度';

  @override
  String get metricHumidity => '湿度';

  @override
  String get metricPm25 => 'PM2.5';

  @override
  String get metricCo2 => 'CO₂';

  @override
  String get metricFormaldehyde => '甲醛';

  @override
  String get network => '网络';

  @override
  String get myNetwork => '我的网络';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get notConnected => '未连接';

  @override
  String get currentNetwork => '当前网络';

  @override
  String get otherNetworks => '其他网络';

  @override
  String get connecting => '连接中';

  @override
  String get wifiConnectingPrefix => '正在连接 ';

  @override
  String get wifiConnectingSuffix => ' ……';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get disconnect => '断开';

  @override
  String get timer => '定时';

  @override
  String get timeRangeSetting => '时间段设置';

  @override
  String timerRangeValue(String start, String end) {
    return '定时开  $start～$end';
  }

  @override
  String get repeatCycle => '重复周期';

  @override
  String get everyDay => '每天';

  @override
  String get monday => '周一';

  @override
  String get tuesday => '周二';

  @override
  String get wednesday => '周三';

  @override
  String get thursday => '周四';

  @override
  String get friday => '周五';

  @override
  String get saturday => '周六';

  @override
  String get sunday => '周日';

  @override
  String get version => '版本号';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get update => '更新';

  @override
  String get noUpdateMessage => '当前已是最新版本';

  @override
  String get systemUptimePrefix => '系统已运行 ';

  @override
  String get systemUptimeSuffix => ' 天';

  @override
  String get clockHourHand => '时针';

  @override
  String get clockMinuteHand => '分针';

  @override
  String get clockSecondHand => '秒针';

  @override
  String get am => '上午';

  @override
  String get pm => '下午';

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get brightness => '亮度';

  @override
  String get start => '开始';

  @override
  String get end => '结束';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get passwordError => '※  密码不正确，请重试';

  @override
  String get updateAvailableMessage => '有最新可用版本，更新预计耗时2小时，是否继续？';

  @override
  String get updateLater => '下次再说';

  @override
  String get updateNow => '立即更新';

  @override
  String get updatingMessage => '更新过程中请勿断电，更新完成后将自动重启设备';

  @override
  String get updateFailedMessage => '版本下载更新失败，请检查网络连接或稍后再试';

  @override
  String get exit => '退出';

  @override
  String get consumableStatus => '耗材状态';

  @override
  String get maintenance => '保养';

  @override
  String filterName(int index) {
    return '滤网 $index';
  }

  @override
  String get remainingPrefix => '余';

  @override
  String get dayUnit => '天';

  @override
  String get dueForMaintenance => '待维护';

  @override
  String get service => '服务';

  @override
  String get callServiceProvider => '呼叫服务商';

  @override
  String get nextMaintenanceDate => '下次保养时间';

  @override
  String get maintenanceResetMessage => '该操作将会重置当前滤网使用周期，是否继续？';

  @override
  String get back => '返回';

  @override
  String get offline => '离线';

  @override
  String get space => '空格';

  @override
  String get navHome => '首页';

  @override
  String get navMain => '主页';

  @override
  String get navSmart => '智能';

  @override
  String get navManual => '手动';

  @override
  String get navTrends => '趋势';

  @override
  String get navHistory => '历史';

  @override
  String get navSettings => '设置';

  @override
  String get navSettingsAlt => '设定';

  @override
  String get backendOffline => '后端服务离线';

  @override
  String get backendStale => '设备数据陈旧';

  @override
  String get notificationCenter => '通知中心';

  @override
  String get faultAlert => '故障提醒';

  @override
  String get noNotifications => '当前无最新通知！';

  @override
  String get noFaults => '当前无故障！';

  @override
  String get contactSupport => '联系售后';

  @override
  String get deviceAirConditioner => '空调';

  @override
  String get deviceFloorHeat => '地暖';

  @override
  String get deviceFreshAir => '新风';

  @override
  String get deviceHumidifier => '调湿';

  @override
  String get devicePure => '超净';

  @override
  String get stateCooling => '制冷';

  @override
  String get stateNotOn => '未开启';

  @override
  String get stateOn => '已开启';

  @override
  String get freshAirModeInternalCirculation => '内循环';

  @override
  String get fanLevelHigh => '强档';

  @override
  String get iefStarting => 'IEF启动中';

  @override
  String get quickPowerAll => '一键\n开关';

  @override
  String get quickLeaveHome => '一键\n离家';

  @override
  String get floorIndoor => '室内';

  @override
  String get floorAll => '全部';

  @override
  String get floorBasement1 => '地下一层';

  @override
  String get floorBasement2 => '地下二层';

  @override
  String get floor1 => '一层';

  @override
  String get floor2 => '二层';

  @override
  String get floor3 => '三层';

  @override
  String get weatherSunny => '晴';

  @override
  String get weatherClearNight => '晴夜';

  @override
  String get weatherMostlyClear => '晴间多云';

  @override
  String get weatherOvercast => '阴';

  @override
  String get weatherCloudy => '多云';

  @override
  String get weatherDrizzle => '毛毛雨';

  @override
  String get weatherMiddleRain => '中雨';

  @override
  String get weatherHeavyRain => '大雨';

  @override
  String get weatherExtremeRain => '暴雨';

  @override
  String get weatherMostlyClearRain => '晴间多云有雨';

  @override
  String get weatherThunderstorms => '雷阵雨';

  @override
  String get weatherDrizzleToMiddleRain => '小到中雨';

  @override
  String get weatherMiddleToHeavyRain => '中到大雨';

  @override
  String get weatherLightSnow => '小雪';

  @override
  String get weatherModerateSnow => '中雪';

  @override
  String get weatherHeavySnow => '大雪';

  @override
  String get weatherWindSnow => '风雪';

  @override
  String get weatherSleet => '雨夹雪';

  @override
  String get weatherFog => '雾';

  @override
  String get weatherHaze => '霾';

  @override
  String get weatherDust => '浮尘';

  @override
  String get weatherSandstorm => '扬沙';

  @override
  String get weatherWindy => '大风';

  @override
  String get weatherCyclone => '台风';

  @override
  String get weatherHail => '冰雹';

  @override
  String get weatherHeatWave => '高温';

  @override
  String get weatherColdWave => '低温';

  @override
  String get weatherAlert => '天气预警';

  @override
  String get weatherBlizzard => '暴雪';

  @override
  String get weatherCodeOrange => '橙色预警';

  @override
  String get weatherCodeRed => '红色预警';

  @override
  String get smartStandard => '标准模式';

  @override
  String get smartGuest => '会客模式';

  @override
  String get smartDry => '干爽模式';

  @override
  String get smartHumid => '温润模式';

  @override
  String get smartTravel => '旅行模式';

  @override
  String smartModeActiveHint(String mode) {
    return '※ $mode已启用';
  }

  @override
  String get smartExitMessage => '该操作将会退出当前智能模式，是否继续？';

  @override
  String get manualMode => '模式';

  @override
  String get manualFanSpeed => '风量';

  @override
  String get manualDuration => '时长';

  @override
  String get manualHold => '保持';

  @override
  String get manualRoom => '房间';

  @override
  String get manualTimerOn => '定时开';

  @override
  String get manualTimerOff => '定时关';

  @override
  String get manualRepeat => '循环';

  @override
  String get manualFreshAirMode => '新风模式';

  @override
  String get manualFreshAirFanSpeed => '新风风量';

  @override
  String get modeAuto => '自动';

  @override
  String get modeHeating => '制热';

  @override
  String get modeFan => '送风';

  @override
  String get freshAirModeFullHeatExchange => '全热交换';

  @override
  String get repeatOnce => '单次';

  @override
  String get repeatWeekdays => '工作日';

  @override
  String get repeatOff => '关闭';

  @override
  String get timerNotSet => '定时  未设置';

  @override
  String timerSummaryValue(String start, String end, String repeat) {
    return '定时  $start-$end（$repeat）';
  }

  @override
  String runningDeviceCount(int count) {
    return '※ 当前 $count 台设备运行中';
  }

  @override
  String get manualWholeHomeFloorHeat => '将控制全屋地暖';

  @override
  String get manualWholeHomeFreshAir => '将控制全屋新风';

  @override
  String get manualWholeHomeHumidity => '将控制全屋湿度';

  @override
  String get manualWholeHomePure => '已开启全屋超净';

  @override
  String get manualExitMessage => '该操作将会退出当前手动模式，是否继续？';

  @override
  String get freshAirTimerSetting => '新风定时设置';

  @override
  String get humidifierTimerSetting => '调湿定时设置';

  @override
  String get floorHeatTimerSetting => '地暖定时设置';

  @override
  String acTimerSettingTitle(String room) {
    return '$room空调定时设置';
  }

  @override
  String acAdjustTitle(String room) {
    return '$room空调调节';
  }

  @override
  String floorHeatRoomTimerTitle(String room) {
    return '$room地暖定时设置';
  }

  @override
  String get idleNoData => '暂无实时数据';

  @override
  String get idleAdviceGoodGood => '室内外空气质量良好，可适当开窗通风';

  @override
  String get idleAdviceOutdoorBetter => '室外空气质量优于室内，建议适当开窗通风';

  @override
  String get idleAdviceGoodFair => '室内空气质量优良，室外空气质量一般，建议减少室外活动';

  @override
  String get idleAdviceGoodPoor => '室内空气质量优良，室外空气质量较差，建议减少室外活动';

  @override
  String get idleAdviceFairFair => '室内空气质量一般，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动';

  @override
  String get idleAdviceFairPoor => '室内空气质量一般，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动';

  @override
  String get idleAdvicePoorFair => '室内空气质量较差，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动';

  @override
  String get idleAdvicePoorPoor => '室内空气质量较差，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动';

  @override
  String get idleOutdoor => '室外';

  @override
  String get historyWeeklyTitle => '星期';

  @override
  String get historyTimeTitle => '时间';

  @override
  String get historyAverageSuffix => '平均';

  @override
  String get historyDailyView => '按日查看';

  @override
  String get historyWeeklyView => '按周查看';

  @override
  String get historyMonthlyView => '按月查看';

  @override
  String get engineeringFreshAirConfig => '新风子系统配置';

  @override
  String get engineeringAcConfig => '空调子系统配置';

  @override
  String get engineeringFloorHeatConfig => '地暖子系统配置';

  @override
  String get engineeringProductionTestConfig => '产测模式配置';

  @override
  String get engineeringCompleteInstallation => '施工完成确认';

  @override
  String get engineeringSavingConfig => '正在保存配置…';

  @override
  String get engineeringConfigConfirmed => '本次配置已确认';

  @override
  String get engineeringProductionTestTitle => '产测模式';

  @override
  String get engineeringDeviceSearch => '设备搜索';

  @override
  String get engineeringNameSettings => '名称设置';

  @override
  String get engineeringSaveAndReturn => '确定并返回';

  @override
  String get engineeringAreaSelect => '区域选择';

  @override
  String get engineeringRoomSelect => '房间选择';

  @override
  String get engineeringDeviceName => '设备名称';

  @override
  String get engineeringConfigAddress => '配置地址';

  @override
  String get engineeringAreaName => '区域名称';

  @override
  String get engineeringRoomName => '房间名称';

  @override
  String get engineeringTestRun => '试运行';

  @override
  String get engineeringAreaId => '区域ID';

  @override
  String get engineeringRoomId => '房间ID';

  @override
  String get engineeringAddRoomHint => '点击输入新增房间';

  @override
  String get engineeringAddAreaHint => '点击输入新增区域';

  @override
  String get engineeringSettingItem => '设置项';

  @override
  String get engineeringParameterSettings => '参数设置';

  @override
  String get engineeringPanelName => '8寸控制屏';

  @override
  String get engineeringTempHumiditySensor => '温湿度传感器';

  @override
  String get engineeringTempHumidityParams => '温度：25℃        湿度：56%';

  @override
  String get engineeringPasswordSetting => '工程模式密码设置';

  @override
  String get engineeringFilterLife => '滤网寿命';

  @override
  String get engineeringMaintenanceInterval => '保养时间';

  @override
  String get engineeringServicePhone => '服务商电话';

  @override
  String engineeringMotorSpeedTitle(int index) {
    return '电机$index转速设置';
  }

  @override
  String get engineeringCompressorFreq => '压缩机频率设置';

  @override
  String get engineeringRepeatInput => '重复输入';

  @override
  String get engineeringNextMaintenanceDays => '下次保养天数';

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
