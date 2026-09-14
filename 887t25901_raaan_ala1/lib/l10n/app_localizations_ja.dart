import 'app_localizations.dart';

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get menuSettings => 'システム設定';

  @override
  String get menuMaintenance => '機器メンテナンス';

  @override
  String get menuEngineering => '施工モード';

  @override
  String get settingsBackHint => '※ 返回即自动保存设置';

  @override
  String get generalSettings => '一般設定';

  @override
  String get networkSettings => 'ネットワーク設定';

  @override
  String get timerSettings => '定时设置';

  @override
  String get systemInfo => 'システム情報';

  @override
  String get timeFormat => '時刻表示形式';

  @override
  String get timeFormat24h => '24 小时';

  @override
  String get timeFormat12h => '12 小时';

  @override
  String get dateSetting => '日付設定';

  @override
  String get clockSetting => '時計設定';

  @override
  String get languageSelection => '言語選択';

  @override
  String get screenBrightness => '画面の明るさ';

  @override
  String brightnessPercent(int value) {
    return '$value%';
  }

  @override
  String get priorityMetric => '優先表示項目';

  @override
  String get aqiIndicator => 'AQIインジケーター';

  @override
  String get indicatorLightBrightness => 'インジケーターの明るさ';

  @override
  String get indicatorLightBright => '明るい';

  @override
  String get indicatorLightDark => '暗い';

  @override
  String get presenceRadar => '人感センサー';

  @override
  String get screenOffTime => '画面消灯時間';

  @override
  String screenOffSecondsValue(int seconds) {
    return '$seconds秒';
  }

  @override
  String get airQualityAutoDetection => '空気質自動検知';

  @override
  String get metricTemperature => '温度';

  @override
  String get metricHumidity => '湿度';

  @override
  String get metricPm25 => 'PM2.5';

  @override
  String get metricCo2 => 'CO₂';

  @override
  String get metricFormaldehyde => 'ホルムアルデヒド';

  @override
  String get network => 'ネットワーク';

  @override
  String get myNetwork => 'マイネットワーク';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get notConnected => '未连接';

  @override
  String get currentNetwork => '現在のネットワーク';

  @override
  String get otherNetworks => 'その他のネットワーク';

  @override
  String get connecting => '连接中';

  @override
  String get wifiConnectingPrefix => '';

  @override
  String get wifiConnectingSuffix => ' に接続しています……';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get disconnect => '切断';

  @override
  String get timer => 'タイマー';

  @override
  String get timeRangeSetting => '时间段设置';

  @override
  String timerRangeValue(String start, String end) {
    return 'タイマーON $start〜$end';
  }

  @override
  String get repeatCycle => '重复周期';

  @override
  String get everyDay => '毎日';

  @override
  String get monday => '月曜日';

  @override
  String get tuesday => '火曜日';

  @override
  String get wednesday => '水曜日';

  @override
  String get thursday => '木曜日';

  @override
  String get friday => '金曜日';

  @override
  String get saturday => '土曜日';

  @override
  String get sunday => '日曜日';

  @override
  String get version => 'バージョン';

  @override
  String get checkUpdate => 'アップデートを確認';

  @override
  String get update => 'アップデート';

  @override
  String get noUpdateMessage => '当前已是最新版本';

  @override
  String get systemUptimePrefix => '系统已运行 ';

  @override
  String get systemUptimeSuffix => ' 天';

  @override
  String get clockHourHand => '時';

  @override
  String get clockMinuteHand => '分';

  @override
  String get clockSecondHand => '秒';

  @override
  String get am => '午前';

  @override
  String get pm => '午後';

  @override
  String get confirm => '確認';

  @override
  String get cancel => 'キャンセル';

  @override
  String get ok => '確定';

  @override
  String get brightness => '亮度';

  @override
  String get start => '开始';

  @override
  String get end => '结束';

  @override
  String get enterPassword => 'パスワードを入力してください';

  @override
  String get passwordError => '※  密码不正确，请重试';

  @override
  String get updateAvailableMessage => '有最新可用版本，更新预计耗时2小时，是否继续？';

  @override
  String get updateLater => '後で';

  @override
  String get updateNow => '今すぐアップデート';

  @override
  String get updatingMessage => 'アップデート中は電源を切らないでください。完了後、機器は自動的に再起動します。';

  @override
  String get updateFailedMessage => 'バージョンアップデートのダウンロードに失敗しました。ネットワーク接続を確認するか、しばらくしてからもう一度お試しください。';

  @override
  String get exit => '終了';

  @override
  String get consumableStatus => '消耗品の状態';

  @override
  String get maintenance => 'メンテナンス';

  @override
  String filterName(int index) {
    return 'フィルター$index';
  }

  @override
  String get remainingPrefix => '余';

  @override
  String get dayUnit => '天';

  @override
  String get dueForMaintenance => '交換待ち';

  @override
  String get service => 'サービス';

  @override
  String get callServiceProvider => '呼叫服务商';

  @override
  String get nextMaintenanceDate => '次回メンテナンス';

  @override
  String get maintenanceResetMessage => 'この操作を行うと現在のフィルター使用期間がリセットされます。続行しますか？';

  @override
  String get back => '戻る';

  @override
  String get offline => 'オフライン';

  @override
  String get space => 'スペース';

  @override
  String get navHome => 'ホーム';

  @override
  String get navMain => 'ホーム';

  @override
  String get navSmart => 'スマート';

  @override
  String get navManual => '手動';

  @override
  String get navTrends => '過去変化';

  @override
  String get navHistory => '履歴';

  @override
  String get navSettings => '設定';

  @override
  String get navSettingsAlt => '設定';

  @override
  String get backendOffline => '后端服务离线';

  @override
  String get backendStale => '设备数据陈旧';

  @override
  String get notificationCenter => '通知センター';

  @override
  String get faultAlert => '異常通知';

  @override
  String get noNotifications => '新しい通知はありません。';

  @override
  String get noFaults => '当前无故障！';

  @override
  String get contactSupport => 'アフターサービス';

  @override
  String get deviceAirConditioner => 'エアコン';

  @override
  String get deviceFloorHeat => '床暖房';

  @override
  String get deviceFreshAir => '換気';

  @override
  String get deviceHumidifier => '調湿';

  @override
  String get devicePure => 'IEFモード';

  @override
  String get stateCooling => '冷房';

  @override
  String get stateNotOn => 'オフ';

  @override
  String get stateOn => 'オン';

  @override
  String get freshAirModeInternalCirculation => '内気循環';

  @override
  String get fanLevelHigh => '強';

  @override
  String get iefStarting => 'IEF起動中';

  @override
  String get quickPowerAll => '一括オン／オフ';

  @override
  String get quickLeaveHome => '外出モード';

  @override
  String get floorIndoor => '室内';

  @override
  String get floorAll => 'すべて';

  @override
  String get floorBasement1 => '地下1階';

  @override
  String get floorBasement2 => '地下2階';

  @override
  String get floor1 => '1階';

  @override
  String get floor2 => '2階';

  @override
  String get floor3 => '3階';

  @override
  String get weatherSunny => '晴れ';

  @override
  String get weatherClearNight => '晴夜';

  @override
  String get weatherMostlyClear => '晴间多云';

  @override
  String get weatherOvercast => '曇り';

  @override
  String get weatherCloudy => '曇り';

  @override
  String get weatherDrizzle => '毛毛雨';

  @override
  String get weatherMiddleRain => '中雨';

  @override
  String get weatherHeavyRain => '大雨';

  @override
  String get weatherExtremeRain => '豪雨';

  @override
  String get weatherMostlyClearRain => '晴间多云有雨';

  @override
  String get weatherThunderstorms => '夕立';

  @override
  String get weatherDrizzleToMiddleRain => '小雨から中雨';

  @override
  String get weatherMiddleToHeavyRain => '中雨から大雨';

  @override
  String get weatherLightSnow => '小雪';

  @override
  String get weatherModerateSnow => '中雪';

  @override
  String get weatherHeavySnow => '大雪';

  @override
  String get weatherWindSnow => '风雪';

  @override
  String get weatherSleet => 'みぞれ';

  @override
  String get weatherFog => '霧';

  @override
  String get weatherHaze => 'ヘイズ';

  @override
  String get weatherDust => '浮遊塵';

  @override
  String get weatherSandstorm => '扬沙';

  @override
  String get weatherWindy => '強風';

  @override
  String get weatherCyclone => '台風';

  @override
  String get weatherHail => '雹';

  @override
  String get weatherHeatWave => '高温';

  @override
  String get weatherColdWave => '低温';

  @override
  String get weatherAlert => '天气预警';

  @override
  String get weatherBlizzard => '大吹雪';

  @override
  String get weatherCodeOrange => '橙色预警';

  @override
  String get weatherCodeRed => '红色预警';

  @override
  String get smartStandard => '標準モード';

  @override
  String get smartGuest => '来客モード';

  @override
  String get smartDry => '除湿モード';

  @override
  String get smartHumid => '加湿モード';

  @override
  String get smartTravel => '旅行モード';

  @override
  String smartModeActiveHint(String mode) {
    return '※ $modeが有効です。';
  }

  @override
  String get smartExitMessage => 'この操作を実行すると現在のスマートモードが終了します。続行しますか？';

  @override
  String get manualMode => 'モード';

  @override
  String get manualFanSpeed => '風量';

  @override
  String get manualDuration => '時間';

  @override
  String get manualHold => '維持';

  @override
  String get manualRoom => '房间';

  @override
  String get manualTimerOn => '入タイマー';

  @override
  String get manualTimerOff => '切タイマー';

  @override
  String get manualRepeat => '循环';

  @override
  String get manualFreshAirMode => '換気モード';

  @override
  String get manualFreshAirFanSpeed => '換気風量';

  @override
  String get modeAuto => '自動';

  @override
  String get modeHeating => '暖房';

  @override
  String get modeFan => '送風';

  @override
  String get freshAirModeFullHeatExchange => '全熱交換';

  @override
  String get repeatOnce => '1回';

  @override
  String get repeatWeekdays => '平日';

  @override
  String get repeatOff => 'オフ';

  @override
  String get timerNotSet => 'タイマー  未設定';

  @override
  String timerSummaryValue(String start, String end, String repeat) {
    return 'タイマー  $start-$end（$repeat）';
  }

  @override
  String runningDeviceCount(int count) {
    return '※ 現在$count台運転中';
  }

  @override
  String get manualWholeHomeFloorHeat => '全屋の床暖房を制御します。';

  @override
  String get manualWholeHomeFreshAir => '全屋の換気を制御します。';

  @override
  String get manualWholeHomeHumidity => '将控制全屋湿度';

  @override
  String get manualWholeHomePure => '全屋IEFがオンです。';

  @override
  String get manualExitMessage => '该操作将会退出当前手动模式，是否继续？';

  @override
  String get freshAirTimerSetting => '換気タイマー設定';

  @override
  String get humidifierTimerSetting => '調湿タイマー設定';

  @override
  String get floorHeatTimerSetting => '床暖房タイマー設定';

  @override
  String acTimerSettingTitle(String room) {
    return '$roomエアコンタイマー設定';
  }

  @override
  String acAdjustTitle(String room) {
    return '$roomエアコン調整';
  }

  @override
  String floorHeatRoomTimerTitle(String room) {
    return '$room床暖房タイマー設定';
  }

  @override
  String get idleNoData => '暂无实时数据';

  @override
  String get idleAdviceGoodGood => '室内外空气质量良好，可适当开窗通风';

  @override
  String get idleAdviceOutdoorBetter => '室外空气质量优于室内，建议适当开窗通风';

  @override
  String get idleAdviceGoodFair => '室内の空気質は良好ですが、屋外は普通です。屋外での活動を控えてください。';

  @override
  String get idleAdviceGoodPoor => '室内の空気質は良好ですが、屋外は悪いです。屋外での活動を控えてください。';

  @override
  String get idleAdviceFairFair => '室内・屋外の空気質は普通です。IEFをオンにして浄化効率を高め、屋外での活動を控えてください。';

  @override
  String get idleAdviceFairPoor => '室内の空気質は普通ですが、屋外は悪いです。IEFをオンにして浄化効率を高め、屋外での活動を控えてください。';

  @override
  String get idleAdvicePoorFair => '室内の空気質は悪く、屋外は普通です。IEFをオンにして浄化効率を高め、屋外での活動を控えてください。';

  @override
  String get idleAdvicePoorPoor => '室内・屋外の空気質は悪いです。IEFをオンにして浄化効率を高め、屋外での活動を控えてください。';

  @override
  String get idleOutdoor => '室外';

  @override
  String get historyWeeklyTitle => '週';

  @override
  String get historyTimeTitle => '時間';

  @override
  String get historyAverageSuffix => '平均';

  @override
  String get historyDailyView => '日別';

  @override
  String get historyWeeklyView => '週別';

  @override
  String get historyMonthlyView => '月別';

  @override
  String get engineeringFreshAirConfig => '換気サブシステム設定';

  @override
  String get engineeringAcConfig => 'エアコンサブシステム設定';

  @override
  String get engineeringFloorHeatConfig => '床暖房サブシステム設定';

  @override
  String get engineeringProductionTestConfig => '产测模式配置';

  @override
  String get engineeringCompleteInstallation => '施工完了確認';

  @override
  String get engineeringSavingConfig => '正在保存配置…';

  @override
  String get engineeringConfigConfirmed => '本次配置已确认';

  @override
  String get engineeringProductionTestTitle => '产测模式';

  @override
  String get engineeringDeviceSearch => '機器検索';

  @override
  String get engineeringNameSettings => '名称設定';

  @override
  String get engineeringSaveAndReturn => '確定して戻る';

  @override
  String get engineeringAreaSelect => 'ゾーン選択';

  @override
  String get engineeringRoomSelect => '房间选择';

  @override
  String get engineeringDeviceName => '機器名';

  @override
  String get engineeringConfigAddress => 'アドレス設定';

  @override
  String get engineeringAreaName => 'ゾーン名称';

  @override
  String get engineeringRoomName => 'ルーム名';

  @override
  String get engineeringTestRun => '試運転';

  @override
  String get engineeringAreaId => 'ゾーン ID';

  @override
  String get engineeringRoomId => '房间ID';

  @override
  String get engineeringAddRoomHint => '点击输入新增房间';

  @override
  String get engineeringAddAreaHint => 'タップして新規ゾーン追加';

  @override
  String get engineeringSettingItem => '設定項目';

  @override
  String get engineeringParameterSettings => 'パラメータ設定';

  @override
  String get engineeringPanelName => '8寸控制屏';

  @override
  String get engineeringTempHumiditySensor => '温湿度センサー';

  @override
  String get engineeringTempHumidityParams => '温度：25℃        湿度：56%';

  @override
  String get engineeringPasswordSetting => '施工モードパスワード設定';

  @override
  String get engineeringFilterLife => 'フィルター寿命';

  @override
  String get engineeringMaintenanceInterval => 'メンテナンス時期';

  @override
  String get engineeringServicePhone => 'サービス電話番号';

  @override
  String engineeringMotorSpeedTitle(int index) {
    return 'モーター$index回転数設定';
  }

  @override
  String get engineeringCompressorFreq => 'コンプレッサー周波数設定';

  @override
  String get engineeringRepeatInput => '再入力';

  @override
  String get engineeringNextMaintenanceDays => '次回メンテナンスまでの日数';

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
